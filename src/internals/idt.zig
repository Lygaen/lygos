const std = @import("std");

const log = @import("../log.zig");
const arch = @import("arch.zig");

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
    debug_exception,
    nmi_interrupt,
    breakpoint,
    overflow,
    range_exceeded,
    invalid_opcode,
    no_math_coprocessor,
    double_fault,
    coprocessor_segment_overrun,
    invalid_tss,
    segment_not_present,
    stack_segment_fault,
    general_protection,
    page_fault,
    __intel_reserved,
    floating_point_error,
    alignment_check,
    machine_check,
    simd_floating_point_exception,
    virtualization_exception,
    control_protection_exception,

    const __errors_bound = [_]ItemIndex{
        .double_fault,
        .invalid_tss,
        .segment_not_present,
        .stack_segment_fault,
        .general_protection,
        .page_fault,
        .alignment_check,
        .control_protection_exception,
    };

    pub fn hasError(self: ItemIndex) bool {
        return std.mem.containsAtLeastScalar(ItemIndex, &__errors_bound, 1, self);
    }

    const __trap_bound = [_]ItemIndex{
        .debug_exception,
        .breakpoint,
        .overflow,
    };

    pub fn isTrap(self: ItemIndex) bool {
        return std.mem.containsAtLeastScalar(ItemIndex, &__trap_bound, 1, self);
    }
};

const InterruptFrame = struct {
    rip: u64,
    cs: u64,
    rflags: u64,
    rsp: u64,
    ss: u64,
};

var __idt: [256]Entry = @splat(std.mem.zeroes(Entry));

pub fn registerEntry(index: ItemIndex, func: *const anyopaque) void {
    const ptr = &__idt[@intFromEnum(index)];
    const addr = @intFromPtr(func);

    ptr.* = std.mem.zeroes(Entry);

    ptr.selector = 0x28;

    // 0x8F -> trap, 0x8E -> int
    if (index.isTrap()) {
        ptr.flags = 0x8F;
    } else {
        ptr.flags = 0x8F;
    }

    ptr.offset_l = @truncate(addr);
    ptr.offset_m = @truncate(addr >> 16);
    ptr.offset_h = @truncate(addr >> 32);
}

fn interruptHandler(comptime index: ItemIndex) *const anyopaque {
    if (!@inComptime())
        @compileError("This must be called at comptime ! Add a comptime prefix at call site.");

    var ptr: *const anyopaque = undefined;

    if (index.hasError()) {
        ptr = struct {
            pub fn handler(frame: *InterruptFrame) callconv(.{ .x86_64_interrupt = .{} }) void {
                log.err("Interrupt called : '{s}', frame :", .{@tagName(index)});

                inline for (std.meta.fields(InterruptFrame)) |field| {
                    log.err(" - {s: >6}: 0x{X:0>16}", .{ field.name, @field(frame, field.name) });
                }

                if (!index.isTrap())
                    arch.hcf();
            }
        }.handler;
    } else {
        ptr = struct {
            pub fn handler(frame: *InterruptFrame, err: u64) callconv(.{ .x86_64_interrupt = .{} }) void {
                log.err("Interrupt called : '{s}' (err: 0x{X}), frame :", .{ @tagName(index), err });

                inline for (std.meta.fields(InterruptFrame)) |field| {
                    log.err(" - {s: >6}: 0x{X:0>16}", .{ field.name, @field(frame, field.name) });
                }

                if (!index.isTrap())
                    arch.hcf();
            }
        }.handler;
    }

    @export(ptr, .{
        .linkage = .strong,
        .name = "handler_" ++ @tagName(index),
    });

    return ptr;
}

var __idt_register: LIDTPayload = undefined;
pub fn load() void {
    inline for (@typeInfo(ItemIndex).@"enum".fields) |field| {
        const val: ItemIndex = @enumFromInt(field.value);

        registerEntry(val, comptime interruptHandler(val));
    }

    __idt_register = .{
        .size = (__idt.len * @sizeOf(Entry)) - 1,
        .addr = @intFromPtr(&__idt),
    };

    arch.loadIDT(@intFromPtr(&__idt_register));
}
