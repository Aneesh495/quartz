module quartz.coding.hamming;

import quartz.coding.bits : hammingDistance;
import quartz.error : QuartzError;
import quartz.math.special : isPow2;

// Binary Hamming codes in the usual position numbering. Parity bits sit at
// powers of two, counting from 1. The syndrome is the index of the bit to
// flip. Extended Hamming adds an overall parity bit and detects double errors.

@safe:

struct HammingCode {
    int m;
    int n;
    int k;
    bool extended;

    static HammingCode binary(int m) {
        if (m < 2 || m > 8) {
            throw new QuartzError("hamming parity count is out of range");
        }
        HammingCode c;
        c.m = m;
        c.n = (1 << m) - 1;
        c.k = c.n - m;
        c.extended = false;
        return c;
    }

    static HammingCode secded(int m) {
        auto c = binary(m);
        c.extended = true;
        c.n += 1;
        return c;
    }
}

bool[] hammingEncode(HammingCode code, const(bool)[] data) {
    if (cast(int) data.length != code.k) {
        throw new QuartzError("hamming data length does not match k");
    }
    int bare = code.extended ? code.n - 1 : code.n;
    bool[] word = new bool[](code.n);
    int di = 0;
    foreach (pos; 1 .. bare + 1) {
        if (isPow2(cast(size_t) pos)) {
            continue;
        }
        word[pos - 1] = data[di];
        di++;
    }
    foreach (p; 0 .. code.m) {
        int parityPos = 1 << p;
        bool parity = false;
        foreach (pos; 1 .. bare + 1) {
            if ((pos & parityPos) != 0) {
                parity ^= word[pos - 1];
            }
        }
        word[parityPos - 1] = parity;
    }
    if (code.extended) {
        bool overall = false;
        foreach (i; 0 .. bare) {
            overall ^= word[i];
        }
        word[bare] = overall;
    }
    return word;
}

struct HammingResult {
    bool[] data;
    bool corrected;
    bool doubleError;
}

HammingResult hammingDecode(HammingCode code, const(bool)[] word) {
    if (cast(int) word.length != code.n) {
        throw new QuartzError("hamming word length does not match n");
    }
    HammingResult result;
    int bare = code.extended ? code.n - 1 : code.n;
    bool[] bits = word.dup;
    if (code.extended) {
        bool overall = false;
        foreach (bit; bits) {
            overall ^= bit;
        }
        int syndrome = 0;
        foreach (p; 0 .. code.m) {
            int parityPos = 1 << p;
            bool parity = false;
            foreach (pos; 1 .. bare + 1) {
                if ((pos & parityPos) != 0) {
                    parity ^= bits[pos - 1];
                }
            }
            if (parity) {
                syndrome |= parityPos;
            }
        }
        if (syndrome == 0 && !overall) {
            result.doubleError = false;
        } else if (syndrome == 0 && overall) {
            bits[bare] = !bits[bare];
            result.corrected = true;
        } else if (syndrome != 0 && overall) {
            if (syndrome >= 1 && syndrome <= bare) {
                bits[syndrome - 1] = !bits[syndrome - 1];
                result.corrected = true;
            }
        } else {
            result.doubleError = true;
        }
    } else {
        int syndrome = 0;
        foreach (p; 0 .. code.m) {
            int parityPos = 1 << p;
            bool parity = false;
            foreach (pos; 1 .. bare + 1) {
                if ((pos & parityPos) != 0) {
                    parity ^= bits[pos - 1];
                }
            }
            if (parity) {
                syndrome |= parityPos;
            }
        }
        if (syndrome != 0 && syndrome <= bare) {
            bits[syndrome - 1] = !bits[syndrome - 1];
            result.corrected = true;
        }
    }
    bool[] data = new bool[](code.k);
    int di = 0;
    foreach (pos; 1 .. bare + 1) {
        if (isPow2(cast(size_t) pos)) {
            continue;
        }
        data[di] = bits[pos - 1];
        di++;
    }
    result.data = data;
    return result;
}

unittest {
    auto h74 = HammingCode.binary(3);
    assert(h74.n == 7 && h74.k == 4);
    foreach (msg; 0 .. 16) {
        bool[] data;
        foreach (b; 0 .. 4) {
            data ~= ((msg >> b) & 1) != 0;
        }
        auto word = hammingEncode(h74, data);
        auto clean = hammingDecode(h74, word);
        assert(clean.data == data);
        assert(!clean.corrected);
        foreach (flip; 0 .. 7) {
            bool[] bad = word.dup;
            bad[flip] = !bad[flip];
            auto fixed = hammingDecode(h74, bad);
            assert(fixed.data == data);
            assert(fixed.corrected);
            assert(hammingDistance(bad, word) == 1);
        }
    }
    auto h1511 = HammingCode.binary(4);
    bool[] data11;
    foreach (i; 0 .. 11) {
        data11 ~= (i % 3) == 0;
    }
    auto word15 = hammingEncode(h1511, data11);
    foreach (flip; 0 .. 15) {
        bool[] bad = word15.dup;
        bad[flip] = !bad[flip];
        assert(hammingDecode(h1511, bad).data == data11);
    }
    auto ext = HammingCode.secded(3);
    bool[] nibble = [true, false, true, true];
    auto extWord = hammingEncode(ext, nibble);
    bool[] two = extWord.dup;
    two[0] = !two[0];
    two[1] = !two[1];
    auto detected = hammingDecode(ext, two);
    assert(detected.doubleError);
    bool[] one = extWord.dup;
    one[3] = !one[3];
    assert(hammingDecode(ext, one).data == nibble);
}
