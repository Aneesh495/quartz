module quartz.dsp.fir;

import quartz.math.approx : near;
import quartz.math.complex : Complex, nearC;
import quartz.math.qformat : Q15;

// Direct-form FIR. The delay line is explicit so a later fixed-point twin
// can share the tap layout. Convolution is the reference the overlap-add
// path has to match.

@safe:

struct Fir {
    double[] taps;
    double[] delay;
    int at;

    this(const(double)[] taps) {
        this.taps = taps.dup;
        this.delay = new double[](taps.length);
        this.delay[] = 0;
        this.at = 0;
    }

    void reset() {
        delay[] = 0;
        at = 0;
    }

    double next(double x) {
        if (taps.length == 0) {
            return 0;
        }
        delay[at] = x;
        double acc = 0;
        size_t idx = at;
        foreach (tap; taps) {
            acc += tap * delay[idx];
            if (idx == 0) {
                idx = delay.length - 1;
            } else {
                idx--;
            }
        }
        at++;
        if (at == delay.length) {
            at = 0;
        }
        return acc;
    }
}

double[] firBlock(const(double)[] taps, const(double)[] input) {
    auto filter = Fir(taps);
    double[] y = new double[](input.length);
    foreach (i, x; input) {
        y[i] = filter.next(x);
    }
    return y;
}

double[] convolve(const(double)[] a, const(double)[] b) {
    if (a.length == 0 || b.length == 0) {
        return [];
    }
    double[] y = new double[](a.length + b.length - 1);
    y[] = 0;
    foreach (i, av; a) {
        foreach (j, bv; b) {
            y[i + j] += av * bv;
        }
    }
    return y;
}

Complex!double[] convolveComplex(const(Complex!double)[] a, const(double)[] b) {
    if (a.length == 0 || b.length == 0) {
        return [];
    }
    auto y = new Complex!double[](a.length + b.length - 1);
    foreach (ref s; y) {
        s = Complex!double(0, 0);
    }
    foreach (i, av; a) {
        foreach (j, bv; b) {
            y[i + j] = y[i + j] + av * bv;
        }
    }
    return y;
}

Q15[] firQ15(const(Q15)[] taps, const(Q15)[] input) {
    Q15[] delay = new Q15[](taps.length);
    int at = 0;
    Q15[] y = new Q15[](input.length);
    foreach (n, x; input) {
        delay[at] = x;
        long acc = 0;
        size_t idx = at;
        foreach (tap; taps) {
            acc += cast(long) tap.raw * delay[idx].raw;
            if (idx == 0) {
                idx = delay.length - 1;
            } else {
                idx--;
            }
        }
        y[n] = Q15.fromRaw(Q15.saturate(Q15.roundDiv(acc)));
        at++;
        if (at == delay.length) {
            at = 0;
        }
    }
    return y;
}

unittest {
    double[] taps = [0.25, 0.5, 0.25];
    double[] impulse = [1, 0, 0, 0, 0];
    auto y = firBlock(taps, impulse);
    assert(near(y[0], 0.25, 1e-12, 0.0));
    assert(near(y[1], 0.5, 1e-12, 0.0));
    assert(near(y[2], 0.25, 1e-12, 0.0));
    assert(near(y[3], 0.0, 1e-12, 0.0));
    auto full = convolve([1.0, 2, 3], [4.0, 5]);
    assert(full.length == 4);
    assert(near(full[0], 4, 1e-12, 0.0));
    assert(near(full[1], 13, 1e-12, 0.0));
    assert(near(full[2], 22, 1e-12, 0.0));
    assert(near(full[3], 15, 1e-12, 0.0));
    alias C = Complex!double;
    auto cy = convolveComplex([C(1, 1), C(0, -1)], [2.0, 0.5]);
    assert(nearC(cy[0], C(2, 2), 1e-12, 1e-12));
    Q15[] qt = [Q15.fromDouble(0.25), Q15.fromDouble(0.5), Q15.fromDouble(0.25)];
    Q15[] qi = [Q15.fromDouble(1), Q15.fromDouble(0), Q15.fromDouble(0), Q15.fromDouble(0)];
    auto qy = firQ15(qt, qi);
    assert(near(qy[0].toDouble(), 0.25, 1.0 / 32768.0, 0.0));
    assert(near(qy[1].toDouble(), 0.5, 1.0 / 32768.0, 0.0));
}
