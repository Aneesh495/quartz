module quartz.coding.hadamard;

import quartz.error : QuartzError;
import quartz.math.special : isPow2;

// In-place Fast Walsh-Hadamard transform, unnormalized. The Reed-Muller
// decoder reads the spike. A second transform scales by the length, which
// is the identity the tests lock down.

@safe:

void fwht(int[] data) {
    if (!isPow2(data.length)) {
        throw new QuartzError("Hadamard length must be a power of two");
    }
    for (size_t len = 1; len < data.length; len <<= 1) {
        for (size_t i = 0; i < data.length; i += len * 2) {
            foreach (j; 0 .. len) {
                int u = data[i + j];
                int v = data[i + j + len];
                data[i + j] = u + v;
                data[i + j + len] = u - v;
            }
        }
    }
}

void ifwht(int[] data) {
    fwht(data);
    int n = cast(int) data.length;
    foreach (ref v; data) {
        v /= n;
    }
}

unittest {
    int[] impulse = [1, 0, 0, 0, 0, 0, 0, 0];
    fwht(impulse);
    foreach (v; impulse) {
        assert(v == 1);
    }
    int[] round = [3, -1, 4, 2];
    int[] copy = round.dup;
    fwht(copy);
    ifwht(copy);
    assert(copy == round);
    int[] spike = [1, 1, 1, 1, -1, -1, -1, -1];
    fwht(spike);
    int peak = 0;
    int peakAt = 0;
    foreach (i, v; spike) {
        int a = v < 0 ? -v : v;
        if (a > peak) {
            peak = a;
            peakAt = cast(int) i;
        }
    }
    assert(peak == 8);
    assert(peakAt == 4);
}
