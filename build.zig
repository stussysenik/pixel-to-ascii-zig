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
    });

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
        wasm_exe.root_module.strip = true;
    }

    // Static library for native/SwiftUI targets
    const lib = b.addStaticLibrary(.{
        .name = "pixel-to-ascii",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib_install = b.addInstallArtifact(lib, .{});
    const lib_step = b.step("lib", "Build static library for native targets");
    lib_step.dependOn(&lib_install.step);

    // macOS arm64 static library
    const macos_target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .macos,
    });

    const macos_lib = b.addStaticLibrary(.{
        .name = "pixel-to-ascii",
        .root_source_file = b.path("src/main.zig"),
        .target = macos_target,
        .optimize = optimize,
    });

    const macos_install = b.addInstallArtifact(macos_lib, .{
        .dest_dir = .{ .custom = "macos" },
    });
    const macos_step = b.step("macos", "Build macOS arm64 static library");
    macos_step.dependOn(&macos_install.step);

    // iOS arm64 static library
    const ios_target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .ios,
    });

    const ios_lib = b.addStaticLibrary(.{
        .name = "pixel-to-ascii",
        .root_source_file = b.path("src/main.zig"),
        .target = ios_target,
        .optimize = optimize,
    });

    const ios_install = b.addInstallArtifact(ios_lib, .{
        .dest_dir = .{ .custom = "ios" },
    });
    const ios_step = b.step("ios", "Build iOS arm64 static library");
    ios_step.dependOn(&ios_install.step);

    // Complete build for web (WASM only — no external JS generator needed)
    const web_step = b.step("web", "Build for web (WASM module)");
    web_step.dependOn(&wasm_install.step);
}
