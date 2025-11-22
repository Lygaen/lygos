const std = @import("std");

const log = @import("../log.zig");
const psf_font = @import("psf_font.zig");

const FBRenderer = @This();

/// Color in format RGB
pub const Color = enum(u24) {
    black = 0x000000,
    white = 0xFFFFFF,
    silver = 0xC0C0C0,
    gray = 0x808080,
    red = 0xFF0000,
    maroon = 0x800000,
    yellow = 0xFFFF00,
    olive = 0x808000,
    lime = 0x00FF00,
    green = 0x008000,
    aqua = 0x00FFFF,
    teal = 0x008080,
    blue = 0x0000FF,
    navy = 0x000080,
    fuschia = 0xFF00FF,
    purple = 0x800080,
    _,

    /// Converts to correct byte order,
    /// aka. RGB for big endian and
    /// BGR for native
    pub fn toNative(self: Color) u32 {
        return std.mem.toNative(u24, @intFromEnum(self), .big);
    }
};

framebuffer: []u8,

width: usize,
height: usize,

pixel_stride: usize,
line_stride: usize,

char_cursor: struct {
    x: usize,
    y: usize,
},
foreground: Color,
background: Color,

pub fn init(address: *anyopaque, width: usize, height: usize, bpp: usize, pitch: usize) FBRenderer {
    const final_index = @divExact(bpp, 8) * width + pitch * height;

    return .{
        .framebuffer = @as([*]u8, @ptrCast(address))[0..final_index],
        .height = height,
        .width = width,
        .pixel_stride = @divExact(bpp, 8),
        .line_stride = pitch,
        .char_cursor = .{ .x = 0, .y = 0 },
        .foreground = .white,
        .background = .black,
    };
}

fn indexFromCoordinate(self: FBRenderer, x: usize, y: usize) usize {
    return self.pixel_stride * x + self.line_stride * y;
}

pub fn put_char(self: FBRenderer, char: u21) void {
    var iter = psf_font.DefaultFont.getIter(char);
    var options: psf_font.PSFFontOptions = psf_font.DefaultFont.getOptions();

    const start_x: usize = options.width * self.char_cursor.x;
    var x = start_x;
    var y = options.height * self.char_cursor.y;
    while (iter.next()) |element| {
        if (element.is_on) {
            self.put_color(x, y, self.foreground);
        }
        x += 1;
        if (element.is_new_line) {
            y += 1;
            x = start_x;
        }
    }
}

pub fn put_string(self: *FBRenderer, str: []const u8) void {
    var view = std.unicode.Utf8View.init(str) catch return;
    const str_width = std.unicode.utf8CountCodepoints(str) catch return;
    var iter = view.iterator();
    var options: psf_font.PSFFontOptions = psf_font.DefaultFont.getOptions();

    self.put_rect(
        self.char_cursor.x * options.width,
        self.char_cursor.y * options.height,
        str_width * options.width,
        options.height,
        self.background,
    );

    while (iter.nextCodepoint()) |cp| {
        if (cp != '\n') {
            self.put_char(cp);
        }

        self.char_cursor.x += 1;
        if (self.char_cursor.x * options.width >= self.width or cp == '\n') {
            self.char_cursor.x = 0;
            self.char_cursor.y += 1;
        }

        if (self.char_cursor.y * options.height >= self.height) {
            self.char_cursor = .{
                .x = 0,
                .y = 0,
            };
            self.clear(null);
        }
    }
}

pub fn put_color(self: FBRenderer, x: usize, y: usize, color: Color) void {
    const native_color = color.toNative();
    const color_bytes: [@sizeOf(Color)]u8 = @bitCast(native_color);
    const index = self.indexFromCoordinate(x, y);
    const out_ptr = self.framebuffer[index .. index + self.pixel_stride];

    for (color_bytes, 0..) |byte, i| {
        out_ptr[i] = byte;
    }
}

pub fn put_rect(self: FBRenderer, x: usize, y: usize, width: usize, height: usize, color: Color) void {
    for (x..x + width) |px| {
        for (y..height) |py| {
            self.put_color(px, py, color);
        }
    }
}

pub fn clear(self: FBRenderer, color: ?Color) void {
    for (0..self.height) |y| {
        for (0..self.width) |x| {
            self.put_color(x, y, color orelse self.background);
        }
    }
}
