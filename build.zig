const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "clipnotify",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = true,
    });
    exe.linkLibC();
    exe.linkSystemLibrary("X11");
    exe.linkSystemLibrary("xfixes");

    b.installArtifact(exe);
}
