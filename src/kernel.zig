const std = @import("std");

const arch = @import("internals/arch.zig");
const gdt = @import("internals/gdt.zig");
const idt = @import("internals/idt.zig");
const limine = @import("limine.zig");
const log = @import("log.zig");
pub const panic = log.panic;

pub export fn _start() noreturn {
    log.init();
    log.info("Reached kernel entry", .{});

    if (!limine.isSupported())
        @panic("Limine version is not supported !");

    const has_framebuffers = limine.getFramebuffers();
    if (has_framebuffers == null)
        @panic("Limine didn't provide any framebuffers !");

    const fb = has_framebuffers.?[0];

    arch.disableInterrupts();
    gdt.load();
    idt.load();
    arch.enableInterrupt();

    { // Trigger a division by zero
        @setRuntimeSafety(false);
        const i = fb.width / (fb.width - fb.width);
        _ = i;
    }

    @panic("Kernel finished execution");
}
