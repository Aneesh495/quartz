module quartz.math.qformat;

import quartz.math.approx : near;

// Signed fixed point kept in a 32-bit word with an explicit fraction length.
// Multiplication rounds to nearest, half away from zero, and saturates.
// Packed Q15 is a separate step: the wide word is the working format, and
// the int16 form is what a sample file would store.

@safe:

struct Fixed(int frac) if (frac > 0 && frac < 28) {
    int raw = 0;

    enum int one = 1 << frac;
    enum double scale = 2.0 ^^ frac;
    enum int fractionBits = frac;

    static long roundDiv(long prod) {
        long half = 1L << (frac - 1);
        if (prod >= 0) {
            return (prod + half) >> frac;
        }
        return -(((-prod) + half) >> frac);
    }

    static int saturate(long v) {
        if (v > int.max) {
            return int.max;
        }
        if (v < int.min) {
            return int.min;
        }
        return cast(int) v;
    }

    static int roundDouble(double s) {
        if (s >= 0) {
            return saturate(cast(long) (s + 0.5));
        }
        return saturate(cast(long) (s - 0.5));
    }

    static Fixed fromDouble(double x) {
        return Fixed(roundDouble(x * scale));
    }

    static Fixed fromRaw(int raw) {
        return Fixed(raw);
    }

    double toDouble() const {
        return cast(double) raw / scale;
    }

    Fixed opUnary(string op)() const if (op == "-") {
        if (raw == int.min) {
            return Fixed(int.max);
        }
        return Fixed(-raw);
    }

    Fixed opBinary(string op)(Fixed rhs) const {
        static if (op == "+") {
            return Fixed(saturate(cast(long) raw + rhs.raw));
        } else static if (op == "-") {
            return Fixed(saturate(cast(long) raw - rhs.raw));
        } else static if (op == "*") {
            long prod = cast(long) raw * rhs.raw;
            return Fixed(saturate(roundDiv(prod)));
        } else {
            static assert(0, "unsupported fixed operator");
        }
    }

    Fixed opOpAssign(string op)(Fixed rhs) {
        this = opBinary!op(rhs);
        return this;
    }
}

alias Q15 = Fixed!15;
alias Q23 = Fixed!23;

short packQ15(Q15 q) {
    long r = q.raw;
    if (r > 32767) {
        r = 32767;
    }
    if (r < -32768) {
        r = -32768;
    }
    return cast(short) r;
}

Q15 unpackQ15(short packed) {
    return Q15.fromRaw(packed);
}

Q15 dotQ15(const(Q15)[] a, const(Q15)[] b) {
    long acc = 0;
    size_t n = a.length < b.length ? a.length : b.length;
    foreach (i; 0 .. n) {
        acc += cast(long) a[i].raw * b[i].raw;
    }
    return Q15.fromRaw(Q15.saturate(Q15.roundDiv(acc)));
}

double maxAbsError(const(double)[] reference, const(Q15)[] got) {
    double m = 0;
    size_t n = reference.length < got.length ? reference.length : got.length;
    foreach (i; 0 .. n) {
        double d = reference[i] - got[i].toDouble();
        if (d < 0) {
            d = -d;
        }
        if (d > m) {
            m = d;
        }
    }
    return m;
}

unittest {
    Q15 half = Q15.fromDouble(0.5);
    Q15 quarter = half * half;
    assert(near(quarter.toDouble(), 0.25, 1.0 / 32768.0, 0.0));
    Q15 neg = -half * half;
    assert(near(neg.toDouble(), -0.25, 1.0 / 32768.0, 0.0));
    Q15 huge = Q15.fromDouble(1.0e8);
    Q15 saturated = huge + huge;
    assert(saturated.raw == int.max);
    short packed = packQ15(half);
    assert(packed == 16384);
    assert(unpackQ15(packed).raw == 16384);
    Q15[] taps = [Q15.fromDouble(0.25), Q15.fromDouble(-0.5), Q15.fromDouble(0.125)];
    Q15[] impulse = [Q15.fromDouble(1.0), Q15.fromDouble(0.0), Q15.fromDouble(0.0)];
    Q15 d = dotQ15(taps, impulse);
    assert(near(d.toDouble(), 0.25, 1.0 / 32768.0, 0.0));
    short sat = packQ15(Q15.fromDouble(2.0));
    assert(sat == 32767);
    short satn = packQ15(Q15.fromDouble(-2.0));
    assert(satn == -32768);
}
