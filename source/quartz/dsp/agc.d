module quartz.dsp.agc;

import quartz.math.approx : near;
import quartz.math.complex : Complex;

// A one-pole automatic gain control. The gain moves toward the value that
// puts the output power on the target. A constant-modulus input settles
// there, which is the property the test locks.

@safe:

struct Agc {
    double target = 1;
    double alpha = 0.05;
    double gain = 1;

    Complex!double next(Complex!double x) {
        Complex!double y = x * gain;
        double power = y.mag2();
        double err = target - power;
        gain += alpha * err * gain;
        if (gain < 1e-6) {
            gain = 1e-6;
        }
        if (gain > 1e6) {
            gain = 1e6;
        }
        return y;
    }
}

unittest {
    auto agc = Agc(1.0, 0.02, 0.2);
    Complex!double last = Complex!double(0, 0);
    foreach (i; 0 .. 4000) {
        last = agc.next(Complex!double(0.25, -0.1));
    }
    assert(near(last.mag2(), 1.0, 0.05, 0.0));
}
