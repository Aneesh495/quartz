module quartz.io.png;

import quartz.coding.crc : crc32Of;
import quartz.error : QuartzError;

// A PNG writer that stores scanlines uncompressed. The zlib wrapper is a
// sequence of stored deflate blocks, so a test can read the pixels back
// without an inflater. CRC-32 on the chunks is the same CRC the frames use.

struct PngImage {
    int width;
    int height;
    ubyte[] rgb;
}

ubyte[] encodePng(const(ubyte)[] rgb, int width, int height) {
    if (width <= 0 || height <= 0 || rgb.length != width * height * 3) {
        throw new QuartzError("png buffer does not match the image size");
    }
    ubyte[] raw;
    foreach (y; 0 .. height) {
        raw ~= 0;
        raw ~= rgb[y * width * 3 .. (y + 1) * width * 3];
    }
    ubyte[] z = zlibStore(raw);
    ubyte[] ihdr;
    ihdr ~= be32(width);
    ihdr ~= be32(height);
    ihdr ~= [8, 2, 0, 0, 0];
    ubyte[] png;
    png ~= [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    png ~= chunk("IHDR", ihdr);
    png ~= chunk("IDAT", z);
    png ~= chunk("IEND", []);
    return png;
}

ubyte[] scatterPng(const(double)[] xs, const(double)[] ys, int size) {
    if (size < 16) {
        size = 16;
    }
    ubyte[] rgb = new ubyte[](size * size * 3);
    foreach (i; 0 .. rgb.length) {
        rgb[i] = 12;
    }
    int n = cast(int) xs.length < cast(int) ys.length ? cast(int) xs.length : cast(int) ys.length;
    foreach (i; 0 .. n) {
        int px = cast(int) ((xs[i] + 1.5) / 3.0 * (size - 1));
        int py = cast(int) ((1.5 - ys[i]) / 3.0 * (size - 1));
        if (px < 1) {
            px = 1;
        }
        if (py < 1) {
            py = 1;
        }
        if (px > size - 2) {
            px = size - 2;
        }
        if (py > size - 2) {
            py = size - 2;
        }
        foreach (dy; -1 .. 2) {
            foreach (dx; -1 .. 2) {
                int at = ((py + dy) * size + (px + dx)) * 3;
                rgb[at] = 240;
                rgb[at + 1] = 180;
                rgb[at + 2] = 60;
            }
        }
    }
    return encodePng(rgb, size, size);
}

private ubyte[] be32(int value) {
    uint v = cast(uint) value;
    return [cast(ubyte) (v >> 24), cast(ubyte) (v >> 16), cast(ubyte) (v >> 8), cast(ubyte) v];
}

private ubyte[] chunk(string kind, const(ubyte)[] data) {
    ubyte[] body = cast(ubyte[]) kind.dup ~ data;
    uint crc = cast(uint) crc32Of(body);
    ubyte[] outBytes = be32(cast(int) data.length) ~ body ~ be32(cast(int) crc);
    return outBytes;
}

private ubyte[] zlibStore(const(ubyte)[] data) {
    ubyte[] z = [0x78, 0x01];
    size_t off = 0;
    while (off < data.length || data.length == 0) {
        size_t n = data.length - off;
        if (n > 65535) {
            n = 65535;
        }
        bool last = off + n >= data.length;
        z ~= last ? 0x01 : 0x00;
        z ~= cast(ubyte) (n & 0xff);
        z ~= cast(ubyte) ((n >> 8) & 0xff);
        uint nlen = cast(uint) (~cast(ushort) n);
        z ~= cast(ubyte) (nlen & 0xff);
        z ~= cast(ubyte) ((nlen >> 8) & 0xff);
        if (n > 0) {
            z ~= data[off .. off + n];
        }
        off += n;
        if (data.length == 0 || off >= data.length) {
            break;
        }
    }
    uint ad = adler32(data);
    z ~= be32(cast(int) ad);
    return z;
}

private uint adler32(const(ubyte)[] data) {
    uint a = 1;
    uint b = 0;
    foreach (byte_; data) {
        a = (a + byte_) % 65521;
        b = (b + a) % 65521;
    }
    return (b << 16) | a;
}

PngImage decodeStoredPng(const(ubyte)[] png) {
    if (png.length < 8 || png[0] != 0x89 || png[1] != 'P') {
        throw new QuartzError("png signature mismatch");
    }
    size_t i = 8;
    int width = 0;
    int height = 0;
    ubyte[] idat;
    while (i + 8 <= png.length) {
        uint len = (cast(uint) png[i] << 24) | (cast(uint) png[i + 1] << 16) | (cast(uint) png[i + 2] << 8) | png[i + 3];
        string kind = cast(string) png[i + 4 .. i + 8].dup;
        if (i + 12 + len > png.length) {
            throw new QuartzError("png chunk overruns the file");
        }
        ubyte[] data = png[i + 8 .. i + 8 + len].dup;
        ubyte[] body = cast(ubyte[]) kind.dup ~ data;
        uint crc = cast(uint) crc32Of(body);
        uint got = (cast(uint) png[i + 8 + len] << 24) | (cast(uint) png[i + 9 + len] << 16)
            | (cast(uint) png[i + 10 + len] << 8) | png[i + 11 + len];
        if (crc != got) {
            throw new QuartzError("png chunk crc mismatch");
        }
        if (kind == "IHDR") {
            width = cast(int) ((cast(uint) data[0] << 24) | (cast(uint) data[1] << 16) | (cast(uint) data[2] << 8) | data[3]);
            height = cast(int) ((cast(uint) data[4] << 24) | (cast(uint) data[5] << 16) | (cast(uint) data[6] << 8) | data[7]);
        } else if (kind == "IDAT") {
            idat ~= data;
        } else if (kind == "IEND") {
            break;
        }
        i += 12 + len;
    }
    if (idat.length < 2) {
        throw new QuartzError("png has no image data");
    }
    ubyte[] raw = inflateStored(idat);
    ubyte[] rgb;
    size_t at = 0;
    foreach (_; 0 .. height) {
        if (at >= raw.length || raw[at] != 0) {
            throw new QuartzError("png scanline filter is not stored-none");
        }
        at++;
        rgb ~= raw[at .. at + width * 3];
        at += width * 3;
    }
    PngImage image;
    image.width = width;
    image.height = height;
    image.rgb = rgb;
    return image;
}

private ubyte[] inflateStored(const(ubyte)[] z) {
    if (z.length < 6) {
        throw new QuartzError("zlib stream is short");
    }
    size_t i = 2;
    ubyte[] raw;
    while (i + 5 <= z.length - 4) {
        ubyte header = z[i];
        i++;
        int n = z[i] | (z[i + 1] << 8);
        i += 4;
        raw ~= z[i .. i + n];
        i += n;
        if ((header & 1) != 0) {
            break;
        }
    }
    return raw;
}

unittest {
    ubyte[] red = [255, 0, 0];
    auto png = encodePng(red, 1, 1);
    auto image = decodeStoredPng(png);
    assert(image.width == 1 && image.height == 1);
    assert(image.rgb == red);
    ubyte[] quad = new ubyte[](2 * 2 * 3);
    quad[0] = 1;
    quad[3] = 2;
    quad[6] = 3;
    quad[9] = 4;
    auto back = decodeStoredPng(encodePng(quad, 2, 2));
    assert(back.rgb == quad);
    auto plot = scatterPng([0.2, -0.4], [0.1, 0.3], 32);
    auto drawn = decodeStoredPng(plot);
    assert(drawn.width == 32 && drawn.height == 32);
    int bright = 0;
    foreach (i; 0 .. drawn.rgb.length / 3) {
        if (drawn.rgb[i * 3] > 200) {
            bright++;
        }
    }
    assert(bright > 0);
}
