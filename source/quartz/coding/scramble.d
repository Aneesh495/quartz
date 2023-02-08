module quartz.coding.scramble;

import quartz.error : QuartzError;

// Additive LFSR scrambler. The same sequence is added again at the receiver,
// so the operation is an involution. The polynomial is a bit mask whose
// least significant bit is the newest tap.

@safe:

struct Lfsr {
    uint state;
    uint poly;
    int width;

    this(uint poly, uint seed, int width) {
        if (width < 2 || width > 31) {
            throw new QuartzError("scrambler width is out of range");
        }
        if (seed == 0) {
            throw new QuartzError("scrambler seed must be nonzero");
        }
        this.poly = poly;
        this.seedWidth(seed, width);
    }

    void seedWidth(uint seed, int width) {
        this.width = width;
        this.state = seed & ((1u << width) - 1);
        if (this.state == 0) {
            this.state = 1;
        }
    }

    bool next() {
        bool outBit = (state & 1u) != 0;
        uint fb = 0;
        uint s = state;
        uint p = poly;
        while (p != 0) {
            if ((p & 1u) != 0) {
                fb ^= s & 1u;
            }
            p >>= 1;
            s >>= 1;
        }
        state = (state >> 1) | (fb << (width - 1));
        return outBit;
    }
}

bool[] scramble(const(bool)[] bits, uint poly, uint seed, int width) {
    auto gen = Lfsr(poly, seed, width);
    bool[] dst = new bool[](bits.length);
    foreach (i, bit; bits) {
        dst[i] = bit ^ gen.next();
    }
    return dst;
}

unittest {
    bool[] msg = [true, false, true, true, false, false, true, false, true];
    // x^7 + x^3 + 1, a common scrambler polynomial, width 7.
    uint poly = 0b1001001;
    auto mixed = scramble(msg, poly, 0x5a, 7);
    assert(mixed != msg);
    assert(scramble(mixed, poly, 0x5a, 7) == msg);
    auto again = scramble(msg, poly, 0x5a, 7);
    assert(again == mixed);
}
