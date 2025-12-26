const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the executable
    const exe = b.addExecutable(.{
        .name = "pixel-to-ascii",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Install the executable
    b.installArtifact(exe);

    // Run step for local development
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Unit tests
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // WebAssembly build
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    }) catch unreachable;

    const wasm_exe = b.addExecutable(.{
        .name = "pixel-to-ascii-wasm",
        .root_source_file = b.path("src/main.zig"),
        .target = wasm_target,
        .optimize = optimize,
    });

    // Configure WASM for browser/JavaScript interop
    wasm_exe.rdynamic = true; // Export all public functions
    wasm_exe.entry = .disabled; // Don't generate standard entry point
    wasm_exe.import_memory = true; // Allow JavaScript to access WASM memory

    // WASM-specific build steps
    const wasm_install = b.addInstallArtifact(wasm_exe, .{
        .dest_dir = .{ .custom = "" },
    });
    b.getInstallStep().dependOn(&wasm_install.step);

    // WASM build step
    const wasm_step = b.step("wasm", "Build WebAssembly module");
    wasm_step.dependOn(&wasm_install.step);

    // Optimize WASM output
    if (optimize != .Debug) {
        // Strip symbols for release builds
        wasm_exe.strip = true;
    }

    // Generate JavaScript bindings
    const js_bindings = b.addExecutable(.{
        .name = "generate-js-bindings",
        .root_source_file = b.path("tools/generate_js.zig"),
        .target = b.host,
    });

    const generate_js = b.addRunArtifact(js_bindings);
    generate_js.addArg("--wasm");
    generate_js.addFileArg(wasm_exe.getEmittedBin());
    generate_js.addFileArg(b.path("src/main.zig"));
    generate_js.addArg("--output");
    generate_js.addFileArg(b.path("dist/pixel-to-ascii-wasm.js"));

    const js_step = b.step("js", "Generate JavaScript bindings");
    js_step.dependOn(&generate_js.step);
    wasm_step.dependOn(&js_step);

    // Complete build for web (WASM + JS)
    const web_step = b.step("web", "Build for web (WASM + JS bindings)");
    web_step.dependOn(&wasm_install.step);
    web_step.dependOn(&js_step);
}
