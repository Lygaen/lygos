const std = @import("std");

const PSF1_MAGIC: [2]u8 = .{ 0x36, 0x04 };
const PSF2_MAGIC: [4]u8 = .{ 0x72, 0xb5, 0x4a, 0x86 };

pub const PSFFontOptions = struct {
    content: []const u8,
    header_size: usize,
    width: usize,
    height: usize,
    bytes_per_glyph: usize,
    number_of_glyph: usize,
};

pub const DefaultFont = BuildFont("./lat9-16.psf");

pub const PixelIteratorReturn = struct {
    is_on: bool,
    is_new_line: bool,
};

pub fn GlyphPixelIterator(comptime options: PSFFontOptions) type {
    return struct {
        x: u32 = 0,
        y: u32 = 0,
        mask: u32 = 1 << (options.width),
        offset: usize,

        pub fn next(self: *@This()) ?PixelIteratorReturn {
            if (self.x < (options.width)) {
                const value = options.content[self.offset] & self.mask == self.mask;
                self.mask >>= 1;
                self.x += 1;
                return .{
                    .is_on = value,
                    .is_new_line = false,
                };
            }

            if (self.y < options.height) {
                self.mask = 1 << (options.width);
                self.x = 0;
                self.y += 1;
                self.offset += 1;
                return .{
                    .is_on = self.next().?.is_on,
                    .is_new_line = true,
                };
            }

            return null;
        }

        pub fn init(char: u21) @This() {
            const offset = blk: {
                if (char > 0 and char < options.number_of_glyph) {
                    break :blk options.header_size + char * options.bytes_per_glyph;
                }
                break :blk options.header_size;
            };

            return .{
                .offset = offset,
            };
        }
    };
}

pub fn PSFFont(comptime options: PSFFontOptions) type {
    return struct {
        pub fn getIter(char: u21) GlyphPixelIterator(options) {
            return .init(if (char > options.number_of_glyph) 0 else char);
        }

        pub fn getOptions() PSFFontOptions {
            return options;
        }
    };
}

pub fn BuildFont(comptime path: []const u8) type {
    const file = @embedFile(path);
    var reader = std.Io.Reader.fixed(file);

    if (std.mem.startsWith(u8, file, &PSF1_MAGIC)) {
        _ = reader.takeInt(u16, .little) catch @compileError("Error while read");
        const version = reader.takeInt(u8, .little) catch @compileError("Error while read");
        const height = reader.takeInt(u8, .little) catch @compileError("Error while read");
        const count = if (version & 0x01 == 1) 512 else 256;

        return PSFFont(.{
            .content = file,
            .header_size = 4,
            .number_of_glyph = count,
            .height = height,
            .bytes_per_glyph = height,
            .width = 8,
        });
    }

    if (std.mem.startsWith(u8, file, &PSF2_MAGIC)) {
        _ = reader.takeInt(u32, .little) catch @compileError("Error while read");
        _ = reader.takeInt(u32, .little) catch @compileError("Error while read");
        const header_size = reader.takeInt(u32, .little) catch @compileError("Error while read");

        _ = reader.takeInt(u32, .little) catch @compileError("Error while read");
        const glyph_count = reader.takeInt(u32, .little) catch @compileError("Error while read");
        const glyph_size = reader.takeInt(u32, .little) catch @compileError("Error while read");
        const glyph_height = reader.takeInt(u32, .little) catch @compileError("Error while read");
        const glyph_width = reader.takeInt(u32, .little) catch @compileError("Error while read");
        return PSFFont(.{
            .content = file,
            .header_size = header_size,
            .number_of_glyph = glyph_count,
            .height = glyph_height,
            .bytes_per_glyph = glyph_size,
            .width = glyph_width,
        });
    }

    @compileError("File at " ++ path ++ " isn't a valid PSF1/2 file");
}
