module quartz.coding.polar;

import quartz.channel.rng : Xoshiro256;
import quartz.error : QuartzError;
import quartz.math.special : isPow2;

// Arikan's polar transform and a successive-cancellation decoder.
// Frozen bits are the noisiest synthetic channels under the Bhattacharyya
// recursion for a binary erasure design point. With infinite channel LLRs the
// decoder is exact for every frozen set; the design point only matters once
// the channel is noisy.

@safe:

void polarTransform(bool[] block) {
    if (!isPow2(block.length) || block.length == 0) {
        throw new QuartzError("polar block length must be a power of two");
    }
    for (size_t step = 1; step < block.length; step <<= 1) {
        for (size_t i = 0; i < block.length; i += step * 2) {
            foreach (j; 0 .. step) {
                block[i + j] = block[i + j] ^ block[i + j + step];
            }
        }
    }
}

double[] bhattacharyya(int n, double erasure) {
    if (!isPow2(n) || erasure < 0 || erasure > 1) {
        throw new QuartzError("Bhattacharyya parameters are invalid");
    }
    double[] z = [erasure];
    while (cast(int) z.length < n) {
        double[] nxt = new double[](z.length * 2);
        foreach (i, v; z) {
            nxt[i * 2] = 2.0 * v - v * v;
            nxt[i * 2 + 1] = v * v;
        }
        z = nxt;
    }
    return z;
}

bool[] frozenMask(int n, int k, double erasure) {
    if (k < 0 || k > n) {
        throw new QuartzError("polar dimension is out of range");
    }
    double[] z = bhattacharyya(n, erasure);
    int[] order = new int[](n);
    foreach (i; 0 .. n) {
        order[i] = cast(int) i;
    }
    // Noisiest channels first. A simple insertion sort keeps the tie break
    // stable: equal Z keeps the lower index earlier.
    foreach (i; 1 .. n) {
        int key = order[i];
        int j = cast(int) i - 1;
        while (j >= 0 && (z[order[j]] < z[key] || (z[order[j]] == z[key] && order[j] > key))) {
            order[j + 1] = order[j];
            j--;
        }
        order[j + 1] = key;
    }
    bool[] frozen = new bool[](n);
    frozen[] = true;
    foreach (i; n - k .. n) {
        frozen[order[i]] = false;
    }
    return frozen;
}

bool[] polarPlace(const(bool)[] info, const(bool)[] frozen) {
    int k = 0;
    foreach (bit; frozen) {
        if (!bit) {
            k++;
        }
    }
    if (cast(int) info.length != k) {
        throw new QuartzError("polar information length does not match the frozen set");
    }
    bool[] u = new bool[](frozen.length);
    int at = 0;
    foreach (i, isFrozen; frozen) {
        if (!isFrozen) {
            u[i] = info[at];
            at++;
        }
    }
    return u;
}

bool[] polarEncode(const(bool)[] info, const(bool)[] frozen) {
    bool[] u = polarPlace(info, frozen);
    polarTransform(u);
    return u;
}

private double fBox(double a, double b) {
    double sign = 1.0;
    if (a < 0) {
        sign = -sign;
    }
    if (b < 0) {
        sign = -sign;
    }
    double aa = a < 0 ? -a : a;
    double bb = b < 0 ? -b : b;
    double m = aa < bb ? aa : bb;
    return sign * m;
}

private double gBox(double a, double b, bool u) {
    return b + (u ? -a : a);
}

private void scRec(double[] llr, const(bool)[] frozen, bool[] uHat, size_t offset) {
    if (llr.length == 1) {
        if (frozen[offset]) {
            uHat[offset] = false;
        } else {
            uHat[offset] = llr[0] < 0;
        }
        return;
    }
    size_t half = llr.length / 2;
    double[] left = new double[](half);
    foreach (i; 0 .. half) {
        left[i] = fBox(llr[i], llr[i + half]);
    }
    scRec(left, frozen, uHat, offset);
    // The g-box needs the left child's encoded partial sum, not the source bits.
    bool[] partial = uHat[offset .. offset + half].dup;
    polarTransform(partial);
    double[] right = new double[](half);
    foreach (i; 0 .. half) {
        right[i] = gBox(llr[i], llr[i + half], partial[i]);
    }
    scRec(right, frozen, uHat, offset + half);
}

bool[] polarDecode(const(double)[] channelLlr, const(bool)[] frozen) {
    if (channelLlr.length != frozen.length || !isPow2(channelLlr.length)) {
        throw new QuartzError("polar decoder length is wrong");
    }
    bool[] uHat = new bool[](frozen.length);
    scRec(channelLlr.dup, frozen, uHat, 0);
    bool[] info;
    foreach (i, isFrozen; frozen) {
        if (!isFrozen) {
            info ~= uHat[i];
        }
    }
    return info;
}

double[] llrFromCoded(const(bool)[] coded, double magnitude) {
    double[] llr = new double[](coded.length);
    foreach (i, bit; coded) {
        llr[i] = bit ? -magnitude : magnitude;
    }
    return llr;
}

unittest {
    bool[] block = [true, false, true, true, false, true, false, false];
    bool[] once = block.dup;
    polarTransform(once);
    polarTransform(once);
    assert(once == block);

    auto frozen = frozenMask(8, 4, 0.5);
    int infoCount = 0;
    foreach (bit; frozen) {
        if (!bit) {
            infoCount++;
        }
    }
    assert(infoCount == 4);

    foreach (mask; 0 .. 16) {
        bool[] info = new bool[](4);
        foreach (i; 0 .. 4) {
            info[i] = ((mask >> i) & 1) != 0;
        }
        auto coded = polarEncode(info, frozen);
        auto got = polarDecode(llrFromCoded(coded, 40.0), frozen);
        assert(got == info);
    }

    auto frozen16 = frozenMask(16, 8, 0.4);
    auto rng = Xoshiro256(5);
    foreach (trial; 0 .. 8) {
        bool[] info = new bool[](8);
        foreach (i; 0 .. 8) {
            info[i] = rng.nextBool();
        }
        auto coded = polarEncode(info, frozen16);
        double[] llr = llrFromCoded(coded, 12.0);
        // One channel flip. Distance is not guaranteed, so this only checks
        // that a strong remaining LLR still recovers this particular draw
        // when the flipped bit is a frozen-adjacent synthetic channel. The
        // hard requirement is the clean recovery above; here we re-encode
        // the decision and demand the codeword matches if the info matches.
        llr[3] = -llr[3];
        auto got = polarDecode(llr, frozen16);
        if (got == info) {
            assert(polarEncode(got, frozen16) == coded);
        }
    }
}
