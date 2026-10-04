//! Pack the positions of a set of starting ChristmasTrees using random
//! (delta_x, delta_y) and delta_theta moves.
//!
//! Attractor: trees are pulled toward a point that sits on a circle around the
//! barycenter of the packing.
//!   - circle radius = circle_factor * (side of the current bounding square)
//!   - circle_factor starts at 1/3 and is multiplied by `circle_radius_decay`
//!     after every epoch, so the attractor drifts toward the barycenter itself
//!   - the point rotates a little on every step (`circle_turns_per_epoch` full
//!     turns per epoch); the angle is never reset between epochs
//!
//! Usage:
//!   $ zig build run-pack                           - start from a random grid of trees, default params
//!   $ zig build run-pack -- --random [N] [M] [steps]  - start from a random grid, `N` trees, `M` epochs, `steps` per epoch
//!   $ zig build run-pack -- winner_submission.csv [N] [M] [steps] - start from trees read from a CSV file, `N` trees, `M` epochs, `steps` per epoch
//!
//! Writes the packed configuration to `submission.csv` and a 2D plot
//! of the trees to `pack.png`.

const std = @import("std");

const utilities = @import("utilities.zig");
const uu = utilities.Generic(float_type);
const xmas = @import("christmas_tree.zig");
const image_rgba = @import("image_rgba.zig");
const submission_module = @import("submission.zig");

const float_type = f128;
const default_eps_tol: float_type = 1e-23;
const epoch_decay: float_type = 0.998;
const max_num_trees: usize = 200;

const Interval = xmas.GenericInterval(float_type);
const Point = xmas.GenericPoint(float_type);
const ChristmasTree = xmas.GenericChristmasTree(float_type);
const Shape = xmas.GenericShapeInterface(float_type);

const Submission = submission_module.Submission;

const PixelValue = image_rgba.PixelValue;
const ImageRGBA = image_rgba.GenericImageRGBA(float_type);

const Stats = struct {
    intersect: usize = 0,
    worse: usize = 0,
    same: usize = 0,
    better: usize = 0,
};

pub fn main(init: std.process.Init) !void {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();

    const gpa = init.gpa;
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);

    var config = Config{
        .init_method = .GridWithRandomRotation,
        .num_trees = 150,
        .seed = 25,
        .num_epochs = 100,
        .num_steps_per_epoch = 10_000,
        .log_freq = 100, // in epochs
        .factor_delta_x = 1e-2,
        .factor_delta_y = 1e-2,
        .factor_delta_theta = 1e-2,
        .factor_pull_to_center = 1e-2,
        .prob_update_one_tree = 0.05,
        .circle_radius_factor = 1.0 / 3.0,
        .circle_radius_decay = 0.97,
        .circle_turns_per_epoch = 0.1,
    };

    if (args.len > 1) {
        if (std.mem.eql(u8, args[1], "--random")) {
            config.init_method = .GridWithRandomRotation;
        } else {
            config.init_method = .FromExistingSubmission;
            config.init_submission_path = args[1];
        }
    }
    if (args.len > 2) {
        config.num_trees = try std.fmt.parseInt(usize, args[2], 10);
    }
    if (args.len > 3) {
        config.num_epochs = try std.fmt.parseInt(usize, args[3], 10);
    }
    if (args.len > 4) {
        config.num_steps_per_epoch = try std.fmt.parseInt(usize, args[4], 10);
    }

    if (config.num_trees == 0 or config.num_trees > max_num_trees) {
        std.log.info("ERROR: num_trees must be in [1, {d}]", .{max_num_trees});
        return error.InvalidNumTrees;
    }

    std.log.info("--- Pack ChristmasTrees ---", .{});
    std.log.info("num_trees={d} epochs={d} steps={d} init={s}", .{
        config.num_trees,
        config.num_epochs,
        config.num_steps_per_epoch,
        @tagName(config.init_method),
    });

    const trees = try gpa.alloc(ChristmasTree, config.num_trees);
    defer gpa.free(trees);
    // Indices of the trees moved in the current step.
    const moved = try gpa.alloc(usize, config.num_trees);
    defer gpa.free(moved);
    const num_trees_float: float_type = @floatFromInt(trees.len);

    switch (config.init_method) {
        .GridWithRandomRotation => {
            std.log.info("Initializing {d} trees on a square grid with random rotation", .{trees.len});
            initTreesOnGrid(trees, config.seed);
        },
        .FromExistingSubmission => {
            std.log.info("Reading submission from {s}", .{config.init_submission_path});
            var sub: Submission = .{};
            defer sub.deinit(gpa);
            const num_of_trees_read = try sub.read(gpa, io, config.init_submission_path);
            std.log.info("Number of trees read from {s} => {d}", .{
                config.init_submission_path,
                num_of_trees_read,
            });

            if (num_of_trees_read < config.num_trees) {
                std.log.err("The submission has {d} trees but we need {d}", .{ num_of_trees_read, config.num_trees });
                return error.NotEnoughTrees;
            }

            for (0..config.num_trees) |idx_tree| {
                trees[idx_tree] = ChristmasTree.init(
                    Point{
                        .x = @floatCast(sub.entries[idx_tree].x),
                        .y = @floatCast(sub.entries[idx_tree].y),
                    },
                    @floatCast(sub.entries[idx_tree].theta),
                );
            }
        },
    }

    if (isIntersection(trees)) {
        std.log.info("Starting trees are already intersecting, stopping.", .{});
        return;
    }

    var pseudo_random = std.Random.DefaultPrng.init(config.seed);
    const rand = pseudo_random.random();

    // Note: compute the starting score
    const initial = uu.calcScoreAndPackCoeff(trees);
    var side_length: float_type = initial[0]; // side of the accepted bounding square
    var score: float_type = (side_length * side_length) / num_trees_float;
    var pack_coeff: float_type = initial[1];
    std.log.info("Initial score={d:.15}", .{score});

    // Attractor circle state (persists across epochs).
    var circle_factor: float_type = config.circle_radius_factor;
    var phi: float_type = 0.0;
    const steps_f: float_type = @floatFromInt(@max(config.num_steps_per_epoch, 1));
    const dphi: float_type = std.math.tau * config.circle_turns_per_epoch / steps_f;

    for (0..config.num_epochs) |epoch_idx| {
        var stats = Stats{};

        for (0..config.num_steps_per_epoch) |_| {
            // Rotate the attractor point on the circle around the barycenter.
            phi += dphi;
            if (phi >= std.math.tau) phi -= std.math.tau;

            const bary = barycenter(trees);
            const circle_radius = circle_factor * side_length;
            const target = Point{
                .x = bary.x + circle_radius * @cos(phi),
                .y = bary.y + circle_radius * @sin(phi),
            };

            const num_moved = updateAllWithProb(trees, moved, target, rand, config);
            const moved_now = moved[0..num_moved];

            if (isIntersectionMoved(trees, moved_now)) {
                stats.intersect += 1;
                revertMoved(trees, moved_now);
                continue;
            }

            const new_score_and_pack_coeff = uu.calcScoreAndPackCoeff(trees);
            const new_side_length = new_score_and_pack_coeff[0];
            const new_score = (new_side_length * new_side_length) / num_trees_float;
            const new_pack_coeff = new_score_and_pack_coeff[1];

            if (new_score < score) {
                stats.better += 1;
                acceptMoved(trees, moved_now);
                score = new_score;
                side_length = new_side_length;
                pack_coeff = new_pack_coeff;
            } else if (new_score == score and new_pack_coeff < pack_coeff) {
                stats.same += 1;
                acceptMoved(trees, moved_now);
                score = new_score;
                side_length = new_side_length;
                pack_coeff = new_pack_coeff;
            } else {
                stats.worse += 1;
                revertMoved(trees, moved_now);
            }
        }

        if (epoch_idx % config.log_freq == 0) {
            std.log.info(
                "epoch {d:>5} | score={d:.10} pack={d:.5} | better={d} same={d} worse={d} intersect={d} | step={e:.2} circle_r={d:.4} phi={d:.3}",
                .{
                    epoch_idx,
                    score,
                    pack_coeff,
                    stats.better,
                    stats.same,
                    stats.worse,
                    stats.intersect,
                    config.factor_delta_x,
                    circle_factor * side_length,
                    phi,
                },
            );
        }

        // Anneal step sizes.
        config.factor_delta_x *= epoch_decay;
        config.factor_delta_y *= epoch_decay;
        config.factor_delta_theta *= epoch_decay;
        config.factor_pull_to_center *= epoch_decay;

        // Shrink the attractor circle: trees get pulled more and more
        // toward the barycenter itself.
        circle_factor *= config.circle_radius_decay;
    }

    // Write submission
    std.log.info("Writing submission.csv", .{});
    var out_sub: Submission = .{};
    defer out_sub.deinit(gpa);
    out_sub.entries = try gpa.alloc(submission_module.Entry, config.num_trees);
    out_sub.num_trees = config.num_trees;
    for (0..config.num_trees) |idx_tree| {
        out_sub.entries[idx_tree] = .{
            .x = @floatCast(trees[idx_tree].init_center.x),
            .y = @floatCast(trees[idx_tree].init_center.y),
            .theta = @floatCast(trees[idx_tree].init_theta),
        };
    }
    try out_sub.write(gpa, io, "submission.csv");

    std.log.info("Plotting trees to pack.png", .{});
    try plotTrees(gpa, io, trees, "pack.png");

    std.log.info("Done. score={d:.15}", .{score});
}

pub const TypesOfInits = enum {
    GridWithRandomRotation,
    FromExistingSubmission,
};

pub const Config = struct {
    init_method: TypesOfInits,
    init_submission_path: []const u8 = "",
    num_trees: usize = 10,
    seed: u64 = 123,
    num_epochs: usize = 3,
    num_steps_per_epoch: usize = 100_001,
    /// Log every `log_freq` epochs.
    log_freq: usize = 10,
    factor_delta_x: float_type = 0.0001,
    factor_delta_y: float_type = 0.0001,
    factor_delta_theta: float_type = 0.0001,
    /// Max fraction of the distance to the attractor a tree is pulled per step.
    factor_pull_to_center: float_type = 0.01,
    prob_update_one_tree: float_type = 0.3,
    /// Initial attractor-circle radius as a fraction of the packing diameter
    /// (side of the bounding square).
    circle_radius_factor: float_type = 1.0 / 3.0,
    /// Multiplier applied to the circle radius factor after every epoch.
    circle_radius_decay: float_type = 0.97,
    /// How many full turns the attractor point makes around the circle per epoch.
    circle_turns_per_epoch: float_type = 0.1,
};

/// Uniform random float in [0, 1).
fn genRandomFloat(rand: std.Random) float_type {
    const value = rand.float(f64);
    return @as(float_type, @floatCast(value));
}

/// Initialize the trees on a square grid (side = ceil(sqrt(N))) with random rotation.
/// The spacing is larger than the tree's bounding circle, so the start is collision free.
pub fn initTreesOnGrid(blank_trees: []ChristmasTree, seed: u64) void {
    var pseudo_random = std.Random.DefaultPrng.init(seed);
    const rand = pseudo_random.random();

    const n_f: float_type = @floatFromInt(blank_trees.len);
    const side: usize = @intFromFloat(@ceil(@sqrt(n_f)));

    outer_loop: for (0..side) |ix| {
        for (0..side) |iy| {
            const idx_tree = iy + ix * side;
            if (idx_tree >= blank_trees.len) {
                break :outer_loop;
            }
            const ix_f: float_type = @floatFromInt(ix);
            const iy_f: float_type = @floatFromInt(iy);
            const init_center = Point{ .x = 1.602 * ix_f, .y = 1.602 * iy_f };
            const init_theta = 2.0 * std.math.pi * genRandomFloat(rand);
            blank_trees[idx_tree] = ChristmasTree.init(init_center, init_theta);
        }
    }
}

/// Barycenter of the last *accepted* centers (uses .init_center).
pub fn barycenter(trees: []const ChristmasTree) Point {
    var sx: float_type = 0.0;
    var sy: float_type = 0.0;
    for (trees) |t| {
        sx += t.init_center.x;
        sy += t.init_center.y;
    }
    const n: float_type = @floatFromInt(trees.len);
    return .{ .x = sx / n, .y = sy / n };
}

/// Move one tree: random jitter + a random-sized pull toward `target`.
fn perturbTree(
    tree: *ChristmasTree,
    target: Point,
    rand: std.Random,
    config: Config,
) void {
    const jitter_x = config.factor_delta_x * (genRandomFloat(rand) - 0.5);
    const jitter_y = config.factor_delta_y * (genRandomFloat(rand) - 0.5);
    const delta_theta = config.factor_delta_theta * 2 * std.math.pi *
        (genRandomFloat(rand) - 0.5);

    // Pull is proportional to the distance, so trees far from the attractor
    // (typically the ones that set the bounding square) are pulled hardest.
    const pull = config.factor_pull_to_center * genRandomFloat(rand);
    const delta_x = pull * (target.x - tree.init_center.x) + jitter_x;
    const delta_y = pull * (target.y - tree.init_center.y) + jitter_y;

    tree.update(delta_theta, Point{ .x = delta_x, .y = delta_y });
}

/// All trees are assumed to be in their accepted state on entry. Perturbs a
/// random subset (at least one) toward `target`, writes the moved indices into
/// `moved` and returns how many trees were moved.
pub fn updateAllWithProb(
    trees: []ChristmasTree,
    moved: []usize,
    target: Point,
    rand: std.Random,
    config: Config,
) usize {
    var count: usize = 0;
    for (trees, 0..) |*t, idx| {
        if (config.prob_update_one_tree > genRandomFloat(rand)) {
            perturbTree(t, target, rand, config);
            moved[count] = idx;
            count += 1;
        }
    }

    if (count == 0) {
        const idx = rand.uintLessThan(usize, trees.len);
        perturbTree(&trees[idx], target, rand, config);
        moved[0] = idx;
        count = 1;
    }
    return count;
}

/// Full O(n^2) check (used once at start-up).
pub fn isIntersection(trees: []ChristmasTree) bool {
    for (0..trees.len) |idx1| {
        for (idx1 + 1..trees.len) |idx2| {
            if (trees[idx1].intersects(trees[idx2], default_eps_tol)) {
                return true;
            }
        }
    }

    return false;
}

/// Only pairs involving a moved tree can have changed: O(moved * n).
pub fn isIntersectionMoved(trees: []ChristmasTree, moved: []const usize) bool {
    for (moved) |i| {
        for (0..trees.len) |j| {
            if (j == i) continue;
            if (trees[i].intersects(trees[j], default_eps_tol)) {
                return true;
            }
        }
    }
    return false;
}

/// Make the perturbed state the new accepted state (moved trees only).
pub fn acceptMoved(trees: []ChristmasTree, moved: []const usize) void {
    for (moved) |i| {
        trees[i].init_center = trees[i].center;
        trees[i].init_theta = trees[i].theta;
        // Geometry is already consistent with center/theta, no update needed.
    }
}

/// Undo a perturbation: put moved trees back to .init_center/.init_theta.
pub fn revertMoved(trees: []ChristmasTree, moved: []const usize) void {
    for (moved) |i| {
        trees[i].update(0.0, Point{ .x = 0.0, .y = 0.0 });
    }
}

/// Render the trees into a square window that contains all bounding boxes,
/// and save the result as a PNG file.
fn plotTrees(
    allocator: std.mem.Allocator,
    io: std.Io,
    trees: []ChristmasTree,
    path: []const u8,
) !void {
    var min_x_value: float_type = 10_000.0;
    var max_x_value: float_type = -10_000.0;
    var min_y_value: float_type = 10_000.0;
    var max_y_value: float_type = -10_000.0;

    for (trees) |tree| {
        min_x_value = @min(min_x_value, tree.bounding_box.interval_x.A);
        max_x_value = @max(max_x_value, tree.bounding_box.interval_x.B);
        min_y_value = @min(min_y_value, tree.bounding_box.interval_y.A);
        max_y_value = @max(max_y_value, tree.bounding_box.interval_y.B);
    }

    const window_side_length = @max(max_x_value - min_x_value, max_y_value - min_y_value);
    const wx = (max_x_value + min_x_value) / 2.0;
    const wy = (max_y_value + min_y_value) / 2.0;
    const delta: float_type = 0.5;

    const interval_x = Interval{
        .A = wx - (window_side_length / 2.0) - delta,
        .B = wx + window_side_length / 2.0 + delta,
    };
    const interval_y = Interval{
        .A = wy - (window_side_length / 2.0) - delta,
        .B = wy + window_side_length / 2.0 + delta,
    };

    const img = try ImageRGBA.init(
        allocator,
        512,
        512,
        interval_x,
        interval_y,
    );
    defer img.deinit(allocator);

    const green = PixelValue{ .red = 20, .green = 230, .blue = 20, .alpha = 255 };
    const white = PixelValue{ .red = 255, .green = 255, .blue = 255, .alpha = 255 };
    img.setAll(white);

    for (trees) |tree| {
        const shape = Shape{ .christmas_tree = tree };
        img.drawShape(shape, green, 0.00001);
    }

    try img.savePng(allocator, io, path);
}
