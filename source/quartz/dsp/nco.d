module quartz.dsp.nco;

import quartz.math.approx : near;
import quartz.math.complex : Complex, nearC;
import quartz.math.special : wrapHalf;
import std.math : PI;

// A complex NCO whose phase lives in cycles, not radians. One cycle is one
// turn, so a frequency of 0.25 cycles per sample is a bin center on a length
// that is a multiple of 4, and the phase can be wrapped with a subtraction
// instead of a trigonometric reduction.

@safe:

struct Nco {
    double phase;
    double freq;

    this(double freqCycles, double phaseCycles = 0) {
        this.freq = freqCycles;
        this.phase = wrapHalf(phaseCycles);
    }

    Complex!double next() {
        Complex!double z = Complex!double.cis(2.0 * PI * phase);
        phase = wrapHalf(phase + freq);
        return z;
    }

    Complex!double[] tone(int n) {
        auto y = new Complex!double[](n);
        foreach (i; 0 .. n) {
            y[i] = next();
        }
        return y;
    }
}

void mixDown(Complex!double[] samples, double freqCycles) {
    auto osc = Nco(-freqCycles, 0);
    foreach (ref s; samples) {
        s = s * osc.next();
    }
}

unittest {
    auto osc = Nco(0.25, 0);
    auto z0 = osc.next();
    auto z1 = osc.next();
    auto z2 = osc.next();
    auto z3 = osc.next();
    assert(nearC(z0, Complex!double(1, 0), 1e-9, 1e-9));
    assert(nearC(z1, Complex!double(0, 1), 1e-9, 1e-9));
    assert(nearC(z2, Complex!double(-1, 0), 1e-9, 1e-9));
    assert(nearC(z3, Complex!double(0, -1), 1e-9, 1e-9));
    Complex!double[] carrier = Nco(0.1, 0).tone(64);
    mixDown(carrier, 0.1);
    foreach (s; carrier) {
        assert(near(s.re, 1.0, 1e-6, 1e-6));
        assert(near(s.im, 0.0, 1e-6, 1e-6));
    }
}
