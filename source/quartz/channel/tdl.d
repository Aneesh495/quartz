module quartz.channel.tdl;

import quartz.math.approx : near;
import quartz.math.complex : Complex, nearC;

// A tapped delay line. An impulse comes out as the tap vector. A flat
// one-tap channel is ordinary complex scaling, which the OFDM path also uses.

@safe:

struct TappedDelay {
    Complex!double[] taps;
    Complex!double[] memory;

    this(const(Complex!double)[] taps) {
        this.taps = taps.dup;
        this.memory = new Complex!double[](taps.length);
        foreach (ref m; this.memory) {
            m = Complex!double(0, 0);
        }
    }

    Complex!double next(Complex!double x) {
        if (memory.length == 0) {
            return Complex!double(0, 0);
        }
        for (size_t i = memory.length - 1; i > 0; i--) {
            memory[i] = memory[i - 1];
        }
        memory[0] = x;
        Complex!double y = Complex!double(0, 0);
        foreach (i, tap; taps) {
            y = y + tap * memory[i];
        }
        return y;
    }
}

unittest {
    auto line = TappedDelay([
        Complex!double(0.5, 0.0),
        Complex!double(0.0, -0.25),
        Complex!double(0.125, 0.0)
    ]);
    auto y0 = line.next(Complex!double(1, 0));
    auto y1 = line.next(Complex!double(0, 0));
    auto y2 = line.next(Complex!double(0, 0));
    auto y3 = line.next(Complex!double(0, 0));
    assert(nearC(y0, Complex!double(0.5, 0), 1e-12, 1e-12));
    assert(nearC(y1, Complex!double(0, -0.25), 1e-12, 1e-12));
    assert(nearC(y2, Complex!double(0.125, 0), 1e-12, 1e-12));
    assert(near(y3.mag(), 0.0, 1e-12, 0.0));
}
