const log = @import("../log.zig");

pub fn hcf() noreturn {
    log.debug("Reached halt and catch fire", .{});
    while (true) {
        asm volatile ("hlt");
    }
}

pub fn loadIDT(addr: usize) void {
    asm volatile ("lidt (%[val])"
        :
        : [val] "rbx" (addr),
        : .{
          .memory = true,
        });
}

pub fn enableInterrupt() void {
    asm volatile ("sti");
}

pub fn disableInterrupts() void {
    asm volatile ("cli");
}
