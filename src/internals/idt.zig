const std = @import("std");

const log = @import("../log.zig");

const Entry = packed struct(u128) {
    offset_l: u16,
    selector: u16,
    __1cero: u8,
    flags: u8,
    offset_m: u16,
    offset_h: u32,
    __2cero: u32,
};

const LIDTPayload = packed struct(u80) {
    size: u16,
    addr: u64,
};

const ItemIndex = enum(u8) {
    divide_error = 0x00,
    debug_exception = 0x01,
    nmi_interrupt = 0x02,
    breakpoint = 0x03,
    overflow = 0x04,
    range_exceeded = 0x05,
    invalid_opcode = 0x06,
    no_math_coprocessor = 0x07,
    double_fault = 0x08,
};

var __idt: [256]Entry = @splat(std.mem.zeroes(Entry));

pub fn registerEntry(index: ItemIndex, func: *const anyopaque) void {
    const ptr = &__idt[@intFromEnum(index)];
    const addr = @intFromPtr(func);

    ptr.* = std.mem.zeroes(Entry);

    ptr.selector = 0x08;
    ptr.flags = 0x8E; // 0x8F -> trap, 0x8E -> int

    ptr.offset_l = @truncate(addr);
    ptr.offset_m = @truncate(addr >> 16);
    ptr.offset_h = @truncate(addr >> 32);
}

pub export fn divisor() callconv(.{ .x86_64_interrupt = .{} }) void {
    while (true) {}
}

var __idt_register: LIDTPayload = undefined;
pub fn load() void {
    registerEntry(.divide_error, &divisor);

    __idt_register = .{
        .size = (__idt.len * @sizeOf(Entry)) - 1,
        .addr = @intFromPtr(&__idt),
    };

    asm volatile ("lidt %[val]"
        :
        : [val] "m" (&__idt_register),
        : .{
          .memory = true,
        });
}

pub fn enable() void {
    asm volatile ("sti");
}

pub fn disable() void {
    asm volatile ("cli");
}
