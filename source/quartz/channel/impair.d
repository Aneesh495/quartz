module quartz.channel.impair;

import quartz.math.approx : near;
import quartz.math.complex : Complex, nearC;
import std.math : PI, cos, sin;

// Deterministic sample impairments: a carrier mix, a constant IQ imbalance,
// and a uniform quantizer. Each one is invertible or measurable on its own,
// which is the bar before they are stacked.

@safe:

void applyTone(Complex!double[] samples, double cyclesPerSample) {
    double phase = 0;
    foreach (ref s; samples) {
        Complex!double rot = Complex!double(cos(2 * PI * phase), sin(2 * PI * phase));
        s = s * rot;
        phase += cyclesPerSample;
    }
}

void applyIqImbalance(Complex!double[] samples, double gain, double phaseRad) {
    double c = cos(phaseRad);
    double s = sin(phaseRad);
    foreach (ref x; samples) {
        double i = x.re;
        double q = x.im * gain;
        x = Complex!double(i, q * c + i * s);
    }
}

void quantize(Complex!double[] samples, int levels) {
    if (levels < 2) {
        levels = 2;
    }
    double step = 2.0 / cast(double) levels;
    foreach (ref x; samples) {
        x.re = quantizeScalar(x.re, step);
        x.im = quantizeScalar(x.im, step);
    }
}

private double quantizeScalar(double v, double step) {
    if (v > 1) {
        v = 1;
    }
    if (v < -1) {
        v = -1;
    }
    double q = (cast(int) (v / step)) * step;
    if (q > 1) {
        q = 1;
    }
    if (q < -1) {
        q = -1;
    }
    return q;
}

unittest {
    Complex!double[] tone = [Complex!double(1, 0), Complex!double(1, 0)];
    applyTone(tone, 0.25);
    assert(nearC(tone[0], Complex!double(1, 0), 1e-9, 1e-9));
    assert(nearC(tone[1], Complex!double(0, 1), 1e-9, 1e-9));
    Complex!double[] pair = [Complex!double(0.5, 0.25)];
    applyIqImbalance(pair, 1, 0);
    assert(near(pair[0].re, 0.5, 1e-12, 0.0));
    assert(near(pair[0].im, 0.25, 1e-12, 0.0));
    Complex!double[] q = [Complex!double(0.3, -0.7)];
    quantize(q, 4);
    assert(q[0].re <= 0.3 + 0.5);
    assert(q[0].im >= -1);
}
