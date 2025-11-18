const log = @import("../log.zig");

pub const CPURing = enum(u2) {
    kernel = 0,
    device_low = 1,
    device_high = 2,
    user = 3,
};

pub const CodeSegmentSelector = packed struct(u16) {
    requested_permissions: CPURing,
    descriptor_table: enum(u1) {
        global,
        interrupt,
    },
    index: u13,
};

pub fn hcf() noreturn {
    log.debug("Reached halt and catch fire", .{});
    while (true) {
        asm volatile ("hlt");
    }
}

pub fn loadIDT(addr: usize) void {
    log.debug("Loading IDT from 0x{X:0>16}", .{addr});
    asm volatile ("lidt (%[val])"
        :
        : [val] "rbx" (addr),
        : .{
          .memory = true,
        });
}

pub fn loadGDT(addr: usize) void {
    log.debug("Loading GDT from 0x{X:0>16}", .{addr});
    asm volatile ("lgdt (%[val])"
        :
        : [val] "rbx" (addr),
        : .{
          .memory = true,
        });
}

pub fn enableInterrupt() void {
    log.debug("Enabling interrupts", .{});
    asm volatile ("sti");
}

pub fn disableInterrupts() void {
    log.debug("Disabling interrupts", .{});
    asm volatile ("cli");
}
