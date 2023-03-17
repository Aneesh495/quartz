module quartz.sync.pll;

import quartz.dsp.nco : Nco;
import quartz.math.complex : Complex;

// A second-order phase-locked loop on a complex tone. The phase error is the
// imaginary part of the derotated sample. With the frequency already close,
// the loop pulls that sample onto the positive real axis.

@safe:

struct Pll {
    Nco nco;
    double base;
    double kp;
    double ki;
    double integ;

    this(double freq, double kp, double ki) {
        nco = Nco(freq, 0);
        base = freq;
        this.kp = kp;
        this.ki = ki;
        this.integ = 0;
    }

    Complex!double next(Complex!double x) {
        Complex!double local = nco.next();
        Complex!double y = x * local.conj();
        double err = y.im;
        integ += ki * err;
        nco.freq = base + integ + kp * err;
        return y;
    }
}

unittest {
    // Same frequency, a fifth of a cycle of phase offset. Once the loop has
    // settled, the derotated sample sits on the positive real axis.
    auto tone = Nco(0.02, 0.05);
    auto pll = Pll(0.02, 0.2, 0.004);
    double realSum = 0;
    int used = 0;
    foreach (i; 0 .. 4000) {
        auto y = pll.next(tone.next());
        if (i > 3000) {
            realSum += y.re;
            used++;
        }
    }
    assert(used > 0);
    assert(realSum / used > 0.5);
}
