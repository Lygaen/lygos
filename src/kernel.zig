const std = @import("std");

const FBRenderer = @import("gui/fb_renderer.zig");
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

    var renderer: FBRenderer = .init(fb.address, fb.width, fb.height, fb.bpp, fb.pitch);

    renderer.clear(null);
    renderer.put_string("This is a\ntest string");

    arch.hcf();
}
