module quartz.modem.pulse;

import quartz.dsp.design : rrcTaps;
import quartz.dsp.fir : convolveComplex;
import quartz.math.approx : near;
import quartz.math.complex : Complex, nearC;
import quartz.modem.constellation : Constellation, qpsk;

// Upsample, pulse-shape, matched-filter, and sample on the symbol grid.
// The matched filter is the time reverse of the pulse. Raised-cosine pulses
// are symmetric, so the reverse is the pulse itself and the total delay is
// one less than the tap length.

@safe:

Complex!double[] upsample(const(Complex!double)[] symbols, int sps) {
    auto y = new Complex!double[](symbols.length * sps);
    foreach (ref s; y) {
        s = Complex!double(0, 0);
    }
    foreach (i, sym; symbols) {
        y[i * sps] = sym;
    }
    return y;
}

Complex!double[] shape(const(Complex!double)[] symbols, const(double)[] taps, int sps) {
    return convolveComplex(upsample(symbols, sps), taps);
}

Complex!double[] matched(const(Complex!double)[] samples, const(double)[] taps) {
    double[] rev = new double[](taps.length);
    foreach (i, tap; taps) {
        rev[$ - 1 - i] = tap;
    }
    return convolveComplex(samples, rev);
}

Complex!double[] downsampleAt(const(Complex!double)[] samples, int sps, int offset, int count) {
    auto y = new Complex!double[](count);
    foreach (i; 0 .. count) {
        int idx = offset + i * sps;
        if (idx >= 0 && idx < cast(int) samples.length) {
            y[i] = samples[idx];
        } else {
            y[i] = Complex!double(0, 0);
        }
    }
    return y;
}

struct ShapedBurst {
    Complex!double[] samples;
    Complex!double[] symbols;
    int delay;
    int sps;
}

ShapedBurst modulate(const Constellation cons, const(uint)[] labels, const(double)[] taps, int sps) {
    auto symbols = new Complex!double[](labels.length);
    foreach (i, label; labels) {
        symbols[i] = cons.map(label);
    }
    ShapedBurst burst;
    burst.symbols = symbols;
    burst.samples = shape(symbols, taps, sps);
    burst.delay = cast(int) taps.length - 1;
    burst.sps = sps;
    return burst;
}

uint[] demodulate(const Constellation cons, const(Complex!double)[] samples, const(double)[] taps, int sps, int count) {
    auto filtered = matched(samples, taps);
    int delay = cast(int) taps.length - 1;
    auto symbols = downsampleAt(filtered, sps, delay, count);
    uint[] labels = new uint[](count);
    foreach (i, sym; symbols) {
        double d2;
        labels[i] = cons.demap(sym, d2);
    }
    return labels;
}

unittest {
    auto taps = rrcTaps(4, 8, 0.25);
    uint[] labels = [0, 1, 2, 3, 0, 3, 1, 2, 2, 0, 1, 3];
    auto cons = qpsk();
    auto burst = modulate(cons, labels, taps, 4);
    auto got = demodulate(cons, burst.samples, taps, 4, cast(int) labels.length);
    assert(got == labels);
    // The center sample of an isolated symbol is the symbol itself.
    auto single = shape([cons.map(0)], taps, 4);
    auto back = matched(single, taps);
    assert(nearC(back[taps.length - 1], cons.map(0), 1e-6, 1e-6));
    assert(burst.delay == cast(int) taps.length - 1);
}
