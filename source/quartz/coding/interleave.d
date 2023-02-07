module quartz.coding.interleave;

import quartz.error : QuartzError;

// A rectangular block interleaver. Symbols are written in rows and read in
// columns. The inverse is the same rectangle transposed, so a burst that is
// shorter than the column count comes out as isolated errors.

@safe:

bool[] blockInterleave(const(bool)[] bits, int rows, int cols) {
    if (rows <= 0 || cols <= 0) {
        throw new QuartzError("interleaver dimensions must be positive");
    }
    if (bits.length != rows * cols) {
        throw new QuartzError("interleaver input is not a full block");
    }
    bool[] dst = new bool[](bits.length);
    foreach (r; 0 .. rows) {
        foreach (c; 0 .. cols) {
            dst[c * rows + r] = bits[r * cols + c];
        }
    }
    return dst;
}

bool[] blockDeinterleave(const(bool)[] bits, int rows, int cols) {
    if (rows <= 0 || cols <= 0 || bits.length != rows * cols) {
        throw new QuartzError("deinterleaver input is not a full block");
    }
    bool[] dst = new bool[](bits.length);
    foreach (r; 0 .. rows) {
        foreach (c; 0 .. cols) {
            dst[r * cols + c] = bits[c * rows + r];
        }
    }
    return dst;
}

unittest {
    bool[] msg;
    foreach (i; 0 .. 12) {
        msg ~= (i % 2) == 0;
    }
    auto mixed = blockInterleave(msg, 3, 4);
    assert(blockDeinterleave(mixed, 3, 4) == msg);
    // A burst of 3 along the interleaved stream touches 3 different rows
    // of the original, so no original row is wiped out entirely.
    bool[] burst = mixed.dup;
    burst[0] = !burst[0];
    burst[1] = !burst[1];
    burst[2] = !burst[2];
    auto back = blockDeinterleave(burst, 3, 4);
    int rowHits;
    foreach (r; 0 .. 3) {
        int hits = 0;
        foreach (c; 0 .. 4) {
            if (back[r * 4 + c] != msg[r * 4 + c]) {
                hits++;
            }
        }
        if (hits > 0) {
            rowHits++;
        }
        assert(hits <= 1);
    }
    assert(rowHits == 3);
}
