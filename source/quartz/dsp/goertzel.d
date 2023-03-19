module quartz.dsp.goertzel;

import quartz.math.approx : near;
import std.math : PI, cos, sin;

// Goertzel power at one bin. A tone that lands on that bin produces a large
// reading, and a tone a few bins away does not. This is the single-bin form
// of the DFT the periodogram computes in bulk.

@safe:

double goertzelPower(const(double)[] samples, int bin) {
    if (samples.length == 0) {
        return 0;
    }
    double w = 2.0 * PI * bin / cast(double) samples.length;
    double coeff = 2.0 * cos(w);
    double s0 = 0;
    double s1 = 0;
    double s2 = 0;
    foreach (x; samples) {
        s0 = x + coeff * s1 - s2;
        s2 = s1;
        s1 = s0;
    }
    return s1 * s1 + s2 * s2 - coeff * s1 * s2;
}

unittest {
    int n = 64;
    double[] tone = new double[](n);
    foreach (i; 0 .. n) {
        tone[i] = cos(2.0 * PI * 5 * i / n);
    }
    double on = goertzelPower(tone, 5);
    double off = goertzelPower(tone, 9);
    assert(on > off * 20);
    assert(near(sin(0.0), 0.0, 0.0, 0.0));
}
