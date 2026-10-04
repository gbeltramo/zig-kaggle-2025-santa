const xmas = @import("christmas_tree.zig");

pub fn Generic(comptime T: type) type {
    return struct {
        pub fn calcStepValues(values: []T, min_value: T, max_value: T) void {
            for (0..values.len - 1) |idx| {
                const idx_float: T = @floatFromInt(idx);
                const num_float: T = @floatFromInt(values.len - 1);
                values[idx] = idx_float * (max_value - min_value) / num_float + min_value;
            }
            values[values.len - 1] = max_value;
        }

        pub fn calcScore(current_trees: []xmas.GenericChristmasTree(T)) T {
            const num_trees = current_trees.len;

            const max_num_trees: usize = 200;
            var min_x_bounds: [max_num_trees]T = undefined;
            var max_x_bounds: [max_num_trees]T = undefined;
            var min_y_bounds: [max_num_trees]T = undefined;
            var max_y_bounds: [max_num_trees]T = undefined;

            for (0..num_trees) |idx_tree| {
                min_x_bounds[idx_tree] = current_trees[idx_tree].bounding_box.interval_x.A;
                max_x_bounds[idx_tree] = current_trees[idx_tree].bounding_box.interval_x.B;
                min_y_bounds[idx_tree] = current_trees[idx_tree].bounding_box.interval_y.A;
                max_y_bounds[idx_tree] = current_trees[idx_tree].bounding_box.interval_y.B;
            }

            const min_x_coord = calcMinimum(&min_x_bounds, num_trees);
            const max_x_coord = calcMaximum(&max_x_bounds, num_trees);

            const min_y_coord = calcMinimum(&min_y_bounds, num_trees);
            const max_y_coord = calcMaximum(&max_y_bounds, num_trees);

            const side_length_x = max_x_coord - min_x_coord;
            const side_length_y = max_y_coord - min_y_coord;
            const side_length = @max(side_length_x, side_length_y);

            return side_length;
        }

        pub fn calcScoreAndPackCoeff(current_trees: []xmas.GenericChristmasTree(T)) [2]T {
            const num_trees = current_trees.len;

            const max_num_trees: usize = 200;
            var min_x_bounds: [max_num_trees]T = undefined;
            var max_x_bounds: [max_num_trees]T = undefined;
            var min_y_bounds: [max_num_trees]T = undefined;
            var max_y_bounds: [max_num_trees]T = undefined;

            for (0..num_trees) |idx_tree| {
                min_x_bounds[idx_tree] = current_trees[idx_tree].bounding_box.interval_x.A;
                max_x_bounds[idx_tree] = current_trees[idx_tree].bounding_box.interval_x.B;
                min_y_bounds[idx_tree] = current_trees[idx_tree].bounding_box.interval_y.A;
                max_y_bounds[idx_tree] = current_trees[idx_tree].bounding_box.interval_y.B;
            }

            const min_x_coord = calcMinimum(&min_x_bounds, num_trees);
            const max_x_coord = calcMaximum(&max_x_bounds, num_trees);

            const min_y_coord = calcMinimum(&min_y_bounds, num_trees);
            const max_y_coord = calcMaximum(&max_y_bounds, num_trees);

            const side_length_x = max_x_coord - min_x_coord;
            const side_length_y = max_y_coord - min_y_coord;

            const center_bbox_x = (max_x_coord + min_x_coord) / 2.0;
            const center_bbox_y = (max_y_coord + min_y_coord) / 2.0;

            var pack_coeff: T = 0.0;

            for (current_trees) |tmp_tree| {
                const diff_x = @max(
                    @abs(tmp_tree.bounding_box.interval_x.A - center_bbox_x),
                    @abs(tmp_tree.bounding_box.interval_x.B - center_bbox_x),
                );
                const diff_y = @max(
                    @abs(tmp_tree.bounding_box.interval_y.A - center_bbox_y),
                    @abs(tmp_tree.bounding_box.interval_y.B - center_bbox_y),
                );
                pack_coeff += (diff_x + diff_y);
            }

            const side_length = @max(side_length_x, side_length_y);

            return [2]T{ side_length, pack_coeff };
        }

        pub fn calcMinimum(values: []T, n: usize) T {
            var minimum: T = values[0];

            for (0..n) |i| {
                const v = values[i];
                if (v < minimum) {
                    minimum = v;
                }
            }

            return minimum;
        }

        pub fn calcMaximum(values: []T, n: usize) T {
            var maximum: T = values[0];

            for (0..n) |i| {
                const v = values[i];
                if (v > maximum) {
                    maximum = v;
                }
            }

            return maximum;
        }
    };
}
