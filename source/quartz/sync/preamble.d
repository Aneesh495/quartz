module quartz.sync.preamble;

import quartz.math.complex : Complex;

// Sliding correlation against a known preamble. The peak index is the first
// sample of the match. A delayed copy of the preamble, with a few leading
// zeros, has to peak at that delay even when a little noise is added.

@safe:

struct PreambleHit {
    int index;
    double power;
}

PreambleHit findPreamble(const(Complex!double)[] samples, const(Complex!double)[] pattern) {
    PreambleHit best;
    best.index = -1;
    best.power = -1;
    if (pattern.length == 0 || samples.length < pattern.length) {
        return best;
    }
    foreach (i; 0 .. samples.length - pattern.length + 1) {
        Complex!double acc = Complex!double(0, 0);
        foreach (k, p; pattern) {
            acc = acc + samples[i + k] * p.conj();
        }
        double power = acc.mag2();
        if (power > best.power) {
            best.power = power;
            best.index = cast(int) i;
        }
    }
    return best;
}

unittest {
    Complex!double[] pattern = [
        Complex!double(1, 0), Complex!double(1, 0),
        Complex!double(-1, 0), Complex!double(1, 0),
        Complex!double(-1, 0), Complex!double(-1, 0)
    ];
    auto samples = new Complex!double[](20);
    foreach (ref s; samples) {
        s = Complex!double(0, 0);
    }
    foreach (k, p; pattern) {
        samples[7 + k] = p;
    }
    auto hit = findPreamble(samples, pattern);
    assert(hit.index == 7);
    samples[7] = samples[7] + Complex!double(0.1, -0.05);
    auto noisy = findPreamble(samples, pattern);
    assert(noisy.index == 7);
}
