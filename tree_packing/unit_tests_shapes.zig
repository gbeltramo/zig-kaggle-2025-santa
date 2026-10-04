const std = @import("std");
const xmas = @import("christmas_tree.zig");

const default_float_type = xmas.default_float_type;
const default_eps_tol = xmas.default_eps_tol;
const pi = std.math.pi;

const Interval = xmas.Interval;
const Point = xmas.Point;
const Circle = xmas.Circle;
const AlignedRectangle = xmas.AlignedRectangle;
const Segment = xmas.Segment;
const Triangle = xmas.Triangle;
const OpenTriangle = xmas.OpenTriangle;

// --- Segment tests

test "segment_intersects_90_degrees" {
    // Note: canonical intersection, should return true
    var seg1 = Segment.init(Point{ .x = 0.0, .y = 0.0 }, Point{ .x = 2.0, .y = 2.0 });
    var seg2 = Segment.init(Point{ .x = 0.0, .y = 2.0 }, Point{ .x = 2.0, .y = 0.0 });
    try std.testing.expect(seg1.intersects(seg2, default_eps_tol));
    try std.testing.expect(seg2.intersects(seg1, default_eps_tol));
}

test "segment_intersects_horizontal" {
    var seg1 = Segment.init(Point{ .x = 0.0, .y = 0.0 }, Point{ .x = 2.0, .y = 0.0 });
    var seg2 = Segment.init(Point{ .x = 0.0, .y = 2.0 }, Point{ .x = 1.0, .y = -1.0 });
    try std.testing.expect(seg1.intersects(seg2, default_eps_tol));
    try std.testing.expect(seg2.intersects(seg1, default_eps_tol));
}

test "segment_intersects_vertical" {
    var seg1 = Segment.init(Point{ .x = 0.0, .y = 0.0 }, Point{ .x = 0.0, .y = 2.0 });
    var seg2 = Segment.init(Point{ .x = -1.0, .y = 1.0 }, Point{ .x = 1.0, .y = 0.5 });
    try std.testing.expect(seg1.intersects(seg2, default_eps_tol));
    try std.testing.expect(seg2.intersects(seg1, default_eps_tol));
}

test "segment_intersects_horizontal_and_vertical_v1" {
    var seg1 = Segment.init(Point{ .x = 0.0, .y = -1.0 }, Point{ .x = 0.0, .y = 1.0 });
    var seg2 = Segment.init(Point{ .x = -1.0, .y = 0.0 }, Point{ .x = 1.0, .y = 0.0 });
    try std.testing.expect(seg1.intersects(seg2, default_eps_tol));
    try std.testing.expect(seg2.intersects(seg1, default_eps_tol));
}

test "segment_intersects_horizontal_and_vertical_v2" {
    var seg1 = Segment.init(Point{ .x = 0.0, .y = -1.0 }, Point{ .x = 0.0, .y = 1.0 });
    var seg2 = Segment.init(Point{ .x = -1.0, .y = 0.0 }, Point{ .x = 0.0, .y = 0.0 });
    try std.testing.expect(seg1.intersects(seg2, default_eps_tol));
    try std.testing.expect(seg2.intersects(seg1, default_eps_tol));
}

test "segment_intersects_touch" {
    // Note: touching in a point counts as an intersection, because of eps_tol
    const seg1 = Segment.init(Point{ .x = 0.0, .y = 0.0 }, Point{ .x = 1.0, .y = 1.0 });
    const seg2 = Segment.init(Point{ .x = 0.0, .y = 2.0 }, Point{ .x = 2.0, .y = 0.0 });
    try std.testing.expect(seg1.intersects(seg2, default_eps_tol));
    try std.testing.expect(seg2.intersects(seg1, default_eps_tol));
}

test "segment_not_intersects_almost_touch" {
    // Note: the +0.001 avoids the intersection
    const delta = 0.001;
    const seg1 = Segment.init(Point{ .x = 0.0, .y = 0.0 }, Point{ .x = 1.0, .y = 1.0 });
    const seg2 = Segment.init(Point{ .x = 0.000, .y = 2.0 + delta }, Point{ .x = 2.0 + delta, .y = 0.0 });
    try std.testing.expect(!seg1.intersects(seg2, default_eps_tol));
    try std.testing.expect(!seg2.intersects(seg1, default_eps_tol));
}

test "segment_not_intersects_parallel_lines" {
    // Note: parallel lines do not intersect
    const delta = 0.001;
    const seg1 = Segment.init(Point{ .x = 0.0, .y = 0.0 }, Point{ .x = 1.0, .y = 1.0 });
    const seg2 = Segment.init(Point{ .x = 0.000, .y = 1.0 }, Point{ .x = 1.0, .y = 2.0 });
    const seg3 = Segment.init(Point{ .x = 0.000, .y = 0.0 + delta }, Point{ .x = 1.0, .y = 1.0 + delta });
    try std.testing.expect(!seg1.intersects(seg2, default_eps_tol));
    try std.testing.expect(!seg2.intersects(seg1, default_eps_tol));
    try std.testing.expect(!seg1.intersects(seg3, default_eps_tol));
    try std.testing.expect(!seg3.intersects(seg1, default_eps_tol));
}

test "segment_not_intersects_horizontal_and_vertical" {
    const delta = 0.001;
    var seg1 = Segment.init(Point{ .x = 0.0 + delta, .y = -1.0 }, Point{ .x = 0.0 + delta, .y = 1.0 });
    var seg2 = Segment.init(Point{ .x = -1.0, .y = 0.0 }, Point{ .x = 0.0, .y = 0.0 });
    try std.testing.expect(!seg1.intersects(seg2, default_eps_tol));
    try std.testing.expect(!seg2.intersects(seg1, default_eps_tol));
}

test "segment_intersects_n_rays" {
    // Note: we build 4096 rays of length 10.0 shooting from (0.0, 0.0) and check that they
    // all intersect a triangle ABC that contains (0.0, 0.0)
    const allocator = std.testing.allocator;

    const N: default_float_type = 4096.0;
    var rays = try std.ArrayList(Segment).initCapacity(allocator, @intFromFloat(N));
    defer rays.deinit(allocator);

    const theta = 2 * pi / N;
    for (0..N) |i| {
        const idx: default_float_type = @floatFromInt(i + 1);
        const x: default_float_type = 10.0 * @cos(idx * theta);
        const y: default_float_type = 10.0 * @sin(idx * theta);
        const new_segment = Segment.init(Point{ .x = 0.0, .y = 0.0 }, Point{ .x = x, .y = y });
        try rays.append(allocator, new_segment);
    }

    // Note: three points forming a triangle around the origin
    const A = Point{ .x = 0.0, .y = 1.0 };
    const B = Point{ .x = 0.5, .y = -0.5 };
    const C = Point{ .x = -0.5, .y = -0.5 };

    const edge1 = Segment.init(A, B);
    const edge2 = Segment.init(B, C);
    const edge3 = Segment.init(C, A);

    // Note: we check that there is always at least one edge intersecting each ray
    for (rays.items) |ray| {
        try std.testing.expect(ray.intersects(edge1, default_eps_tol) or ray.intersects(edge2, default_eps_tol) or ray.intersects(edge3, default_eps_tol));
        try std.testing.expect(edge1.intersects(ray, default_eps_tol) or edge2.intersects(ray, default_eps_tol) or edge3.intersects(ray, default_eps_tol));
    }
}

test "segment_not_intersects_n_rays" {
    // Note: we build 4096 rays of length 10.0 shooting from (11.0, 2.0) and check that they
    // never intersect a triangle ABC that contains (0.0, 0.0)
    const allocator = std.testing.allocator;

    const N: default_float_type = 4096.0;
    var rays = try std.ArrayList(Segment).initCapacity(allocator, @intFromFloat(N));
    defer rays.deinit(allocator);

    const theta = 2 * pi / N;
    for (0..N) |i| {
        const idx: default_float_type = @floatFromInt(i + 1);
        const x: default_float_type = 10.0 * @cos(idx * theta);
        const y: default_float_type = 10.0 * @sin(idx * theta);

        const dx: default_float_type = 11.0;
        const dy: default_float_type = 2.0;

        const new_segment = Segment.init(
            Point{ .x = dx, .y = dy },
            Point{ .x = x + dx, .y = y + dy },
        );
        try rays.append(allocator, new_segment);
    }

    // Note: three points forming a triangle around the origin
    const A = Point{ .x = 0.0, .y = 1.0 };
    const B = Point{ .x = 0.5, .y = -0.5 };
    const C = Point{ .x = -0.5, .y = -0.5 };

    const edge1 = Segment.init(A, B);
    const edge2 = Segment.init(B, C);
    const edge3 = Segment.init(C, A);

    // Note: we check that there is always at least one edge intersecting each ray
    for (rays.items) |ray| {
        try std.testing.expect(!(ray.intersects(edge1, default_eps_tol) or ray.intersects(edge2, default_eps_tol) or ray.intersects(edge3, default_eps_tol)));
        try std.testing.expect(!(edge1.intersects(ray, default_eps_tol) or edge2.intersects(ray, default_eps_tol) or edge3.intersects(ray, default_eps_tol)));
    }
}

// --- Triangle tests

test "triangle_intersect_v1" {
    // Note: standard intersection
    const tri1 = Triangle.init(
        Point{ .x = -0.8, .y = 1.0 },
        Point{ .x = 0.2, .y = 0.0 },
        Point{ .x = -0.8, .y = -1.0 },
    );
    const tri2 = Triangle.init(
        Point{ .x = 0.0, .y = 0.0 },
        Point{ .x = 1.0, .y = 1.0 },
        Point{ .x = 1.0, .y = -1.0 },
    );
    try std.testing.expect(tri1.intersects(tri2, default_eps_tol));
    try std.testing.expect(tri2.intersects(tri1, default_eps_tol));
}

test "triangle_intersect_v2" {
    // Note: intersection touching in one point
    const tri1 = Triangle.init(
        Point{ .x = -1.0, .y = 1.0 },
        Point{ .x = 0.0, .y = 0.0 },
        Point{ .x = -1.0, .y = -1.0 },
    );
    const tri2 = Triangle.init(
        Point{ .x = 0.0, .y = 0.0 },
        Point{ .x = 1.0, .y = 1.0 },
        Point{ .x = 1.0, .y = -1.0 },
    );
    try std.testing.expect(tri1.intersects(tri2, default_eps_tol));
    try std.testing.expect(tri2.intersects(tri1, default_eps_tol));
}

test "triangle_intersect_v3" {
    // Note: intersect along one edge
    const tri1 = Triangle.init(
        Point{ .x = -1.0, .y = 1.0 },
        Point{ .x = 0.0, .y = 0.0 },
        Point{ .x = -1.0, .y = -1.0 },
    );
    const tri2 = Triangle.init(
        Point{ .x = -0.5, .y = 0.5 },
        Point{ .x = 0.5, .y = 1.5 },
        Point{ .x = 0.5, .y = -0.5 },
    );
    try std.testing.expect(tri1.intersects(tri2, default_eps_tol));
    try std.testing.expect(tri2.intersects(tri1, default_eps_tol));
}

test "triangle_not_intersect_v1" {
    // Note: almost touching in one point
    const tri1 = Triangle.init(
        Point{ .x = -1.001, .y = 1.0 },
        Point{ .x = -0.001, .y = 0.0 },
        Point{ .x = -1.001, .y = -1.0 },
    );
    const tri2 = Triangle.init(
        Point{ .x = 0.0, .y = 0.0 },
        Point{ .x = 1.0, .y = 1.0 },
        Point{ .x = 1.0, .y = -1.0 },
    );
    try std.testing.expect(!tri1.intersects(tri2, default_eps_tol));
    try std.testing.expect(!tri2.intersects(tri1, default_eps_tol));
}

test "triangle_not_intersect_v2" {
    // Note: almost touching along one edge
    const tri1 = Triangle.init(
        Point{ .x = -1.0, .y = 1.0 },
        Point{ .x = 0.0, .y = 0.0 },
        Point{ .x = -1.0, .y = -1.0 },
    );
    const delta = 0.0001;
    const tri2 = Triangle.init(
        Point{ .x = -0.5, .y = 0.5 + delta },
        Point{ .x = 0.5, .y = 1.5 + delta },
        Point{ .x = 0.5, .y = -0.5 + delta },
    );
    try std.testing.expect(!tri1.intersects(tri2, default_eps_tol));
    try std.testing.expect(!tri2.intersects(tri1, default_eps_tol));
}

// --- Open triangle tests

test "open_triangle_intersect_v1" {
    const delta_xs = [_]default_float_type{ 0.1, 0.2, 0.3, 0.99, 1.0, -1.0 };
    const delta_ys = [_]default_float_type{ 0.1, -0.2, 0.3, -0.99, 1.0, 0.0 };

    for (delta_xs, delta_ys) |dx, dy| {
        const tri1 = OpenTriangle.init(
            Point{ .x = 0.0, .y = 1.0 },
            Point{ .x = 0.0, .y = 0.0 },
            Point{ .x = 1.0, .y = 0.0 },
            Point{ .x = 1.0, .y = 1.0 },
        );
        const tri2 = tri1.rotateAndThenTranslate(
            0.0,
            Point{ .x = dx, .y = dy },
        );
        try std.testing.expect(tri1.intersectsOpen(tri2, default_eps_tol));
        try std.testing.expect(tri2.intersectsOpen(tri1, default_eps_tol));
    }
}

test "open_triangle_not_intersect_v1" {
    const delta_xs = [_]default_float_type{ 1.001, 1.001, -1.001 };
    const delta_ys = [_]default_float_type{ 1.001, 0.0, 0.0 };

    for (delta_xs, delta_ys) |dx, dy| {
        const tri1 = OpenTriangle.init(
            Point{ .x = 0.0, .y = 1.0 },
            Point{ .x = 0.0, .y = 0.0 },
            Point{ .x = 1.0, .y = 0.0 },
            Point{ .x = 1.0, .y = 1.0 },
        );
        const tri2 = tri1.rotateAndThenTranslate(
            0.0,
            Point{ .x = dx, .y = dy },
        );
        try std.testing.expect(!tri1.intersectsOpen(tri2, default_eps_tol));
        try std.testing.expect(!tri2.intersectsOpen(tri1, default_eps_tol));
    }
}
