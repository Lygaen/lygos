const std = @import("std");
const builtin = @import("builtin");

const arch = @import("internals/arch.zig");

pub fn init() void {
    const ports: []const u16 = &.{COM1};
    for (ports) |port| {
        outb(port + 1, 0x00);
        outb(port + 3, 0x80);
        outb(port + 0, 0x03);
        outb(port + 1, 0x00);
        outb(port + 3, 0x03);
        outb(port + 2, 0xC7);
        outb(port + 4, 0x0B);
    }
}

var __com_writer: std.Io.Writer = .{
    .buffer = &.{}, // COM is a per-byte transfer, don't buffer anything !
    .vtable = &.{
        .rebase = std.Io.Writer.failingRebase,
        .flush = std.Io.Writer.noopFlush,
        .drain = comDrain,
    },
};

fn comDrain(_: *std.Io.Writer, data: []const []const u8, splat: usize) error{WriteFailed}!usize {
    var len: usize = 0;
    for (0..splat) |_| {
        for (data) |bytes| {
            for (bytes) |char| {
                while (!is_com_empty(COM1)) {}
                outb(COM1, char);
            }
            len += bytes.len;
        }
    }
    return len;
}

pub fn print(comptime fmt: []const u8, args: anytype) void {
    __com_writer.print(fmt, args) catch unreachable;
}

fn logFn(
    comptime message_level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    print("[{t}] ", .{message_level});

    if (scope != .default) {
        print("({}) ", .{scope});
    }
    print(format ++ "\n", args);
}

pub fn debug(comptime format: []const u8, args: anytype) void {
    logFn(.debug, .default, format, args);
}

pub fn info(comptime format: []const u8, args: anytype) void {
    logFn(.info, .default, format, args);
}

pub fn warn(comptime format: []const u8, args: anytype) void {
    logFn(.warn, .default, format, args);
}

pub fn err(comptime format: []const u8, args: anytype) void {
    logFn(.err, .default, format, args);
}

inline fn is_com_empty(port: comptime_int) bool {
    return (inb(port + 5) & 0x20) != 0;
}

/// GDB debug port
const COM1 = 0x3f8;

fn outb(port: u16, val: u8) void {
    asm volatile ("out %[val], %[port]"
        :
        : [val] "{al}" (val),
          [port] "{dx}" (port),
    );
}

fn inb(port: u16) u8 {
    return asm volatile ("in %[port], %[ret]"
        : [ret] "={al}" (-> u8),
        : [port] "{dx}" (port),
    );
}

/// Stolen from STD Lib, platform dependent code pruned
const StackIterator = union(enum) {
    /// We will first report the current PC of this `CpuContextPtr`, then we will switch to a
    /// different strategy to actually unwind.
    ctx_first: std.debug.CpuContextPtr,
    /// Naive frame-pointer-based unwinding. Very simple, but typically unreliable.
    fp: usize,

    /// It is important that this function is marked `inline` so that it can safely use
    /// `@frameAddress` and `cpu_context.Native.current` as the caller's stack frame and
    /// our own are one and the same.
    ///
    /// `opt_context_ptr` must remain valid while the `StackIterator` is used.
    inline fn init(opt_context_ptr: std.debug.CpuContextPtr) StackIterator {
        return .{ .ctx_first = opt_context_ptr };
    }

    const Result = union(enum) {
        /// A stack frame has been found; this is the corresponding return address.
        frame: usize,
        /// The end of the stack has been reached.
        end,
    };

    fn next(it: *StackIterator) Result {
        switch (it.*) {
            .ctx_first => |context_ptr| {
                it.* = .{ .fp = context_ptr.getFp() };
                return .{ .frame = context_ptr.getPc() +| 1 };
            },
            .fp => |fp| {
                if (fp == 0) return .end; // we reached the "sentinel" base pointer

                const bp_addr = applyOffset(fp, 0) orelse return .end;
                const ra_addr = applyOffset(fp, @sizeOf(usize)) orelse return .end;

                if (bp_addr == 0 or !std.mem.isAligned(bp_addr, @alignOf(usize)) or
                    ra_addr == 0 or !std.mem.isAligned(ra_addr, @alignOf(usize)))
                {
                    // This isn't valid, but it most likely indicates end of stack.
                    return .end;
                }

                const bp_ptr: *const usize = @ptrFromInt(bp_addr);
                const ra_ptr: *const usize = @ptrFromInt(ra_addr);
                const bp = applyOffset(bp_ptr.*, 0) orelse return .end;

                // If the stack grows downwards, `bp > fp` should always hold; conversely, if it
                // grows upwards, `bp < fp` should always hold. If that is not the case, this
                // frame is invalid, so we'll treat it as though we reached end of stack. The
                // exception is address 0, which is a graceful end-of-stack signal, in which case
                // *this* return address is valid and the *next* iteration will be the last.
                if (bp != 0 and switch (comptime builtin.target.stackGrowth()) {
                    .down => bp <= fp,
                    .up => bp >= fp,
                }) return .end;

                it.fp = bp;
                const ra = std.debug.stripInstructionPtrAuthCode(ra_ptr.*);
                if (ra <= 1) return .end;
                return .{ .frame = ra };
            },
        }
    }

    fn applyOffset(addr: usize, comptime off: comptime_int) ?usize {
        if (off >= 0) return std.math.add(usize, addr, off) catch return null;
        return std.math.sub(usize, addr, -off) catch return null;
    }
};

fn panicHandler(msg: []const u8, first_address: ?usize) noreturn {
    @branchHint(.cold);

    const cpu_ctx: std.debug.cpu_context.Native = .current();
    var st_it: StackIterator = .init(&cpu_ctx);
    if (first_address) |addr| {
        err("Panic at 0x{X:0>16} : {s}", .{ addr, msg });
    } else {
        err("Panic : {s}", .{msg});
    }

    var i: usize = 0;
    var ptr = st_it.next();

    while (ptr != .end) : (i += 1) {
        err(" - #{d:0>2} - 0x{X:0>16}", .{ i, ptr.frame });

        ptr = st_it.next();
    }
    arch.hcf();
}

pub const panic = std.debug.FullPanic(panicHandler);
