module quartz.dsp.design;

import quartz.dsp.fir : convolve;
import quartz.dsp.window : WindowKind, windowByKind;
import quartz.math.approx : near;
import quartz.math.special : sincPi;
import std.math : PI, cos, sin, sqrt;

// Closed-form pulses. The square-root raised cosine is normalized to unit
// energy so a matched filter (the same taps, the pulse is symmetric) has a
// center autocorrelation of 1. The windowed sinc is the lowpass used when a
// specification is a cutoff rather than a rolloff.

@safe:

double rrcAt(double t, double beta) {
    if (beta < 0 || beta > 1) {
        beta = 0;
    }
    double at = t < 0 ? -t : t;
    if (at < 1e-8) {
        return 1.0 - beta + 4.0 * beta / PI;
    }
    if (beta > 0 && (at - 1.0 / (4.0 * beta)) < 1e-8 && (1.0 / (4.0 * beta) - at) < 1e-8) {
        double a = beta / sqrt(2.0);
        return a * ((1.0 + 2.0 / PI) * sin(PI / (4.0 * beta)) + (1.0 - 2.0 / PI) * cos(PI / (4.0 * beta)));
    }
    double num = sin(PI * t * (1.0 - beta)) + 4.0 * beta * t * cos(PI * t * (1.0 + beta));
    double den = PI * t * (1.0 - (4.0 * beta * t) * (4.0 * beta * t));
    return num / den;
}

double[] rrcTaps(int sps, int spanSymbols, double beta) {
    if (sps < 1) {
        sps = 1;
    }
    if (spanSymbols < 2) {
        spanSymbols = 2;
    }
    int len = spanSymbols * sps + 1;
    int mid = len / 2;
    double[] taps = new double[](len);
    foreach (i; 0 .. len) {
        double t = (cast(double) i - mid) / cast(double) sps;
        taps[i] = rrcAt(t, beta);
    }
    double energy = 0;
    foreach (v; taps) {
        energy += v * v;
    }
    double scale = energy > 0 ? 1.0 / sqrt(energy) : 1;
    foreach (ref v; taps) {
        v *= scale;
    }
    return taps;
}

double[] rcTaps(int sps, int spanSymbols, double beta) {
    auto root = rrcTaps(sps, spanSymbols, beta);
    // A raised cosine is the convolution of two root raised cosines. Trim
    // is unnecessary: the caller can downsample the full convolution.
    return convolve(root, root);
}

double[] firLowpass(int taps, double cutoff, WindowKind kind, double beta = 6.0) {
    // cutoff is in cycles per sample, 0 < cutoff < 0.5.
    if (taps < 3) {
        taps = 3;
    }
    if ((taps % 2) == 0) {
        taps++;
    }
    int mid = taps / 2;
    double[] h = new double[](taps);
    foreach (i; 0 .. taps) {
        double n = cast(double) i - mid;
        h[i] = 2.0 * cutoff * sincPi(2.0 * cutoff * n);
    }
    auto w = windowByKind(kind, taps, beta);
    foreach (i; 0 .. taps) {
        h[i] *= w[i];
    }
    double sum = 0;
    foreach (v; h) {
        sum += v;
    }
    if (sum != 0) {
        foreach (ref v; h) {
            v /= sum;
        }
    }
    return h;
}

double[] firBandpass(int taps, double low, double high, WindowKind kind, double beta = 6.0) {
    auto hi = firLowpass(taps, high, kind, beta);
    auto lo = firLowpass(taps, low, kind, beta);
    double[] h = new double[](hi.length);
    foreach (i; 0 .. h.length) {
        h[i] = hi[i] - lo[i];
    }
    return h;
}

unittest {
    auto root = rrcTaps(4, 8, 0.35);
    assert(root.length == 33);
    double energy = 0;
    foreach (v; root) {
        energy += v * v;
    }
    assert(near(energy, 1.0, 1e-9, 1e-9));
    assert(near(root[0], root[$ - 1], 1e-12, 1e-12));
    auto rc = convolve(root, root);
    int mid = cast(int) root.length - 1;
    assert(near(rc[mid], 1.0, 1e-9, 1e-9));
    foreach (k; 1 .. 6) {
        int idx = mid + k * 4;
        if (idx < rc.length) {
            // An 8-symbol span truncates the tails, so the ISI is small
            // rather than a mathematical zero.
            assert(near(rc[idx], 0.0, 1.5e-2, 0.0));
        }
    }
    auto lp = firLowpass(31, 0.1, WindowKind.hamming);
    double dc = 0;
    foreach (v; lp) {
        dc += v;
    }
    assert(near(dc, 1.0, 1e-9, 1e-9));
    // A Nyquist-rate tone should be heavily attenuated relative to DC.
    double hi = 0;
    foreach (i, v; lp) {
        hi += v * cos(2.0 * PI * 0.45 * i);
    }
    double ahi = hi < 0 ? -hi : hi;
    assert(ahi < 0.05);
    auto bp = firBandpass(31, 0.1, 0.2, WindowKind.hann);
    assert(bp.length == 31);
}
