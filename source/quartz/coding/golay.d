module quartz.coding.golay;

import quartz.math.special : floorLog2, popcount;

// The binary Golay code as a cyclic code of length 23. Encoding is polynomial
// division by the degree-11 generator. Decoding fills the syndrome table of
// the perfect code: every one of the 2048 syndromes belongs to exactly one
// error pattern of weight at most 3.

@safe:

enum int golayGenerator = 0xc75;

int gf2Degree(int p) {
    if (p <= 0) {
        return -1;
    }
    return floorLog2(cast(size_t) p);
}

int gf2Mod(int dividend, int divisor) {
    if (divisor <= 0) {
        return 0;
    }
    int degD = gf2Degree(divisor);
    int cur = dividend;
    int guard = 0;
    while (cur > 0 && gf2Degree(cur) >= degD) {
        int shift = gf2Degree(cur) - degD;
        cur ^= divisor << shift;
        guard++;
        if (guard > 64) {
            break;
        }
    }
    return cur;
}

int golayEncode(int message) {
    int shifted = (message & 0xfff) << 11;
    int parity = gf2Mod(shifted, golayGenerator);
    return shifted ^ parity;
}

int golayWeight(int word) {
    return popcount(cast(ulong) (word & 0x7fffff));
}

struct GolayTable {
    int[2048] pattern;
    bool ready;

    void build() {
        if (ready) {
            return;
        }
        pattern[] = -1;
        // Weight 0.
        pattern[0] = 0;
        foreach (i; 0 .. 23) {
            int e = 1 << i;
            int s = gf2Mod(e, golayGenerator);
            pattern[s] = e;
        }
        foreach (i; 0 .. 23) {
            foreach (j; i + 1 .. 23) {
                int e = (1 << i) ^ (1 << j);
                int s = gf2Mod(e, golayGenerator);
                pattern[s] = e;
            }
        }
        foreach (i; 0 .. 23) {
            foreach (j; i + 1 .. 23) {
                foreach (k; j + 1 .. 23) {
                    int e = (1 << i) ^ (1 << j) ^ (1 << k);
                    int s = gf2Mod(e, golayGenerator);
                    pattern[s] = e;
                }
            }
        }
        ready = true;
    }
}

GolayTable golayTable;

int golayDecode(int received) {
    if (!golayTable.ready) {
        golayTable.build();
    }
    int word = received & 0x7fffff;
    int syndrome = gf2Mod(word, golayGenerator);
    int err = golayTable.pattern[syndrome & 2047];
    if (err < 0) {
        return word;
    }
    return word ^ err;
}

int golayExtend(int word23) {
    int parity = popcount(cast(ulong) (word23 & 0x7fffff)) & 1;
    return (word23 & 0x7fffff) | (parity << 23);
}

unittest {
    int minWeight = 23;
    foreach (msg; 0 .. 4096) {
        int cw = golayEncode(msg);
        assert(gf2Mod(cw, golayGenerator) == 0);
        int w = golayWeight(cw);
        if (msg == 0) {
            assert(w == 0);
        } else if (w < minWeight) {
            minWeight = w;
        }
        assert(golayDecode(cw) == cw);
    }
    assert(minWeight == 7);
    golayTable.build();
    int filled = 0;
    foreach (s; 0 .. 2048) {
        if (golayTable.pattern[s] >= 0) {
            filled++;
        }
    }
    assert(filled == 2048);
    int cw = golayEncode(0x2a5);
    foreach (i; 0 .. 23) {
        foreach (j; i + 1 .. 23) {
            foreach (k; j + 1 .. 23) {
                int err = (1 << i) ^ (1 << j) ^ (1 << k);
                assert(golayDecode(cw ^ err) == cw);
            }
        }
    }
    int ext = golayExtend(cw);
    assert((popcount(cast(ulong) ext) % 4) == 0);
}
