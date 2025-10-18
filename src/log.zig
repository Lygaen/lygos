const std = @import("std");

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
