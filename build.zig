const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });

    const zigimg_dep = b.dependency("zigimg", .{});

    // Note: pack executable
    const pack_module = b.createModule(.{
        .root_source_file = b.path("tree_packing/pack.zig"),
        .target = target,
        .optimize = optimize,
        .single_threaded = true,
    });
    pack_module.addImport("zigimg", zigimg_dep.module("zigimg"));

    const pack_exe = b.addExecutable(.{
        .name = "pack",
        .root_module = pack_module,
    });
    b.installArtifact(pack_exe);

    const run_pack = b.addRunArtifact(pack_exe);
    run_pack.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_pack.addArgs(args);
    }
    const run_step = b.step("run-pack", "Run the tree packer");
    run_step.dependOn(&run_pack.step);

    // Note: shapes unit tests
    const unit_tests_shapes = b.addTest(.{
        .name = "unit_tests_shapes",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tree_packing/unit_tests_shapes.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_tests_shapes = b.addRunArtifact(unit_tests_shapes);

    // Note: christmas trees unit tests
    const unit_tests_christmas_tree = b.addTest(.{
        .name = "unit_tests_christmas_tree",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tree_packing/unit_tests_christmas_tree.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_tests_christmas_tree = b.addRunArtifact(unit_tests_christmas_tree);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests_shapes.step);
    test_step.dependOn(&run_tests_christmas_tree.step);
}
