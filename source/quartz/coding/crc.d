module quartz.coding.crc;

import quartz.util.hex : parseHex;

// Bit-serial CRC with an optional reflected form, plus a byte table that is
// required to match it. The check value is the digest of the ASCII string
// "123456789", which is the conventional vector.

@safe:

struct CrcModel {
    string name;
    int width;
    ulong poly;
    ulong init;
    ulong xorOut;
    bool refIn;
    bool refOut;
    ulong check;
}

enum CrcModel crc32 = CrcModel("CRC-32", 32, 0x04C11DB7, 0xFFFFFFFF, 0xFFFFFFFF, true, true, 0xCBF43926);
enum CrcModel crc32c = CrcModel("CRC-32C", 32, 0x1EDC6F41, 0xFFFFFFFF, 0xFFFFFFFF, true, true, 0xE3069283);
enum CrcModel crc16Ccitt = CrcModel("CRC-16/CCITT-FALSE", 16, 0x1021, 0xFFFF, 0x0000, false, false, 0x29B1);
enum CrcModel crc8 = CrcModel("CRC-8", 8, 0x07, 0x00, 0x00, false, false, 0xF4);

ulong reflectBits(ulong value, int width) {
    ulong y = 0;
    foreach (i; 0 .. width) {
        if ((value >> i) & 1UL) {
            y |= 1UL << (width - 1 - i);
        }
    }
    return y;
}

ulong crcBitwise(CrcModel model, const(ubyte)[] data) {
    int w = model.width;
    ulong top = 1UL << (w - 1);
    ulong mask = w == 64 ? ulong.max : ((1UL << w) - 1);
    ulong poly = model.poly & mask;
    ulong reg = model.init & mask;
    foreach (b; data) {
        ulong bits = b;
        if (model.refIn) {
            bits = reflectBits(bits, 8);
        }
        reg ^= bits << (w - 8);
        reg &= mask;
        foreach (_; 0 .. 8) {
            if ((reg & top) != 0) {
                reg = ((reg << 1) ^ poly) & mask;
            } else {
                reg = (reg << 1) & mask;
            }
        }
    }
    if (model.refOut) {
        reg = reflectBits(reg, w);
    }
    return (reg ^ model.xorOut) & mask;
}

ulong[256] crcTable(CrcModel model) {
    ulong[256] table;
    foreach (i; 0 .. 256) {
        ubyte[1] one = [cast(ubyte) i];
        // The table stores the register update, not the final xorOut.
        CrcModel bare = model;
        bare.init = 0;
        bare.xorOut = 0;
        table[i] = crcBitwise(bare, one);
    }
    return table;
}

ulong crcTabled(CrcModel model, const(ubyte)[] data) {
    auto table = crcTable(model);
    int w = model.width;
    ulong mask = w == 64 ? ulong.max : ((1UL << w) - 1);
    if (model.refIn) {
        ulong reg = model.init & mask;
        foreach (b; data) {
            ulong idx = (reg ^ b) & 0xff;
            reg = (reg >> 8) ^ table[cast(size_t) idx];
            reg &= mask;
        }
        if (!model.refOut) {
            reg = reflectBits(reg, w);
        }
        return (reg ^ model.xorOut) & mask;
    }
    ulong reg = model.init & mask;
    foreach (b; data) {
        ulong idx = ((reg >> (w - 8)) ^ b) & 0xff;
        reg = ((reg << 8) ^ table[cast(size_t) idx]) & mask;
    }
    if (model.refOut) {
        reg = reflectBits(reg, w);
    }
    return (reg ^ model.xorOut) & mask;
}

ulong crc32Of(const(ubyte)[] data) {
    return crcBitwise(crc32, data);
}

unittest {
    ubyte[] digits = cast(ubyte[]) "123456789".dup;
    assert(crcBitwise(crc32, digits) == crc32.check);
    assert(crcTabled(crc32, digits) == crc32.check);
    assert(crcBitwise(crc32c, digits) == crc32c.check);
    assert(crcTabled(crc32c, digits) == crc32c.check);
    assert(crcBitwise(crc16Ccitt, digits) == crc16Ccitt.check);
    assert(crcTabled(crc16Ccitt, digits) == crc16Ccitt.check);
    assert(crcBitwise(crc8, digits) == crc8.check);
    assert(crcTabled(crc8, digits) == crc8.check);
    assert(crc32Of(parseHex("")) == crcBitwise(crc32, []));
    // A one-byte difference changes the CRC-32 of a short payload.
    assert(crc32Of(cast(ubyte[]) "quartz".dup) != crc32Of(cast(ubyte[]) "quartz!".dup));
}
