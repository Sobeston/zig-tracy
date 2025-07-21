const std = @import("std");
const builtin = @import("builtin");
pub const options = @import("tracy-options");
const c = @cImport({
    if (options.tracy_enable) @cDefine("TRACY_ENABLE", {});
    if (options.tracy_on_demand) @cDefine("TRACY_ON_DEMAND", {});
    if (options.tracy_callstack) |depth| @cDefine(std.fmt.comptimePrint("TRACY_CALLSTACK \"{d}\"", .{depth}), {});
    if (options.tracy_no_callstack) @cDefine("TRACY_NO_CALLSTACK", {});
    if (options.tracy_no_callstack_inlines) @cDefine("TRACY_NO_CALLSTACK_INLINES", {});
    if (options.tracy_only_localhost) @cDefine("TRACY_ONLY_LOCALHOST", {});
    if (options.tracy_no_broadcast) @cDefine("TRACY_NO_BROADCAST", {});
    if (options.tracy_only_ipv4) @cDefine("TRACY_ONLY_IPV4", {});
    if (options.tracy_no_code_transfer) @cDefine("TRACY_NO_CODE_TRANSFER", {});
    if (options.tracy_no_context_switch) @cDefine("TRACY_NO_CONTEXT_SWITCH", {});
    if (options.tracy_no_exit) @cDefine("TRACY_NO_EXIT", {});
    if (options.tracy_no_sampling) @cDefine("TRACY_NO_SAMPLING", {});
    if (options.tracy_no_verify) @cDefine("TRACY_NO_VERIFY", {});
    if (options.tracy_no_vsync_capture) @cDefine("TRACY_NO_VSYNC_CAPTURE", {});
    if (options.tracy_no_frame_image) @cDefine("TRACY_NO_FRAME_IMAGE", {});
    if (options.tracy_no_system_tracing) @cDefine("TRACY_NO_SYSTEM_TRACING", {});
    if (options.tracy_delayed_init) @cDefine("TRACY_DELAYED_INIT", {});
    if (options.tracy_manual_lifetime) @cDefine("TRACY_MANUAL_LIFETIME", {});
    if (options.tracy_fibers) @cDefine("TRACY_FIBERS", {});
    if (options.tracy_no_crash_handler) @cDefine("TRACY_NO_CRASH_HANDLER", {});
    if (options.tracy_timer_fallback) @cDefine("TRACY_TIMER_FALLBACK", {});
    if (options.shared and builtin.os.tag == .windows) @cDefine("TRACY_IMPORTS", {});

    @cInclude("tracy/TracyC.h");
});

pub inline fn setThreadName(name: [:0]const u8) void {
    if (!options.tracy_enable) return;
    c.___tracy_set_thread_name(name);
}

pub inline fn startupProfiler() void {
    if (!options.tracy_enable) return;
    if (!options.tracy_manual_lifetime) return;
    c.___tracy_startup_profiler();
}

pub inline fn shutdownProfiler() void {
    if (!options.tracy_enable) return;
    if (!options.tracy_manual_lifetime) return;
    c.___tracy_shutdown_profiler();
}

pub inline fn isConnected() bool {
    if (!options.tracy_enable) return false;
    return c.___tracy_connected() > 0;
}

pub inline fn frameMark() void {
    if (!options.tracy_enable) return;
    c.___tracy_emit_frame_mark(null);
}

pub inline fn frameMarkNamed(name: [:0]const u8) void {
    if (!options.tracy_enable) return;
    c.___tracy_emit_frame_mark(name);
}

pub const DiscontinuousFrame = struct {
    name: [:0]const u8,

    pub inline fn end(frame: *const DiscontinuousFrame) void {
        if (!options.tracy_enable) return;
        c.___tracy_emit_frame_mark_end(frame.name);
    }
};

pub inline fn startDiscontinuousFrame(comptime name: [:0]const u8) DiscontinuousFrame {
    if (!options.tracy_enable) return .{ .name = name };
    c.___tracy_emit_frame_mark_start(name);
    return .{ .name = name };
}

pub inline fn frameImage(image: *anyopaque, width: u16, height: u16, offset: u8, flip: bool) void {
    if (!options.tracy_enable) return;
    c.___tracy_emit_frame_image(image, width, height, offset, @as(c_int, @intFromBool(flip)));
}

pub const ZoneOptions = struct {
    active: bool = true,
    name: ?[]const u8 = null,
    color: ?u32 = null,
};

pub const ZoneContext = struct {
    ctx: if (options.tracy_enable) c.___tracy_c_zone_context else void,

    pub inline fn end(zone: ZoneContext) void {
        if (!options.tracy_enable) return;
        c.___tracy_emit_zone_end(zone.ctx);
    }

    pub inline fn name(zone: ZoneContext, zone_name: []const u8) void {
        if (!options.tracy_enable) return;
        c.___tracy_emit_zone_name(zone.ctx, zone_name.ptr, zone_name.len);
    }

    pub inline fn text(zone: ZoneContext, zone_text: []const u8) void {
        if (!options.tracy_enable) return;
        c.___tracy_emit_zone_text(zone.ctx, zone_text.ptr, zone_text.len);
    }

    pub inline fn color(zone: ZoneContext, zone_color: u32) void {
        if (!options.tracy_enable) return;
        c.___tracy_emit_zone_color(zone.ctx, zone_color);
    }

    pub inline fn value(zone: ZoneContext, zone_value: u64) void {
        if (!options.tracy_enable) return;
        c.___tracy_emit_zone_value(zone.ctx, zone_value);
    }
} else struct {
    pub inline fn deinit(_: *const ZoneContext) void {}
    pub inline fn name(_: *const ZoneContext, _: []const u8) void {}
    pub inline fn text(_: *const ZoneContext, _: []const u8) void {}
    pub inline fn color(_: *const ZoneContext, _: u32) void {}
    pub inline fn value(_: *const ZoneContext, _: u64) void {}
};

fn toTracySrc(
    src: std.builtin.SourceLocation,
    name: ?[*:0]const u8,
) c.___tracy_source_location_data {
    return .{ .name = name, .file = src.file, .function = src.fn_name, .line = src.line, .color = 0 };
}

pub const Lockable = struct {
    ctx: if (options.tracy_enable) *c.__tracy_lockable_context_data else void,
    pub fn announce(src: std.builtin.SourceLocation, name: ?[*:0]const u8) Lockable {
        comptime if (!options.tracy_enable) return .{};
        return .{ .ctx = c.___tracy_announce_lockable_ctx(&toTracySrc(src, name)) orelse @panic("wat") };
    }
    pub fn terminate(self: *Lockable) void {
        comptime if (!options.tracy_enable) return;
        c.___tracy_terminate_lockable_ctx(self.ctx);
    }
    pub fn beforeLock(self: *Lockable) void {
        comptime if (!options.tracy_enable) return;
        _ = c.___tracy_before_lock_lockable_ctx(self.ctx);
    }
    pub fn afterLock(self: *Lockable) void {
        comptime if (!options.tracy_enable) return;
        c.___tracy_after_lock_lockable_ctx(self.ctx);
    }
    pub fn afterUnlock(self: *Lockable) void {
        comptime if (!options.tracy_enable) return;
        c.___tracy_after_unlock_lockable_ctx(self.ctx);
    }
    pub fn afterTryUnlock(self: *Lockable) void {
        comptime if (!options.tracy_enable) return;
        c.___tracy_after_try_lock_lockable_ctx(self.ctx);
    }
    pub fn mark(self: *Lockable, src: std.builtin.SourceLocation, name: ?[:0]const u8) void {
        comptime if (!options.tracy_enable) return;
        c.___tracy_mark_lockable_ctx(self.ctx, &toTracySrc(src, name));
    }
    pub fn customName(self: *Lockable, name: []const u8) void {
        comptime if (!options.tracy_enable) return;
        c.___tracy_custom_name_lockable_ctx(self.ctx, name.ptr, name.len);
    }
};

pub inline fn initZone(comptime src: std.builtin.SourceLocation, comptime opts: ZoneOptions) ZoneContext {
    if (!options.tracy_enable) return .{};
    const active: c_int = @intFromBool(opts.active);

    const src_loc = c.___tracy_source_location_data{
        .name = if (opts.name) |name| name.ptr else null,
        .function = src.fn_name.ptr,
        .file = src.file,
        .line = src.line,
        .color = opts.color orelse 0,
    };

    if (!options.tracy_no_callstack) {
        if (options.tracy_callstack) |depth| {
            return .{
                .ctx = c.___tracy_emit_zone_begin_callstack(&src_loc, depth, active),
            };
        }
    }

    return .{
        .ctx = c.___tracy_emit_zone_begin(&src_loc, active),
    };
}

pub inline fn plot(comptime T: type, name: [:0]const u8, value: T) void {
    if (!options.tracy_enable) return;

    const type_info = @typeInfo(T);
    switch (type_info) {
        .int => |int_type| {
            if (int_type.bits > 64) @compileError("Too large int to plot");
            if (int_type.signedness == .unsigned and int_type.bits > 63) @compileError("Too large unsigned int to plot");
            c.___tracy_emit_plot_int(name, @intCast(value));
        },
        .float => |float_type| {
            if (float_type.bits <= 32) {
                c.___tracy_emit_plot_float(name, @floatCast(value));
            } else if (float_type.bits <= 64) {
                c.___tracy_emit_plot(name, @floatCast(value));
            } else {
                @compileError("Too large float to plot");
            }
        },
        else => @compileError("Unsupported plot value type"),
    }
}

pub const PlotType = enum(c.TracyPlotFormatEnum) {
    Number = c.TracyPlotFormatNumber,
    Memory = c.TracyPlotFormatMemory,
    Percentage = c.TracyPlotFormatPercentage,
    Watt = c.TracyPlotFormatWatt,
};

pub const PlotConfig = struct {
    plot_type: PlotType,
    step: c_int,
    fill: c_int,
    color: u32,
};

pub inline fn plotConfig(name: [:0]const u8, config: PlotConfig) void {
    if (!options.tracy_enable) return;
    c.___tracy_emit_plot_config(
        name,
        @intFromEnum(config.plot_type),
        config.step,
        config.fill,
        config.color,
    );
}

pub inline fn message(msg: [:0]const u8) void {
    if (!options.tracy_enable) return;
    const depth = options.tracy_callstack orelse 0;
    c.___tracy_emit_messageL(msg, depth);
}

pub inline fn messageColor(msg: [:0]const u8, color: u32) void {
    if (!options.tracy_enable) return;
    const depth = options.tracy_callstack orelse 0;
    c.___tracy_emit_messageLC(msg, color, depth);
}

const tracy_message_buffer_size = if (options.tracy_enable) 4096 else 0;
threadlocal var tracy_message_buffer: [tracy_message_buffer_size]u8 = undefined;

pub inline fn print(comptime fmt: []const u8, args: anytype) void {
    if (!options.tracy_enable) return;
    const depth = options.tracy_callstack orelse 0;

    var stream = std.io.fixedBufferStream(&tracy_message_buffer);
    stream.writer().print(fmt, args) catch {};

    const written = stream.getWritten();
    c.___tracy_emit_message(written.ptr, written.len, depth);
}

pub inline fn printColor(comptime fmt: []const u8, args: anytype, color: u32) void {
    if (!options.tracy_enable) return;
    const depth = options.tracy_callstack orelse 0;

    var stream = std.io.fixedBufferStream(&tracy_message_buffer);
    stream.writer().print(fmt, args) catch {};

    const written = stream.getWritten();
    c.___tracy_emit_messageC(written.ptr, written.len, color, depth);
}

pub inline fn printAppInfo(comptime fmt: []const u8, args: anytype) void {
    if (!options.tracy_enable) return;

    var stream = std.io.fixedBufferStream(&tracy_message_buffer);
    stream.reset();
    stream.writer().print(fmt, args) catch {};

    const written = stream.getWritten();
    c.___tracy_emit_message_appinfo(written.ptr, written.len);
}

// @TODO: Add explicit support for area allocators when the discard emit comes out in stable tracy
pub const TracingAllocator = struct {
    pool_name: ?[:0]const u8,
    backing_allocator: std.mem.Allocator,

    const Self = @This();
    const Alignment = std.mem.Alignment;

    pub fn init(backing_allocator: std.mem.Allocator) Self {
        return .{
            .backing_allocator = backing_allocator,
            .pool_name = null,
        };
    }

    pub fn initNamed(pool_name: [:0]const u8, backing_allocator: std.mem.Allocator) Self {
        return .{
            .pool_name = pool_name,
            .backing_allocator = backing_allocator,
        };
    }

    pub fn allocator(self: *Self) std.mem.Allocator {
        if (!options.tracy_enable) return self.backing_allocator;

        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .remap = std.mem.Allocator.noRemap,
                .free = free,
            },
        };
    }

    fn alloc(
        ctx: *anyopaque,
        len: usize,
        ptr_align: std.mem.Alignment,
        ret_addr: usize,
    ) ?[*]u8 {
        const self: *Self = @ptrCast(@alignCast(ctx));
        const result = self.backing_allocator.rawAlloc(len, alignment, ret_addr);

        if (options.tracy_enable) {
            if (self.pool_name) |name| {
                c.___tracy_emit_memory_alloc_named(result, len, 0, name.ptr);
            } else {
                c.___tracy_emit_memory_alloc(result, len, 0);
            }
        }

        return result;
    }

    fn resize(
        ctx: *anyopaque,
        buf: []u8,
        buf_align: std.mem.Alignment,
        new_len: usize,
        ret_addr: usize,
    ) bool {
        const self: *Self = @ptrCast(@alignCast(ctx));
        const result = self.backing_allocator.rawResize(memory, alignment, new_len, ret_addr);

        if (options.tracy_enable) {
            if (self.pool_name) |name| {
                c.___tracy_emit_memory_free_named(memory.ptr, 0, name.ptr);
                c.___tracy_emit_memory_alloc_named(memory.ptr, new_len, 0, name.ptr);
            } else {
                c.___tracy_emit_memory_free(memory.ptr, 0);
                c.___tracy_emit_memory_alloc(memory.ptr, new_len, 0);
            }
        }

        return result;
    }

    fn free(
        ctx: *anyopaque,
        buf: []u8,
        buf_align: std.mem.Alignment,
        ret_addr: usize,
    ) void {
        const self: *Self = @ptrCast(@alignCast(ctx));
        self.backing_allocator.rawFree(memory, alignment, ret_addr);

        if (options.tracy_enable) {
            if (self.pool_name) |name| {
                c.___tracy_emit_memory_free_named(memory.ptr, 0, name.ptr);
            } else {
                c.___tracy_emit_memory_free(memory.ptr, 0);
            }
        }
    }
};
