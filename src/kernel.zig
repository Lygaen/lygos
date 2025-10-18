const std = @import("std");

const idt = @import("internals/idt.zig");
const limine = @import("limine.zig");
const log = @import("log.zig");

pub fn hcf() noreturn {
    log.debug("Reached halt and catch fire", .{});
    while (true) {
        asm volatile ("hlt");
    }
}

pub export fn _start() noreturn {
    log.init();
    log.info("Reached kernel entry", .{});

    if (!limine.isSupported())
        @panic("Limine version is not supported !");

    const has_framebuffers = limine.getFramebuffers();
    if (has_framebuffers == null)
        @panic("Limine didn't provide any framebuffers !");

    const fb = has_framebuffers.?[0];

    idt.load();
    idt.enable();

    { // Trigger a division by zero
        @setRuntimeSafety(false);
        const i = fb.width / (fb.width - fb.width);
        _ = i;
    }

    @panic("Kernel finished execution");
}

fn panicHandler(msg: []const u8, first_address: ?usize) noreturn {
    @branchHint(.cold);

    var st_it = std.debug.StackIterator.init(first_address, @frameAddress());
    if (first_address) |addr| {
        log.err("Panic at 0x{X:0>16} : {s}", .{ addr, msg });
    } else {
        log.err("Panic : {s}", .{msg});
    }

    var i: usize = 0;
    while (st_it.next()) |stack| : (i += 1) {
        log.err(" - #{d:0>2} - 0x{X:0>16}", .{ i, stack });
    }
    hcf();
}

pub const panic = std.debug.FullPanic(panicHandler);
