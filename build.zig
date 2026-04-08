const std = @import("std");

const examples = [_][]const u8{
    "hello",
    "spark-counter",
    "plasma-counter",
    "secret-jwt",
    "websocket-echo",
    "beam-fetch",
    "edge-ops",
};

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    const host_target = b.standardTargetOptions(.{});

    const flaron_module = b.addModule("flaron", .{
        .root_source_file = b.path("src/root.zig"),
    });

    const test_module = b.createModule(.{
        .root_source_file = b.path("tests/all_tests.zig"),
        .target = host_target,
        .optimize = optimize,
    });
    test_module.addImport("flaron", flaron_module);

    const tests = b.addTest(.{ .root_module = test_module });
    const run_tests = b.addRunArtifact(tests);
    run_tests.has_side_effects = true;

    const test_step = b.step("test", "Run unit tests on the host");
    test_step.dependOn(&run_tests.step);

    const examples_step = b.step("examples", "Build all example flares");

    inline for (examples) |name| {
        const example_module = b.createModule(.{
            .root_source_file = b.path("examples/" ++ name ++ "/flare.zig"),
            .target = wasm_target,
            .optimize = .ReleaseSmall,
        });
        example_module.addImport("flaron", flaron_module);

        const example_exe = b.addExecutable(.{
            .name = name,
            .root_module = example_module,
        });
        example_exe.entry = .disabled;
        example_exe.rdynamic = true;

        const install = b.addInstallArtifact(example_exe, .{});
        examples_step.dependOn(&install.step);
        b.getInstallStep().dependOn(&install.step);
    }
}
