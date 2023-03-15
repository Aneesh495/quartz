module quartz.modem.msk;

import quartz.math.approx : near;
import quartz.math.complex : Complex;
import std.math : PI, cos, sin;

// Minimum-shift keying. Each bit advances the carrier phase by plus or minus
// a quarter turn. The demodulator reads the phase step at the symbol
// boundary. Gaussian MSK filters the frequency steps with a short binomial
// kernel before the phase accumulator.

@safe:

Complex!double[] mskModulate(const(bool)[] bits, int sps) {
    auto y = new Complex!double[](bits.length * sps);
    double phase = 0;
    foreach (i, bit; bits) {
        double step = (bit ? -1.0 : 1.0) * (PI / 2.0) / sps;
        foreach (n; 0 .. sps) {
            phase += step;
            y[i * sps + n] = Complex!double(cos(phase), sin(phase));
        }
    }
    return y;
}

bool[] mskDemodulate(const(Complex!double)[] samples, int sps, int count) {
    bool[] bits = new bool[](count);
    Complex!double prev = Complex!double(1, 0);
    foreach (i; 0 .. count) {
        size_t at = (i + 1) * sps - 1;
        if (at >= samples.length) {
            break;
        }
        Complex!double d = samples[at] * prev.conj();
        bits[i] = d.im < 0;
        prev = samples[at];
    }
    return bits;
}

double[] gaussianKernel(int taps, double bt, int sps) {
    // A short binomial kernel stands in for the Gaussian when the product
    // BT is moderate. The taps are normalized to unit sum so the frequency
    // deviation is unchanged.
    if (taps < 3) {
        taps = 3;
    }
    if ((taps % 2) == 0) {
        taps++;
    }
    double[] h = new double[](taps);
    h[0] = 1;
    foreach (n; 1 .. taps) {
        h[n] = h[n - 1] * cast(double) (taps - n) / cast(double) n;
    }
    double sum = 0;
    foreach (v; h) {
        sum += v;
    }
    double width = bt * sps;
    if (width < 0.2) {
        width = 0.2;
    }
    foreach (ref v; h) {
        v /= sum;
    }
    return h;
}

Complex!double[] gmskModulate(const(bool)[] bits, int sps, double bt) {
    auto kernel = gaussianKernel(sps + 1, bt, sps);
    double[] nrz = new double[](bits.length * sps + kernel.length);
    nrz[] = 0;
    foreach (i, bit; bits) {
        double v = bit ? -1.0 : 1.0;
        foreach (n; 0 .. sps) {
            nrz[i * sps + n] = v;
        }
    }
    double[] freq = new double[](bits.length * sps);
    foreach (i; 0 .. freq.length) {
        double acc = 0;
        foreach (k, tap; kernel) {
            if (i + k < nrz.length) {
                acc += tap * nrz[i + k];
            }
        }
        freq[i] = acc;
    }
    auto y = new Complex!double[](freq.length);
    double phase = 0;
    foreach (i, f; freq) {
        phase += f * (PI / 2.0) / sps;
        y[i] = Complex!double(cos(phase), sin(phase));
    }
    return y;
}

unittest {
    bool[] bits = [false, true, true, false, true, false, true, true, false, false];
    auto wave = mskModulate(bits, 8);
    assert(mskDemodulate(wave, 8, cast(int) bits.length) == bits);
    foreach (s; wave) {
        assert(near(s.mag(), 1.0, 1e-9, 1e-9));
    }
    auto g = gmskModulate(bits, 8, 0.5);
    assert(g.length == bits.length * 8);
    foreach (s; g) {
        assert(near(s.mag(), 1.0, 1e-6, 1e-6));
    }
    auto kernel = gaussianKernel(5, 0.5, 8);
    double sum = 0;
    foreach (v; kernel) {
        sum += v;
    }
    assert(near(sum, 1.0, 1e-12, 1e-12));
}
