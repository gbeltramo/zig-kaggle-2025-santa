const std = @import("std");

pub const default_float_type: type = f128;
pub const default_eps_tol: default_float_type = 1e-23;

pub fn GenericPoint(comptime T: type) type {
    return struct {
        const Self = @This();

        x: T = 0.0,
        y: T = 0.0,

        /// Rotate by an angle whose cos/sin are already known, then translate.
        pub inline fn transform(self: Self, cos_t: T, sin_t: T, transl: Self) Self {
            @setFloatMode(.optimized);
            return Self{
                .x = self.x * cos_t - self.y * sin_t + transl.x,
                .y = self.x * sin_t + self.y * cos_t + transl.y,
            };
        }

        pub fn rotateAndThenTranslate(self: Self, theta: T, transl: Self) Self {
            return self.transform(@cos(theta), @sin(theta), transl);
        }
    };
}

pub const Point = GenericPoint(default_float_type);

pub fn GenericInterval(comptime T: type) type {
    return struct {
        const Self = @This();

        A: T,
        B: T,

        /// Closed-interval overlap (touching counts as overlap).
        pub fn intersects(self: Self, other: Self, eps_tol: T) bool {
            return (self.A < other.B + eps_tol) and (other.A < self.B + eps_tol);
        }

        pub fn contains(self: Self, value: T, eps_tol: T) bool {
            return (self.A < value + eps_tol) and (self.B > value - eps_tol);
        }
    };
}

pub const Interval = GenericInterval(default_float_type);

pub fn GenericAlignedRectangle(comptime T: type) type {
    return struct {
        const Self = @This();

        interval_x: GenericInterval(T),
        interval_y: GenericInterval(T),

        pub fn intersects(self: Self, other: Self, eps_tol: T) bool {
            return self.interval_x.intersects(other.interval_x, eps_tol) and
                self.interval_y.intersects(other.interval_y, eps_tol);
        }

        pub fn contains(self: Self, point: GenericPoint(T), eps_tol: T) bool {
            return self.interval_x.contains(point.x, eps_tol) and
                self.interval_y.contains(point.y, eps_tol);
        }
    };
}

pub const AlignedRectangle = GenericAlignedRectangle(default_float_type);

pub fn GenericCircle(comptime T: type) type {
    return struct {
        const Self = @This();

        cx: T = 0.0,
        cy: T = 0.0,
        radius: T = 0.0,

        pub fn intersects(self: Self, other: Self, eps_tol: T) bool {
            const dx = self.cx - other.cx;
            const dy = self.cy - other.cy;
            const r = self.radius + other.radius + eps_tol;
            return dx * dx + dy * dy < r * r;
        }

        pub fn contains(self: Self, p: GenericPoint(T), eps_tol: T) bool {
            const dx = self.cx - p.x;
            const dy = self.cy - p.y;
            const r = self.radius + eps_tol;
            return dx * dx + dy * dy < r * r;
        }

        /// Rotate the centre (radius unchanged), then translate.
        pub inline fn transform(self: Self, cos_t: T, sin_t: T, transl: GenericPoint(T)) Self {
            @setFloatMode(.optimized);
            return Self{
                .cx = self.cx * cos_t - self.cy * sin_t + transl.x,
                .cy = self.cx * sin_t + self.cy * cos_t + transl.y,
                .radius = self.radius,
            };
        }
    };
}

pub const Circle = GenericCircle(default_float_type);

pub fn GenericSegment(comptime T: type) type {
    return struct {
        const Self = @This();
        const Pt = GenericPoint(T);

        p: Pt,
        q: Pt,

        pub fn init(p: Pt, q: Pt) Self {
            return Self{ .p = p, .q = q };
        }

        /// Twice the signed area of triangle (a, b, c): > 0 if c is left of a->b.
        pub inline fn orient(a: Pt, b: Pt, c: Pt) T {
            return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
        }

        inline fn sgn(v: T, eps_tol: T) i8 {
            if (v > eps_tol) return 1;
            if (v < -eps_tol) return -1;
            return 0;
        }

        /// `c` is assumed collinear with a-b: is it inside the bounding box of a-b?
        inline fn inBox(a: Pt, b: Pt, c: Pt, eps_tol: T) bool {
            return (c.x > @min(a.x, b.x) - eps_tol) and (c.x < @max(a.x, b.x) + eps_tol) and
                (c.y > @min(a.y, b.y) - eps_tol) and (c.y < @max(a.y, b.y) + eps_tol);
        }

        /// Orientation-based intersection. Touching / collinear overlap counts
        /// as an intersection (conservative for packing).
        pub fn intersects(self: Self, other: Self, eps_tol: T) bool {
            const a = self.p;
            const b = self.q;
            const c = other.p;
            const d = other.q;

            // Cheap bounding box rejection.
            if (@max(a.x, b.x) + eps_tol < @min(c.x, d.x)) return false;
            if (@max(c.x, d.x) + eps_tol < @min(a.x, b.x)) return false;
            if (@max(a.y, b.y) + eps_tol < @min(c.y, d.y)) return false;
            if (@max(c.y, d.y) + eps_tol < @min(a.y, b.y)) return false;

            const o1 = sgn(orient(a, b, c), eps_tol);
            const o2 = sgn(orient(a, b, d), eps_tol);
            const o3 = sgn(orient(c, d, a), eps_tol);
            const o4 = sgn(orient(c, d, b), eps_tol);

            if (o1 != o2 and o3 != o4) return true;

            // Collinear / touching special cases.
            if (o1 == 0 and inBox(a, b, c, eps_tol)) return true;
            if (o2 == 0 and inBox(a, b, d, eps_tol)) return true;
            if (o3 == 0 and inBox(c, d, a, eps_tol)) return true;
            if (o4 == 0 and inBox(c, d, b, eps_tol)) return true;
            return false;
        }

        pub fn contains(self: Self, point: Pt, eps_tol: T) bool {
            if (!inBox(self.p, self.q, point, eps_tol)) return false;
            return @abs(orient(self.p, self.q, point)) <= eps_tol;
        }
    };
}

pub const Segment = GenericSegment(default_float_type);

pub fn GenericTriangle(comptime T: type) type {
    return struct {
        const Self = @This();
        const Pt = GenericPoint(T);
        const Seg = GenericSegment(T);

        A: Pt,
        B: Pt,
        C: Pt,

        pub fn init(A: Pt, B: Pt, C: Pt) Self {
            return Self{ .A = A, .B = B, .C = C };
        }

        pub inline fn transform(self: Self, cos_t: T, sin_t: T, transl: Pt) Self {
            return Self.init(
                self.A.transform(cos_t, sin_t, transl),
                self.B.transform(cos_t, sin_t, transl),
                self.C.transform(cos_t, sin_t, transl),
            );
        }

        pub fn rotateAndThenTranslate(tri: Self, theta: T, transl: Pt) Self {
            return tri.transform(@cos(theta), @sin(theta), transl);
        }

        pub fn boundingBox(self: Self) GenericAlignedRectangle(T) {
            return .{
                .interval_x = .{
                    .A = @min(self.A.x, self.B.x, self.C.x),
                    .B = @max(self.A.x, self.B.x, self.C.x),
                },
                .interval_y = .{
                    .A = @min(self.A.y, self.B.y, self.C.y),
                    .B = @max(self.A.y, self.B.y, self.C.y),
                },
            };
        }

        pub fn edges(self: Self) [3]Seg {
            return .{
                Seg.init(self.A, self.B),
                Seg.init(self.B, self.C),
                Seg.init(self.C, self.A),
            };
        }

        pub fn intersects(self: Self, other: Self, eps_tol: T) bool {
            if (!self.boundingBox().intersects(other.boundingBox(), eps_tol)) {
                return false;
            }

            const self_edges = self.edges();
            const other_edges = other.edges();
            for (self_edges) |s| {
                for (other_edges) |o| {
                    if (s.intersects(o, eps_tol)) return true;
                }
            }

            // No edge crossing: one triangle may still lie entirely inside the other.
            return self.contains(other.A, eps_tol) or other.contains(self.A, eps_tol);
        }

        /// Point in triangle (boundary included), independent of orientation.
        pub fn contains(self: Self, point: Pt, eps_tol: T) bool {
            const d1 = Seg.orient(self.A, self.B, point);
            const d2 = Seg.orient(self.B, self.C, point);
            const d3 = Seg.orient(self.C, self.A, point);
            const has_neg = (d1 < -eps_tol) or (d2 < -eps_tol) or (d3 < -eps_tol);
            const has_pos = (d1 > eps_tol) or (d2 > eps_tol) or (d3 > eps_tol);
            return !(has_neg and has_pos);
        }
    };
}

pub const Triangle = GenericTriangle(default_float_type);

/// "Open triangle": the polyline A-B-C-D (edge D-A is NOT part of the shape).
pub fn GenericOpenTriangle(comptime T: type) type {
    return struct {
        const Self = @This();
        const Pt = GenericPoint(T);
        const Seg = GenericSegment(T);

        A: Pt,
        B: Pt,
        C: Pt,
        D: Pt,

        pub fn init(A: Pt, B: Pt, C: Pt, D: Pt) Self {
            return Self{ .A = A, .B = B, .C = C, .D = D };
        }

        pub inline fn transform(self: Self, cos_t: T, sin_t: T, transl: Pt) Self {
            return Self.init(
                self.A.transform(cos_t, sin_t, transl),
                self.B.transform(cos_t, sin_t, transl),
                self.C.transform(cos_t, sin_t, transl),
                self.D.transform(cos_t, sin_t, transl),
            );
        }

        pub fn rotateAndThenTranslate(tri: Self, theta: T, transl: Pt) Self {
            return tri.transform(@cos(theta), @sin(theta), transl);
        }

        pub fn boundingBox(self: Self) GenericAlignedRectangle(T) {
            return .{
                .interval_x = .{
                    .A = @min(self.A.x, self.B.x, self.C.x, self.D.x),
                    .B = @max(self.A.x, self.B.x, self.C.x, self.D.x),
                },
                .interval_y = .{
                    .A = @min(self.A.y, self.B.y, self.C.y, self.D.y),
                    .B = @max(self.A.y, self.B.y, self.C.y, self.D.y),
                },
            };
        }

        pub fn edges(self: Self) [3]Seg {
            return .{
                Seg.init(self.A, self.B),
                Seg.init(self.B, self.C),
                Seg.init(self.C, self.D),
            };
        }

        pub fn intersects(self: Self, other: GenericTriangle(T), eps_tol: T) bool {
            if (!self.boundingBox().intersects(other.boundingBox(), eps_tol)) {
                return false;
            }
            const self_edges = self.edges();
            const other_edges = other.edges();
            for (self_edges) |s| {
                for (other_edges) |o| {
                    if (s.intersects(o, eps_tol)) return true;
                }
            }
            return false;
        }

        pub fn intersectsOpen(self: Self, other: Self, eps_tol: T) bool {
            if (!self.boundingBox().intersects(other.boundingBox(), eps_tol)) {
                return false;
            }
            const self_edges = self.edges();
            const other_edges = other.edges();
            for (self_edges) |s| {
                for (other_edges) |o| {
                    if (s.intersects(o, eps_tol)) return true;
                }
            }
            return false;
        }

        pub fn contains(self: Self, point: Pt, eps_tol: T) bool {
            _ = self;
            _ = point;
            _ = eps_tol;
            return false;
        }
    };
}

pub const OpenTriangle = GenericOpenTriangle(default_float_type);

/// Christmas tree
///
/// Local frame (theta = 0, centre = origin):
///   top    tier : triangle (0,0.8) (±0.125,0.5)
///   middle tier : triangle (0,0.6136..) (±0.2,0.25)
///   bottom tier : triangle (0,0.35) (±0.35,0)
///   trunk       : rectangle x in [-0.075,0.075], y in [-0.2,0]
/// The union of these shapes is the tree polygon.
pub fn GenericChristmasTree(comptime T: type) type {
    return struct {
        const Self = @This();
        const Pt = GenericPoint(T);
        const Tri = GenericTriangle(T);
        const OTri = GenericOpenTriangle(T);
        const Circ = GenericCircle(T);
        const Rect = GenericAlignedRectangle(T);

        /// Safety margin added to every bounding circle radius.
        const radius_margin: T = 1e-7;

        // Note: geometry constants
        const local_circ_all = Circ{ .cx = 0.0, .cy = 0.29718697187, .radius = 0.50281303813 + radius_margin };
        const local_circ_big_top = Circ{ .cx = 0.0, .cy = 0.48863668636, .radius = 0.31136388371 + radius_margin };
        const local_circ_big_bottom = Circ{ .cx = 0.0, .cy = 0.0, .radius = 0.35 + radius_margin };
        const local_circ_bot_1 = Circ{ .cx = 0.21249249, .cy = 0.11249249, .radius = 0.17766043681 + radius_margin };
        const local_circ_bot_2 = Circ{ .cx = -0.21249249, .cy = 0.11249249, .radius = 0.17766043681 + radius_margin };
        const local_circ_trunk = Circ{ .cx = 0.0, .cy = -0.1, .radius = 0.125 + radius_margin };
        const local_circ_mid = Circ{ .cx = 0.0, .cy = 0.302822823, .radius = 0.20686872275 + radius_margin };
        const local_circ_top = Circ{ .cx = 0.0, .cy = 0.623873874, .radius = 0.17612712641 + radius_margin };

        const local_tri_top = Tri.init(
            Pt{ .x = 0.0, .y = 0.8 },
            Pt{ .x = 0.125, .y = 0.5 },
            Pt{ .x = -0.125, .y = 0.5 },
        );
        const local_tri_mid = Tri.init(
            Pt{ .x = 0.0, .y = 0.6136363636363636 },
            Pt{ .x = 0.2, .y = 0.25 },
            Pt{ .x = -0.2, .y = 0.25 },
        );
        const local_tri_bottom = Tri.init(
            Pt{ .x = 0.0, .y = 0.35 },
            Pt{ .x = 0.35, .y = 0.0 },
            Pt{ .x = -0.35, .y = 0.0 },
        );
        const local_tri_trunk = OTri.init(
            Pt{ .x = -0.075, .y = 0.0 },
            Pt{ .x = -0.075, .y = -0.2 },
            Pt{ .x = 0.075, .y = -0.2 },
            Pt{ .x = 0.075, .y = 0.0 },
        );

        bounding_box: Rect = Rect{
            .interval_x = .{ .A = -0.35, .B = 0.35 },
            .interval_y = .{ .A = -0.2, .B = 0.8 },
        },

        circ_all: Circ = local_circ_all,
        circ_big_top: Circ = local_circ_big_top,
        circ_big_bottom: Circ = local_circ_big_bottom,
        circ_bot_1: Circ = local_circ_bot_1,
        circ_bot_2: Circ = local_circ_bot_2,
        circ_trunk: Circ = local_circ_trunk,
        circ_mid: Circ = local_circ_mid,
        circ_top: Circ = local_circ_top,

        // Cached rotated + translated triangles.
        tri_top: Tri = local_tri_top,
        tri_mid: Tri = local_tri_mid,
        tri_bottom: Tri = local_tri_bottom,
        tri_trunk: OTri = local_tri_trunk,

        init_center: Pt = Pt{ .x = 0.0, .y = 0.0 },
        init_theta: T = 0.0,
        center: Pt = Pt{ .x = 0.0, .y = 0.0 },
        theta: T = 0.0,
        cos_theta: T = 1.0,
        sin_theta: T = 0.0,

        /// Extreme points of the convex hull of the tree. A bounding box of
        /// these five points is exact for every rotation.
        pub fn calcPointsOnBoundary(self: Self) [5]Pt {
            const c = self.cos_theta;
            const s = self.sin_theta;
            return .{
                (Pt{ .x = 0.0, .y = 0.8 }).transform(c, s, self.center),
                (Pt{ .x = 0.35, .y = 0.0 }).transform(c, s, self.center),
                (Pt{ .x = -0.35, .y = 0.0 }).transform(c, s, self.center),
                (Pt{ .x = 0.075, .y = -0.2 }).transform(c, s, self.center),
                (Pt{ .x = -0.075, .y = -0.2 }).transform(c, s, self.center),
            };
        }

        fn updateBoundingBox(self: *Self) void {
            const points = self.calcPointsOnBoundary();
            var min_x = points[0].x;
            var max_x = points[0].x;
            var min_y = points[0].y;
            var max_y = points[0].y;
            for (points[1..]) |p| {
                min_x = @min(min_x, p.x);
                max_x = @max(max_x, p.x);
                min_y = @min(min_y, p.y);
                max_y = @max(max_y, p.y);
            }
            self.bounding_box.interval_x.A = min_x;
            self.bounding_box.interval_x.B = max_x;
            self.bounding_box.interval_y.A = min_y;
            self.bounding_box.interval_y.B = max_y;
        }

        pub fn init(center: Pt, theta: T) Self {
            var tree = Self{};
            tree.init_center = center;
            tree.init_theta = theta;
            tree.update(0.0, Pt{ .x = 0.0, .y = 0.0 });
            return tree;
        }

        /// Place the tree at (init_center + delta_transl, init_theta + delta_theta).
        pub fn update(self: *Self, delta_theta: T, delta_transl: Pt) void {
            @setFloatMode(.optimized);
            const cx = self.init_center.x + delta_transl.x;
            const cy = self.init_center.y + delta_transl.y;
            const theta = self.init_theta + delta_theta;
            const c = @cos(theta);
            const s = @sin(theta);
            const t = Pt{ .x = cx, .y = cy };

            self.center = t;
            self.theta = theta;
            self.cos_theta = c;
            self.sin_theta = s;

            self.circ_all = local_circ_all.transform(c, s, t);
            self.circ_big_top = local_circ_big_top.transform(c, s, t);
            self.circ_big_bottom = local_circ_big_bottom.transform(c, s, t);
            self.circ_bot_1 = local_circ_bot_1.transform(c, s, t);
            self.circ_bot_2 = local_circ_bot_2.transform(c, s, t);
            self.circ_trunk = local_circ_trunk.transform(c, s, t);
            self.circ_mid = local_circ_mid.transform(c, s, t);
            self.circ_top = local_circ_top.transform(c, s, t);

            self.tri_top = local_tri_top.transform(c, s, t);
            self.tri_mid = local_tri_mid.transform(c, s, t);
            self.tri_bottom = local_tri_bottom.transform(c, s, t);
            self.tri_trunk = local_tri_trunk.transform(c, s, t);

            self.updateBoundingBox();
        }

        /// Does either of the two circles covering the bottom tier hit `c`?
        inline fn bottomHits(t: *const Self, c: Circ, eps_tol: T) bool {
            return t.circ_bot_1.intersects(c, eps_tol) or t.circ_bot_2.intersects(c, eps_tol);
        }

        /// Exact (up to eps_tol) overlap test between two trees.
        ///
        /// The tree is the union of top / mid / bottom triangles and the trunk.
        /// Each component is covered by a bounding circle (the bottom tier by
        /// two), and a pair of components is only tested exactly when their
        /// circles overlap. All 16 component pairs are covered by the 4 groups.
        pub fn intersects(self: Self, other: Self, eps_tol: T) bool {
            if (!self.bounding_box.intersects(other.bounding_box, eps_tol)) return false;
            if (!self.circ_all.intersects(other.circ_all, eps_tol)) return false;

            // Group 1: (top, mid) x (top, mid)
            if (self.circ_big_top.intersects(other.circ_big_top, eps_tol)) {
                if (self.circ_top.intersects(other.circ_top, eps_tol) and
                    self.tri_top.intersects(other.tri_top, eps_tol)) return true;
                if (self.circ_top.intersects(other.circ_mid, eps_tol) and
                    self.tri_top.intersects(other.tri_mid, eps_tol)) return true;
                if (self.circ_mid.intersects(other.circ_top, eps_tol) and
                    self.tri_mid.intersects(other.tri_top, eps_tol)) return true;
                if (self.circ_mid.intersects(other.circ_mid, eps_tol) and
                    self.tri_mid.intersects(other.tri_mid, eps_tol)) return true;
            }

            // Group 2: self (bottom, trunk) x other (top, mid)
            if (self.circ_big_bottom.intersects(other.circ_big_top, eps_tol)) {
                if (bottomHits(&self, other.circ_top, eps_tol) and
                    self.tri_bottom.intersects(other.tri_top, eps_tol)) return true;
                if (bottomHits(&self, other.circ_mid, eps_tol) and
                    self.tri_bottom.intersects(other.tri_mid, eps_tol)) return true;
                if (self.circ_trunk.intersects(other.circ_top, eps_tol) and
                    self.tri_trunk.intersects(other.tri_top, eps_tol)) return true;
                if (self.circ_trunk.intersects(other.circ_mid, eps_tol) and
                    self.tri_trunk.intersects(other.tri_mid, eps_tol)) return true;
            }

            // Group 3: self (top, mid) x other (bottom, trunk)
            if (self.circ_big_top.intersects(other.circ_big_bottom, eps_tol)) {
                if (bottomHits(&other, self.circ_top, eps_tol) and
                    self.tri_top.intersects(other.tri_bottom, eps_tol)) return true;
                if (bottomHits(&other, self.circ_mid, eps_tol) and
                    self.tri_mid.intersects(other.tri_bottom, eps_tol)) return true;
                if (self.circ_top.intersects(other.circ_trunk, eps_tol) and
                    other.tri_trunk.intersects(self.tri_top, eps_tol)) return true;
                if (self.circ_mid.intersects(other.circ_trunk, eps_tol) and
                    other.tri_trunk.intersects(self.tri_mid, eps_tol)) return true;
            }

            // Group 4: (bottom, trunk) x (bottom, trunk)
            if (self.circ_big_bottom.intersects(other.circ_big_bottom, eps_tol)) {
                const bottom_bottom =
                    self.circ_bot_1.intersects(other.circ_bot_1, eps_tol) or
                    self.circ_bot_1.intersects(other.circ_bot_2, eps_tol) or
                    self.circ_bot_2.intersects(other.circ_bot_1, eps_tol) or
                    self.circ_bot_2.intersects(other.circ_bot_2, eps_tol);
                if (bottom_bottom and self.tri_bottom.intersects(other.tri_bottom, eps_tol)) return true;

                if (bottomHits(&self, other.circ_trunk, eps_tol) and
                    other.tri_trunk.intersects(self.tri_bottom, eps_tol)) return true;
                if (bottomHits(&other, self.circ_trunk, eps_tol) and
                    self.tri_trunk.intersects(other.tri_bottom, eps_tol)) return true;

                if (self.circ_trunk.intersects(other.circ_trunk, eps_tol) and
                    self.tri_trunk.intersectsOpen(other.tri_trunk, eps_tol)) return true;
            }

            return false;
        }

        /// Point-in-tree test. The point is rotated into the tree's local frame
        /// so the constant local triangles/rectangle can be used.
        pub fn contains(self: Self, p: Pt, eps_tol: T) bool {
            if (!self.bounding_box.contains(p, eps_tol)) return false;
            if (!self.circ_all.contains(p, eps_tol)) return false;
            if (!self.circ_big_top.contains(p, eps_tol) and !self.circ_big_bottom.contains(p, eps_tol)) {
                return false;
            }

            const dx = p.x - self.center.x;
            const dy = p.y - self.center.y;
            const local = Pt{
                .x = dx * self.cos_theta + dy * self.sin_theta,
                .y = -dx * self.sin_theta + dy * self.cos_theta,
            };

            if (local_tri_top.contains(local, eps_tol)) return true;
            if (local_tri_mid.contains(local, eps_tol)) return true;
            if (local_tri_bottom.contains(local, eps_tol)) return true;

            // Trunk rectangle.
            return (local.x > -0.075 - eps_tol) and (local.x < 0.075 + eps_tol) and
                (local.y > -0.2 - eps_tol) and (local.y < 0.0 + eps_tol);
        }
    };
}

pub const ChristmasTree = GenericChristmasTree(default_float_type);

pub fn GenericShapeInterface(comptime T: type) type {
    return union(enum) {
        const Self = @This();

        segment: GenericSegment(T),
        triangle: GenericTriangle(T),
        circle: GenericCircle(T),
        christmas_tree: GenericChristmasTree(T),

        /// Only same-type pairs are supported.
        pub fn intersects(self: Self, other: Self, eps_tol: T) bool {
            if (std.meta.activeTag(self) != std.meta.activeTag(other)) {
                @panic("GenericShapeInterface.intersects: mixed shape types are not supported");
            }
            switch (self) {
                inline else => |case, tag| return case.intersects(@field(other, @tagName(tag)), eps_tol),
            }
        }

        pub fn contains(self: Self, point: GenericPoint(T), eps_tol: T) bool {
            switch (self) {
                inline else => |case| return case.contains(point, eps_tol),
            }
        }
    };
}

pub const Shape = GenericShapeInterface(default_float_type);
