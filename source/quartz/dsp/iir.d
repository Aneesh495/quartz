module quartz.dsp.iir;

import quartz.math.approx : near;
import std.math : PI, cos, sin, sqrt;

// Transposed direct form II biquads. A Butterworth lowpass is a cascade of
// these sections, designed by the bilinear cookbook rather than by rooting
// the analog polynomial at runtime. DC gain of the lowpass is 1.

@safe:

struct Biquad {
    double b0 = 1;
    double b1 = 0;
    double b2 = 0;
    double a1 = 0;
    double a2 = 0;
    double z1 = 0;
    double z2 = 0;

    double next(double x) {
        double y = b0 * x + z1;
        z1 = b1 * x - a1 * y + z2;
        z2 = b2 * x - a2 * y;
        return y;
    }

    void reset() {
        z1 = 0;
        z2 = 0;
    }
}

Biquad lowpassBiquad(double cutoff, double q) {
    // cutoff in cycles per sample.
    double w0 = 2.0 * PI * cutoff;
    double alpha = sin(w0) / (2.0 * q);
    double cw = cos(w0);
    double b0 = (1.0 - cw) / 2.0;
    double b1 = 1.0 - cw;
    double b2 = (1.0 - cw) / 2.0;
    double a0 = 1.0 + alpha;
    double a1 = -2.0 * cw;
    double a2 = 1.0 - alpha;
    Biquad s;
    s.b0 = b0 / a0;
    s.b1 = b1 / a0;
    s.b2 = b2 / a0;
    s.a1 = a1 / a0;
    s.a2 = a2 / a0;
    return s;
}

struct SosFilter {
    Biquad[] sections;

    double next(double x) {
        double y = x;
        foreach (ref section; sections) {
            y = section.next(y);
        }
        return y;
    }

    void reset() {
        foreach (ref section; sections) {
            section.reset();
        }
    }
}

SosFilter butterworthLowpass(int order, double cutoff) {
    if (order < 2) {
        order = 2;
    }
    if ((order % 2) != 0) {
        order++;
    }
    SosFilter filter;
    int pairs = order / 2;
    foreach (k; 0 .. pairs) {
        double theta = PI * (2.0 * k + 1.0) / (2.0 * order);
        double q = 1.0 / (2.0 * cos(theta));
        if (q < 0) {
            q = -q;
        }
        filter.sections ~= lowpassBiquad(cutoff, q);
    }
    return filter;
}

double[] runSos(SosFilter filter, const(double)[] input) {
    double[] y = new double[](input.length);
    foreach (i, x; input) {
        y[i] = filter.next(x);
    }
    return y;
}

unittest {
    auto lp = butterworthLowpass(4, 0.05);
    double[] step = new double[](400);
    step[] = 1;
    auto y = runSos(lp, step);
    assert(near(y[$ - 1], 1.0, 1e-3, 1e-3));
    double[] high = new double[](256);
    foreach (i; 0 .. high.length) {
        high[i] = cos(2.0 * PI * 0.4 * i);
    }
    auto filtered = SosFilter(lp.sections.dup);
    // sections were already run; rebuild.
    auto fresh = butterworthLowpass(4, 0.05);
    auto hy = runSos(fresh, high);
    double power = 0;
    foreach (i; hy.length / 2 .. hy.length) {
        power += hy[i] * hy[i];
    }
    power /= cast(double) (hy.length / 2);
    assert(power < 1e-3);
    auto one = lowpassBiquad(0.1, 1.0 / sqrt(2.0));
    double dc = one.b0 + one.b1 + one.b2;
    double da = 1.0 + one.a1 + one.a2;
    assert(near(dc / da, 1.0, 1e-9, 1e-9));
}
