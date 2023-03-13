module quartz.modem.differential;

import quartz.math.complex : Complex, nearC;
import std.math : PI;

// Differential BPSK and QPSK. The first symbol is a reference. Each later
// symbol is the previous one rotated by the information phase. A silent
// channel returns the bits, including a rotation of the whole burst, because
// only the differences are information.

@safe:

Complex!double[] dbpskModulate(const(bool)[] bits) {
    auto y = new Complex!double[](bits.length + 1);
    y[0] = Complex!double(1, 0);
    foreach (i, bit; bits) {
        Complex!double step = bit ? Complex!double(-1, 0) : Complex!double(1, 0);
        y[i + 1] = y[i] * step;
    }
    return y;
}

bool[] dbpskDemodulate(const(Complex!double)[] symbols) {
    if (symbols.length < 2) {
        return [];
    }
    bool[] bits = new bool[](symbols.length - 1);
    foreach (i; 0 .. bits.length) {
        Complex!double d = symbols[i + 1] * symbols[i].conj();
        bits[i] = d.re < 0;
    }
    return bits;
}

Complex!double[] dqpskModulate(const(bool)[] bits) {
    int symbols = cast(int) bits.length / 2;
    auto y = new Complex!double[](symbols + 1);
    y[0] = Complex!double(1, 0);
    foreach (s; 0 .. symbols) {
        bool b0 = bits[s * 2];
        bool b1 = bits[s * 2 + 1];
        // Gray phase steps: 00 -> 0, 01 -> pi/2, 11 -> pi, 10 -> -pi/2.
        int idx = (b0 ? 2 : 0) + (b1 ? 1 : 0);
        double phase = [0.0, PI / 2, -PI / 2, PI][idx];
        y[s + 1] = y[s] * Complex!double.cis(phase);
    }
    return y;
}

bool[] dqpskDemodulate(const(Complex!double)[] symbols) {
    if (symbols.length < 2) {
        return [];
    }
    bool[] bits;
    foreach (i; 0 .. symbols.length - 1) {
        Complex!double d = symbols[i + 1] * symbols[i].conj();
        // Nearest of 0, pi/2, pi, -pi/2. Axes belong to the adjacent
        // decision by the strict inequalities below.
        if (d.re > d.im && d.re > -d.im) {
            bits ~= false;
            bits ~= false;
        } else if (d.im > d.re && d.im > -d.re) {
            bits ~= false;
            bits ~= true;
        } else if (-d.re > d.im && -d.re > -d.im) {
            bits ~= true;
            bits ~= true;
        } else {
            bits ~= true;
            bits ~= false;
        }
    }
    return bits;
}

unittest {
    bool[] bits = [true, false, true, true, false, false, true];
    auto db = dbpskModulate(bits);
    assert(dbpskDemodulate(db) == bits);
    Complex!double rot = Complex!double.cis(0.4);
    foreach (ref s; db) {
        s = s * rot;
    }
    assert(dbpskDemodulate(db) == bits);
    bool[] qbits = [false, false, false, true, true, true, true, false];
    auto dq = dqpskModulate(qbits);
    assert(dqpskDemodulate(dq) == qbits);
    assert(nearC(dq[0], Complex!double(1, 0), 1e-12, 1e-12));
}
