const std = @import("std");
const zigimg = @import("zigimg");
const xmas = @import("christmas_tree.zig");

const default_eps_tol = xmas.default_eps_tol;

pub const PixelValue = struct {
    red: u8,
    green: u8,
    blue: u8,
    alpha: u8,

    pub fn toBytes(self: PixelValue) [4]u8 {
        const bytes = [4]u8{ self.red, self.green, self.blue, self.alpha };
        return bytes;
    }
};

pub fn GenericImageRGBA(comptime T: type) type {
    return struct {
        num_rows: usize,
        num_cols: usize,
        interval_x: xmas.GenericInterval(T),
        interval_y: xmas.GenericInterval(T),
        bytes: []u8,

        pub fn init(
            allocator: std.mem.Allocator,
            num_rows: usize,
            num_cols: usize,
            interval_x: xmas.GenericInterval(T),
            interval_y: xmas.GenericInterval(T),
        ) !GenericImageRGBA(T) {
            const bytes = try allocator.alloc(u8, 4 * num_rows * num_cols);
            std.crypto.secureZero(u8, bytes);
            return .{
                .num_rows = num_rows,
                .num_cols = num_cols,
                .interval_x = interval_x,
                .interval_y = interval_y,
                .bytes = bytes,
            };
        }

        pub fn deinit(self: GenericImageRGBA(T), allocator: std.mem.Allocator) void {
            allocator.free(self.bytes);
        }

        pub fn set(self: GenericImageRGBA(T), row_i: usize, col_i: usize, pv: PixelValue) void {
            const idx = 4 * (self.num_cols * row_i + col_i);
            const pv_bytes = pv.toBytes();
            self.bytes[idx + 0] = pv_bytes[0];
            self.bytes[idx + 1] = pv_bytes[1];
            self.bytes[idx + 2] = pv_bytes[2];
            self.bytes[idx + 3] = pv_bytes[3];
        }

        pub fn setAll(self: GenericImageRGBA(T), pv: PixelValue) void {
            for (0..self.num_rows) |row_i| {
                for (0..self.num_cols) |col_i| {
                    self.set(row_i, col_i, pv);
                }
            }
        }

        pub fn drawShape(self: GenericImageRGBA(T), shape: xmas.GenericShapeInterface(T), pixel_value: PixelValue, dilation_eps: T) void {
            const step_x = (self.interval_x.B - self.interval_x.A) / @as(T, @floatFromInt(self.num_cols));
            const step_y = (self.interval_y.B - self.interval_y.A) / @as(T, @floatFromInt(self.num_rows));

            for (0..self.num_rows) |row_i| {
                for (0..self.num_cols) |col_i| {
                    const coord_x = self.interval_x.A + step_x * @as(T, @floatFromInt(col_i));
                    const coord_y = self.interval_y.B - step_y * @as(T, @floatFromInt(row_i));
                    const point = xmas.GenericPoint(T){ .x = coord_x, .y = coord_y };

                    if (shape.contains(point, dilation_eps)) {
                        self.set(row_i, col_i, pixel_value);
                    }
                }
            }
        }

        /// Save the image as a PNG file using the zigimg dependency.
        pub fn savePng(self: GenericImageRGBA(T), allocator: std.mem.Allocator, io: std.Io, path: []const u8) !void {
            var img = try zigimg.Image.create(allocator, self.num_cols, self.num_rows, .rgba32);
            defer img.deinit(allocator);

            @memcpy(@constCast(img.rawBytes()), self.bytes);

            const header = zigimg.formats.png.HeaderData{
                .width = @intCast(self.num_cols),
                .height = @intCast(self.num_rows),
                .bit_depth = 8,
                .color_type = .rgba_color,
                .compression_method = .deflate,
                .filter_method = .adaptive,
                .interlace_method = .none,
            };

            const cwd = std.Io.Dir.cwd();
            const file = try cwd.createFile(io, path, .{});
            defer file.close(io);

            var write_buffer: [64 * 1024]u8 = undefined;
            var write_stream = zigimg.io.WriteStream.initFile(io, file, &write_buffer);
            try zigimg.formats.png.PNG.write(allocator, &write_stream, img.pixels, header, .{});
            try write_stream.flush();
        }
    };
}
