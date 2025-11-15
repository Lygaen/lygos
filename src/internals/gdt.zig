const std = @import("std");

const arch = @import("arch.zig");

const LGDTPayload = packed struct(u80) {
    size: u16,
    addr: u64,
};

const Entry = packed struct(u64) {
    limit_low: u16,
    base_low: u24,
    access: packed struct(u8) {
        accessed: bool,
        /// Readable for code, writable for data
        rw: bool,
        /// For data indicates whether the segment
        /// grows down, for code indicates whether to
        /// enable privilege conformance
        direction_conforming: bool,
        executable: bool,
        descriptor_type: enum(u1) {
            system_segment = 0,
            code_data_segment = 1,
        },
        privilege: arch.CPURing,
        presence: bool,
    },
    limit_high: u4,
    flags: packed struct(u4) {
        __cero: u1 = 0,
        size: enum(u2) {
            long = 0b01,
            mode_32 = 0b10,
            mode_16 = 0b00,
        },
        is_page_granular: bool,
    },
    base_high: u8,
};

var __gdt = [_]Entry{
    std.mem.zeroes(Entry),
    // Kernel code
    Entry{
        .base_high = 0,
        .base_low = 0,
        .limit_low = 0xFFFF,
        .limit_high = 0xF,
        .flags = .{
            .is_page_granular = true,
            .size = .long,
        },
        .access = .{
            .accessed = false,
            .rw = true,
            .direction_conforming = false,
            .executable = true,
            .descriptor_type = .code_data_segment,
            .privilege = .kernel,
            .presence = true,
        },
    },
    // Kernel data
    Entry{
        .base_high = 0,
        .base_low = 0,
        .limit_low = 0xFFFF,
        .limit_high = 0xF,
        .flags = .{
            .is_page_granular = true,
            .size = .long,
        },
        .access = .{
            .accessed = false,
            .rw = true,
            .direction_conforming = false,
            .executable = false,
            .descriptor_type = .code_data_segment,
            .privilege = .kernel,
            .presence = true,
        },
    },
    // User code
    Entry{
        .base_high = 0,
        .base_low = 0,
        .limit_low = 0xFFFF,
        .limit_high = 0xF,
        .flags = .{
            .is_page_granular = true,
            .size = .long,
        },
        .access = .{
            .accessed = false,
            .rw = true,
            .direction_conforming = false,
            .executable = true,
            .descriptor_type = .code_data_segment,
            .privilege = .user,
            .presence = true,
        },
    },
    // User data
    Entry{
        .base_high = 0,
        .base_low = 0,
        .limit_low = 0xFFFF,
        .limit_high = 0xF,
        .flags = .{
            .is_page_granular = true,
            .size = .long,
        },
        .access = .{
            .accessed = false,
            .rw = true,
            .direction_conforming = false,
            .executable = false,
            .descriptor_type = .code_data_segment,
            .privilege = .user,
            .presence = true,
        },
    },
};

pub const Index = enum(u13) {
    kernel_code = 1,
    kernel_data = 2,
    user_code = 3,
    user_data = 4,
};

var __gdt_payload: LGDTPayload = undefined;

pub fn load() void {
    __gdt_payload = .{
        .size = (__gdt.len * @sizeOf(Entry)) - 1,
        .addr = @intFromPtr(&__gdt),
    };

    arch.loadGDT(@intFromPtr(&__gdt_payload));
}
