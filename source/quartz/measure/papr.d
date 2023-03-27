module quartz.measure.papr;

import quartz.math.approx : near;
import quartz.math.complex : Complex;
import quartz.units : db10;

// Peak to average power, in decibels. A constant-modulus tone scores zero.
// OFDM does not, which is why the waveform notes talk about the backoff.

@safe:

double paprDb(const(Complex!double)[] samples) {
    if (samples.length == 0) {
        return 0;
    }
    double peak = 0;
    double mean = 0;
    foreach (s; samples) {
        double p = s.mag2();
        mean += p;
        if (p > peak) {
            peak = p;
        }
    }
    mean /= cast(double) samples.length;
    if (mean <= 0) {
        return 0;
    }
    return db10(peak / mean);
}

unittest {
    Complex!double[] tone = new Complex!double[](32);
    foreach (ref s; tone) {
        s = Complex!double(0.5, -0.5);
    }
    assert(near(paprDb(tone), 0.0, 1e-9, 1e-9));
    Complex!double[] spike = new Complex!double[](8);
    foreach (ref s; spike) {
        s = Complex!double(0, 0);
    }
    spike[3] = Complex!double(1, 0);
    assert(paprDb(spike) > 8);
}
