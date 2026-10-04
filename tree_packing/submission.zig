//! Read and write ChristmasTree positions as a CSV submission file.
//!
//! Format: a header line `id,x,y,theta` followed by one row per tree:
//! `id,x,y,theta` where (x, y) is the tree center and theta its rotation.

const std = @import("std");

const default_float_type = f64;

pub const Entry = struct {
    x: default_float_type,
    y: default_float_type,
    theta: default_float_type,
};

pub const Submission = struct {
    num_trees: usize = 0,
    entries: []Entry = &.{},

    pub fn deinit(self: *Submission, allocator: std.mem.Allocator) void {
        allocator.free(self.entries);
        self.* = .{};
    }

    /// Read a submission CSV from `path`. Returns the number of trees read.
    pub fn read(
        self: *Submission,
        allocator: std.mem.Allocator,
        io: std.Io,
        path: []const u8,
    ) !usize {
        const cwd = std.Io.Dir.cwd();
        const contents = try cwd.readFileAlloc(io, path, allocator, .limited(1 << 30));
        defer allocator.free(contents);

        var lines = std.mem.tokenizeAny(u8, contents, "\r\n");
        var num_read: usize = 0;
        var entries: std.ArrayList(Entry) = .empty;
        errdefer entries.deinit(allocator);

        while (lines.next()) |line| {
            if (line.len == 0) continue;
            var fields = std.mem.splitScalar(u8, line, ',');
            const id_field = fields.next() orelse continue;

            // Note: skip the header line
            _ = std.fmt.parseFloat(default_float_type, id_field) catch continue;

            var x_str = fields.next() orelse return error.MissingField;
            var y_str = fields.next() orelse return error.MissingField;
            var theta_str = fields.next() orelse return error.MissingField;

            if ('s' == x_str[0]) {
                x_str = x_str[1..];
            }
            if ('s' == y_str[0]) {
                y_str = y_str[1..];
            }
            if ('s' == theta_str[0]) {
                theta_str = theta_str[1..];
            }

            try entries.append(allocator, .{
                .x = try std.fmt.parseFloat(default_float_type, x_str),
                .y = try std.fmt.parseFloat(default_float_type, y_str),
                .theta = try std.fmt.parseFloat(default_float_type, theta_str),
            });
            num_read += 1;
        }

        self.entries = try entries.toOwnedSlice(allocator);
        self.num_trees = num_read;
        return num_read;
    }

    /// Write the submission CSV to `path`.
    pub fn write(self: Submission, allocator: std.mem.Allocator, io: std.Io, path: []const u8) !void {
        var buffer: std.Io.Writer.Allocating = .init(allocator);
        defer buffer.deinit();
        const writer = &buffer.writer;

        try writer.print("id,x,y,theta\n", .{});
        for (self.entries, 0..) |entry, idx| {
            try writer.print("{d},{d},{d},{d}\n", .{ idx, entry.x, entry.y, entry.theta });
        }

        const cwd = std.Io.Dir.cwd();
        const file = try cwd.createFile(io, path, .{});
        defer file.close(io);
        try file.writeStreamingAll(io, buffer.written());
    }
};
