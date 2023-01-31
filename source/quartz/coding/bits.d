module quartz.coding.bits;

import quartz.error : QuartzError;

// Bits are booleans in time order. Inside a byte, bit 7 is the earliest bit.
// Frame headers, CRC inputs, and soft demappers all use this convention so a
// payload hex string survives a modem loopback without a surprise reversal.

@safe:

struct BitWriter {
    bool[] bits;

    void put(bool bit) {
        bits ~= bit;
    }

    void putWord(ulong value, int width) {
        if (width < 0 || width > 64) {
            throw new QuartzError("bit width is out of range");
        }
        if (width == 64) {
            foreach_reverse (i; 0 .. 64) {
                bits ~= ((value >> i) & 1UL) != 0;
            }
            return;
        }
        ulong maskLimit = (1UL << width) - 1;
        value &= maskLimit;
        foreach_reverse (i; 0 .. width) {
            bits ~= ((value >> i) & 1UL) != 0;
        }
    }

    void putBytes(const(ubyte)[] data) {
        foreach (b; data) {
            putWord(b, 8);
        }
    }
}

struct BitReader {
    const(bool)[] bits;
    size_t index;

    this(const(bool)[] bits) {
        this.bits = bits;
        this.index = 0;
    }

    bool empty() const {
        return index >= bits.length;
    }

    size_t remaining() const {
        if (index >= bits.length) {
            return 0;
        }
        return bits.length - index;
    }

    bool next() {
        if (index >= bits.length) {
            throw new QuartzError("bit reader underrun");
        }
        bool bit = bits[index];
        index++;
        return bit;
    }

    ulong nextWord(int width) {
        if (width < 0 || width > 64) {
            throw new QuartzError("bit width is out of range");
        }
        ulong value = 0;
        foreach (_; 0 .. width) {
            value = (value << 1) | (next() ? 1UL : 0UL);
        }
        return value;
    }
}

bool[] bytesToBits(const(ubyte)[] data) {
    BitWriter w;
    w.putBytes(data);
    return w.bits;
}

ubyte[] bitsToBytes(const(bool)[] bits) {
    BitReader r = BitReader(bits);
    ubyte[] data;
    while (r.remaining() >= 8) {
        data ~= cast(ubyte) r.nextWord(8);
    }
    if (r.remaining() > 0) {
        int leftover = cast(int) r.remaining();
        ulong value = r.nextWord(leftover);
        data ~= cast(ubyte) (value << (8 - leftover));
    }
    return data;
}

int hammingDistance(const(bool)[] a, const(bool)[] b) {
    if (a.length != b.length) {
        throw new QuartzError("hamming distance needs equal lengths");
    }
    int n = 0;
    foreach (i, bit; a) {
        if (bit != b[i]) {
            n++;
        }
    }
    return n;
}

int popcountBits(const(bool)[] bits) {
    int n = 0;
    foreach (bit; bits) {
        if (bit) {
            n++;
        }
    }
    return n;
}

bool[] padTo(const(bool)[] bits, size_t n) {
    bool[] outBits = bits.dup;
    while (outBits.length < n) {
        outBits ~= false;
    }
    return outBits;
}

bool[] takePrefix(const(bool)[] bits, size_t n) {
    if (n > bits.length) {
        throw new QuartzError("prefix is longer than the bit string");
    }
    return bits[0 .. n].dup;
}

unittest {
    BitWriter w;
    w.putWord(0xA5, 8);
    assert(w.bits == [true, false, true, false, false, true, false, true]);
    BitReader r = BitReader(w.bits);
    assert(r.nextWord(8) == 0xA5);
    auto round = bytesToBits([0x01, 0x80]);
    assert(bitsToBytes(round) == [0x01, 0x80]);
    assert(hammingDistance([true, false, true], [true, true, true]) == 1);
    bool[] three = [true, false, true];
    assert(bitsToBytes(three)[0] == 0b1010_0000);
    assert(padTo([true], 3) == [true, false, false]);
    bool threw = false;
    try {
        auto d = hammingDistance([true], [true, false]);
        assert(d == 0);
    } catch (QuartzError) {
        threw = true;
    }
    assert(threw);
}
