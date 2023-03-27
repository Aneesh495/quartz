module quartz.measure.evm;

import quartz.math.approx : near;
import quartz.math.complex : Complex;
import std.math : sqrt;

// RMS error vector magnitude, normalized by the reference energy.
// Identical sequences score zero. A pure scale error scores the relative
// distance, which is what a constellation plot is showing numerically.

@safe:

double evmRms(const(Complex!double)[] got, const(Complex!double)[] reference) {
    size_t n = got.length < reference.length ? got.length : reference.length;
    if (n == 0) {
        return 0;
    }
    double err = 0;
    double energy = 0;
    foreach (i; 0 .. n) {
        err += (got[i] - reference[i]).mag2();
        energy += reference[i].mag2();
    }
    if (energy == 0) {
        return sqrt(err / n);
    }
    return sqrt(err / energy);
}

unittest {
    Complex!double[] ideal = [Complex!double(1, 0), Complex!double(-1, 0)];
    assert(near(evmRms(ideal, ideal), 0.0, 1e-15, 0.0));
    Complex!double[] noisy = [Complex!double(1.1, 0), Complex!double(-0.9, 0)];
    double evm = evmRms(noisy, ideal);
    assert(evm > 0.05 && evm < 0.15);
}
