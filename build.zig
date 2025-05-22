const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tracy_enable = b.option(bool, "tracy_enable", "Enable profiling") orelse true;
    const tracy_on_demand = b.option(bool, "tracy_on_demand", "On-demand profiling") orelse false;
    const tracy_callstack: ?u8 = b.option(u8, "tracy_callstack", "Enforce callstack collection for tracy regions");
    const tracy_no_callstack = b.option(bool, "tracy_no_callstack", "Disable all callstack related functionality") orelse false;
    const tracy_no_callstack_inlines = b.option(bool, "tracy_no_callstack_inlines", "Disables the inline functions in callstacks") orelse false;
    const tracy_only_localhost = b.option(bool, "tracy_only_localhost", "Only listen on the localhost interface") orelse false;
    const tracy_no_broadcast = b.option(bool, "tracy_no_broadcast", "Disable client discovery by broadcast to local network") orelse false;
    const tracy_only_ipv4 = b.option(bool, "tracy_only_ipv4", "Tracy will only accept connections on IPv4 addresses (disable IPv6)") orelse false;
    const tracy_no_code_transfer = b.option(bool, "tracy_no_code_transfer", "Disable collection of source code") orelse false;
    const tracy_no_context_switch = b.option(bool, "tracy_no_context_switch", "Disable capture of context switches") orelse false;
    const tracy_no_exit = b.option(bool, "tracy_no_exit", "Client executable does not exit until all profile data is sent to server") orelse false;
    const tracy_no_sampling = b.option(bool, "tracy_no_sampling", "Disable call stack sampling") orelse false;
    const tracy_no_verify = b.option(bool, "tracy_no_verify", "Disable zone validation for C API") orelse false;
    const tracy_no_vsync_capture = b.option(bool, "tracy_no_vsync_capture", "Disable capture of hardware Vsync events") orelse false;
    const tracy_no_frame_image = b.option(bool, "tracy_no_frame_image", "Disable the frame image support and its thread") orelse false;
    // NOTE For some reason system tracing on zig projects crashes tracy, will need to investigate
    const tracy_no_system_tracing = b.option(bool, "tracy_no_system_tracing", "Disable systrace sampling") orelse true;
    const tracy_delayed_init = b.option(bool, "tracy_delayed_init", "Enable delayed initialization of the library (init on first call)") orelse false;
    const tracy_manual_lifetime = b.option(bool, "tracy_manual_lifetime", "Enable the manual lifetime management of the profile") orelse false;
    const tracy_fibers = b.option(bool, "tracy_fibers", "Enable fibers support") orelse false;
    const tracy_no_crash_handler = b.option(bool, "tracy_no_crash_handler", "Disable crash handling") orelse false;
    const tracy_timer_fallback = b.option(bool, "tracy_timer_fallback", "Use lower resolution timers") orelse false;
    const shared = b.option(bool, "shared", "Build the tracy client as a shared libary") orelse false;

    const c_tracy = b.dependency("tracy_lib", .{});

    const options = b.addOptions();
    options.addOption(bool, "tracy_enable", tracy_enable);
    options.addOption(bool, "tracy_on_demand", tracy_on_demand);
    options.addOption(?u8, "tracy_callstack", tracy_callstack);
    options.addOption(bool, "tracy_no_callstack", tracy_no_callstack);
    options.addOption(bool, "tracy_no_callstack_inlines", tracy_no_callstack_inlines);
    options.addOption(bool, "tracy_only_localhost", tracy_only_localhost);
    options.addOption(bool, "tracy_no_broadcast", tracy_no_broadcast);
    options.addOption(bool, "tracy_only_ipv4", tracy_only_ipv4);
    options.addOption(bool, "tracy_no_code_transfer", tracy_no_code_transfer);
    options.addOption(bool, "tracy_no_context_switch", tracy_no_context_switch);
    options.addOption(bool, "tracy_no_exit", tracy_no_exit);
    options.addOption(bool, "tracy_no_sampling", tracy_no_sampling);
    options.addOption(bool, "tracy_no_verify", tracy_no_verify);
    options.addOption(bool, "tracy_no_vsync_capture", tracy_no_vsync_capture);
    options.addOption(bool, "tracy_no_frame_image", tracy_no_frame_image);
    options.addOption(bool, "tracy_no_system_tracing", tracy_no_system_tracing);
    options.addOption(bool, "tracy_delayed_init", tracy_delayed_init);
    options.addOption(bool, "tracy_manual_lifetime", tracy_manual_lifetime);
    options.addOption(bool, "tracy_fibers", tracy_fibers);
    options.addOption(bool, "tracy_no_crash_handler", tracy_no_crash_handler);
    options.addOption(bool, "tracy_timer_fallback", tracy_timer_fallback);
    options.addOption(bool, "shared", shared);

    const tracy_module = b.addModule("tracy", .{
        .root_source_file = b.path("./src/tracy.zig"),
        .imports = &.{
            .{
                .name = "tracy-options",
                .module = options.createModule(),
            },
        },
    });

    tracy_module.addIncludePath(c_tracy.path("public"));

    const tracy_client = if (shared) b.addSharedLibrary(.{
        .name = "tracy",
        .target = target,
        .optimize = optimize,
    }) else b.addStaticLibrary(.{
        .name = "tracy",
        .target = target,
        .optimize = optimize,
    });

    if (tracy_enable) {
        tracy_module.link_libcpp = true;
        tracy_module.linkLibrary(tracy_client);
    }

    if (target.result.os.tag == .windows) {
        tracy_client.linkSystemLibrary("dbghelp");
        tracy_client.linkSystemLibrary("ws2_32");
    }
    tracy_client.linkLibCpp();
    tracy_client.addCSourceFile(.{
        .file = c_tracy.path("public/TracyClient.cpp"),
        .flags = &.{},
    });
    if (tracy_enable)
        tracy_client.root_module.addCMacro("TRACY_ENABLE", "");
    if (tracy_on_demand)
        tracy_client.root_module.addCMacro("TRACY_ON_DEMAND", "");
    if (tracy_callstack) |depth| {
        tracy_client.root_module.addCMacro("TRACY_CALLSTACK", "" ++ digits2(depth) ++ "\"");
    }
    if (tracy_no_callstack)
        tracy_client.root_module.addCMacro("TRACY_NO_CALLSTACK", "");
    if (tracy_no_callstack_inlines)
        tracy_client.root_module.addCMacro("TRACY_NO_CALLSTACK_INLINES", "");
    if (tracy_only_localhost)
        tracy_client.root_module.addCMacro("TRACY_ONLY_LOCALHOST", "");
    if (tracy_no_broadcast)
        tracy_client.root_module.addCMacro("TRACY_NO_BROADCAST", "");
    if (tracy_only_ipv4)
        tracy_client.root_module.addCMacro("TRACY_ONLY_IPV4", "");
    if (tracy_no_code_transfer)
        tracy_client.root_module.addCMacro("TRACY_NO_CODE_TRANSFER", "");
    if (tracy_no_context_switch)
        tracy_client.root_module.addCMacro("TRACY_NO_CONTEXT_SWITCH", "");
    if (tracy_no_exit)
        tracy_client.root_module.addCMacro("TRACY_NO_EXIT", "");
    if (tracy_no_sampling)
        tracy_client.root_module.addCMacro("TRACY_NO_SAMPLING", "");
    if (tracy_no_verify)
        tracy_client.root_module.addCMacro("TRACY_NO_VERIFY", "");
    if (tracy_no_vsync_capture)
        tracy_client.root_module.addCMacro("TRACY_NO_VSYNC_CAPTURE", "");
    if (tracy_no_frame_image)
        tracy_client.root_module.addCMacro("TRACY_NO_FRAME_IMAGE", "");
    if (tracy_no_system_tracing)
        tracy_client.root_module.addCMacro("TRACY_NO_SYSTEM_TRACING", "");
    if (tracy_delayed_init)
        tracy_client.root_module.addCMacro("TRACY_DELAYED_INIT", "");
    if (tracy_manual_lifetime)
        tracy_client.root_module.addCMacro("TRACY_MANUAL_LIFETIME", "");
    if (tracy_fibers)
        tracy_client.root_module.addCMacro("TRACY_FIBERS", "");
    if (tracy_no_crash_handler)
        tracy_client.root_module.addCMacro("TRACY_NO_CRASH_HANDLER", "");
    if (tracy_timer_fallback)
        tracy_client.root_module.addCMacro("TRACY_TIMER_FALLBACK", "");
    if (shared and target.result.os.tag == .windows)
        tracy_client.root_module.addCMacro("TRACY_EXPORTS", "");
    b.installArtifact(tracy_client);
}

fn digits2(value: usize) [2]u8 {
    return ("0001020304050607080910111213141516171819" ++
        "2021222324252627282930313233343536373839" ++
        "4041424344454647484950515253545556575859" ++
        "6061626364656667686970717273747576777879" ++
        "8081828384858687888990919293949596979899")[value * 2 ..][0..2].*;
}
