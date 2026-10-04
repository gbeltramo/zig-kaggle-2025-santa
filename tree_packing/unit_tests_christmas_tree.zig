//! Test if ChristmasTrees intersect as expected

const std = @import("std");
const xmas = @import("christmas_tree.zig");

const default_float_type = xmas.default_float_type;
const default_eps_tol = xmas.default_eps_tol;
const pi = std.math.pi;

const Point = xmas.Point;
const ChristmasTree = xmas.ChristmasTree;

test "christmas_tree_intersects_v1" {
    const tree1 = ChristmasTree.init(Point{ .x = 0.0, .y = 0.0 }, 0.0);
    const tree2 = ChristmasTree.init(Point{ .x = 0.0, .y = 0.5 }, 0.5 * pi);
    try std.testing.expect(tree1.intersects(tree2, default_eps_tol));
    try std.testing.expect(tree2.intersects(tree1, default_eps_tol));
}

test "christmas_tree_intersects_v2" {
    const tree1 = ChristmasTree.init(Point{ .x = 0.0, .y = 0.0 }, 0.0);
    const tree2 = ChristmasTree.init(Point{ .x = 0.2, .y = 0.0 }, 1.3 * pi);
    try std.testing.expect(tree1.intersects(tree2, default_eps_tol));
    try std.testing.expect(tree2.intersects(tree1, default_eps_tol));
}

test "christmas_tree_intersects_v3" {
    const tree1 = ChristmasTree.init(Point{ .x = 0.0, .y = 0.0 }, 0.0);
    const tree2 = ChristmasTree.init(Point{ .x = -0.3, .y = 0.0 }, 0.9 * pi);
    try std.testing.expect(tree1.intersects(tree2, default_eps_tol));
    try std.testing.expect(tree2.intersects(tree1, default_eps_tol));
}

test "christmas_tree_intersects_v4" {
    const tree1 = ChristmasTree.init(Point{ .x = 0.0, .y = 0.0 }, 0.0);
    const tree2 = ChristmasTree.init(Point{ .x = 0.0, .y = -0.3 }, 0.1 * pi);
    try std.testing.expect(tree1.intersects(tree2, default_eps_tol));
    try std.testing.expect(tree2.intersects(tree1, default_eps_tol));
}

test "christmas_tree_intersects_v5" {
    const tree1 = ChristmasTree.init(Point{ .x = 0.0, .y = 0.0 }, 0.0);
    const tree2 = ChristmasTree.init(Point{ .x = 0.7, .y = 0.0 }, 0.0);
    try std.testing.expect(tree1.intersects(tree2, default_eps_tol));
    try std.testing.expect(tree2.intersects(tree1, default_eps_tol));
}

test "christmas_tree_intersects_v6" {
    const tree1 = ChristmasTree.init(Point{ .x = 0.0, .y = 0.0 }, 0.0);
    const tree2 = ChristmasTree.init(Point{ .x = 0.0, .y = 1.6 }, pi);
    try std.testing.expect(tree1.intersects(tree2, default_eps_tol));
    try std.testing.expect(tree2.intersects(tree1, default_eps_tol));
}

test "christmas_tree_intersects_v7" {
    const tree1 = ChristmasTree.init(Point{ .x = 0.0, .y = 0.0 }, 0.0);
    const tree2 = ChristmasTree.init(Point{ .x = 0.0, .y = -1.0 }, 0.0);
    try std.testing.expect(tree1.intersects(tree2, default_eps_tol));
    try std.testing.expect(tree2.intersects(tree1, default_eps_tol));
}

test "christmas_tree_intersects_v8" {
    const tree1 = ChristmasTree.init(Point{ .x = 0.0, .y = 0.0 }, 0.0);
    const tree2 = ChristmasTree.init(Point{ .x = 0.0, .y = -0.4 }, std.math.pi);
    try std.testing.expect(tree1.intersects(tree2, default_eps_tol));
    try std.testing.expect(tree2.intersects(tree1, default_eps_tol));
}

test "christmas_tree_not_intersects_v1" {
    const delta: default_float_type = 0.001;
    const tree1 = ChristmasTree.init(Point{ .x = 0.0, .y = 0.0 }, 0.0);
    const tree2 = ChristmasTree.init(Point{ .x = 0.7 + delta, .y = 0.0 }, 0.0);
    try std.testing.expect(!tree1.intersects(tree2, default_eps_tol));
    try std.testing.expect(!tree2.intersects(tree1, default_eps_tol));
}

test "christmas_tree_not_intersects_v2" {
    const delta: default_float_type = 0.001;
    const tree1 = ChristmasTree.init(Point{ .x = 0.0, .y = 0.0 }, 0.0);
    const tree2 = ChristmasTree.init(Point{ .x = 0.0, .y = 1.6 + delta }, pi);
    try std.testing.expect(!tree1.intersects(tree2, default_eps_tol));
    try std.testing.expect(!tree2.intersects(tree1, default_eps_tol));
}

test "christmas_tree_not_intersects_v3" {
    const delta: default_float_type = -0.001;
    const tree1 = ChristmasTree.init(Point{ .x = 0.0, .y = 0.0 }, 0.0);
    const tree2 = ChristmasTree.init(Point{ .x = 0.0, .y = -1.0 + delta }, 0.0);
    try std.testing.expect(!tree1.intersects(tree2, default_eps_tol));
    try std.testing.expect(!tree2.intersects(tree1, default_eps_tol));
}

test "christmas_tree_not_intersects_v4" {
    const delta: default_float_type = -0.001;
    const tree1 = ChristmasTree.init(Point{ .x = 0.0, .y = 0.0 }, 0.0);
    const tree2 = ChristmasTree.init(Point{ .x = 0.0, .y = -0.4 + delta }, std.math.pi);
    try std.testing.expect(!tree1.intersects(tree2, default_eps_tol));
    try std.testing.expect(!tree2.intersects(tree1, default_eps_tol));
}
