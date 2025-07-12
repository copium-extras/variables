const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const dll_module = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const my_dll = b.addLibrary(.{
        .name = "my_module",
        .root_module = dll_module,
        .linkage = .dynamic,
    });

    // --- THE CORRECTED AND COMPLETE LIST OF SYSTEM LIBRARIES ---
    if (target.result.os.tag == .windows) {
        my_dll.linkSystemLibrary("kernel32");
        my_dll.linkSystemLibrary("user32");
        my_dll.linkSystemLibrary("gdi32");
        my_dll.linkSystemLibrary("winmm");
        my_dll.linkSystemLibrary("imm32");
        my_dll.linkSystemLibrary("ole32");
        my_dll.linkSystemLibrary("oleaut32");
        my_dll.linkSystemLibrary("version");
        my_dll.linkSystemLibrary("advapi32");
        my_dll.linkSystemLibrary("setupapi");
        my_dll.linkSystemLibrary("shell32");
    }

    b.installArtifact(my_dll);

    // --- Test Step ---
    const lib_unit_tests = b.addTest(.{
        .root_module = dll_module,
    });

    if (target.result.os.tag == .windows) {
        // Also add the necessary libs for testing
        lib_unit_tests.linkSystemLibrary("kernel32");
        lib_unit_tests.linkSystemLibrary("user32");
        lib_unit_tests.linkSystemLibrary("gdi32");
        lib_unit_tests.linkSystemLibrary("winmm");
        lib_unit_tests.linkSystemLibrary("imm32");
    }

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
