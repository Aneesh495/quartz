module quartz.math.rational;

import quartz.error : QuartzError;
import std.math : fabs;

// Exact ratios for sample clocks and resampling. A rate pair such as
// 44100 to 48000 becomes a reduced up/down fraction so the polyphase
// resampler does not accumulate a drift from a truncated double.

@safe:

long iabs(long v) {
    if (v < 0) {
        if (v == long.min) {
            throw new QuartzError("absolute value of long.min is not representable");
        }
        return -v;
    }
    return v;
}

long gcdLong(long a, long b) {
    a = iabs(a);
    b = iabs(b);
    while (b != 0) {
        long t = a % b;
        a = b;
        b = t;
    }
    return a;
}

long lcmLong(long a, long b) {
    if (a == 0 || b == 0) {
        return 0;
    }
    long g = gcdLong(a, b);
    return checkedMul(iabs(a) / g, iabs(b));
}

bool mulOverflows(long a, long b) {
    if (a == 0 || b == 0) {
        return false;
    }
    if (a == long.min || b == long.min) {
        return true;
    }
    long aa = iabs(a);
    long bb = iabs(b);
    return aa > long.max / bb;
}

long checkedMul(long a, long b) {
    if (mulOverflows(a, b)) {
        throw new QuartzError("rational multiplication overflow");
    }
    return a * b;
}

long checkedAdd(long a, long b) {
    if (b > 0 && a > long.max - b) {
        throw new QuartzError("rational addition overflow");
    }
    if (b < 0 && a < long.min - b) {
        throw new QuartzError("rational addition overflow");
    }
    return a + b;
}

struct Rational {
    long num = 0;
    long den = 1;

    this(long num, long den) {
        if (den == 0) {
            throw new QuartzError("rational denominator is zero");
        }
        if (den < 0) {
            if (num == long.min || den == long.min) {
                throw new QuartzError("rational sign flip overflows");
            }
            num = -num;
            den = -den;
        }
        long g = gcdLong(num, den);
        this.num = num / g;
        this.den = den / g;
    }

    static Rational fromInt(long n) {
        return Rational(n, 1);
    }

    double toDouble() const {
        return cast(double) num / cast(double) den;
    }

    bool isZero() const {
        return num == 0;
    }

    bool isOne() const {
        return num == 1 && den == 1;
    }

    Rational inverse() const {
        if (num == 0) {
            throw new QuartzError("inverse of zero rational");
        }
        return Rational(den, num);
    }

    Rational opUnary(string op)() const if (op == "-") {
        if (num == long.min) {
            throw new QuartzError("negation overflows");
        }
        return Rational(-num, den);
    }

    Rational opBinary(string op)(Rational rhs) const {
        static if (op == "+") {
            long n = checkedAdd(checkedMul(num, rhs.den), checkedMul(rhs.num, den));
            long d = checkedMul(den, rhs.den);
            return Rational(n, d);
        } else static if (op == "-") {
            return this + (-rhs);
        } else static if (op == "*") {
            return Rational(checkedMul(num, rhs.num), checkedMul(den, rhs.den));
        } else static if (op == "/") {
            return this * rhs.inverse();
        } else {
            static assert(0, "unsupported rational operator");
        }
    }

    int opCmp(Rational rhs) const {
        // Compare by cross product. Overflow is reported rather than wrapped.
        long left = checkedMul(num, rhs.den);
        long right = checkedMul(rhs.num, den);
        if (left < right) {
            return -1;
        }
        if (left > right) {
            return 1;
        }
        return 0;
    }

    bool opEquals(Rational rhs) const {
        return num == rhs.num && den == rhs.den;
    }
}

// Reduced resampling ratio that turns inRate into outRate.
struct ClockRatio {
    long up;
    long down;

    static ClockRatio fromRates(long inRate, long outRate) {
        if (inRate <= 0 || outRate <= 0) {
            throw new QuartzError("sample rates must be positive");
        }
        long g = gcdLong(inRate, outRate);
        return ClockRatio(outRate / g, inRate / g);
    }

    Rational asRational() const {
        return Rational(up, down);
    }
}

unittest {
    assert(gcdLong(44100, 48000) == 300);
    assert(lcmLong(6, 8) == 24);
    auto r = Rational(2, 4);
    assert(r.num == 1 && r.den == 2);
    auto s = Rational(-3, -9);
    assert(s.num == 1 && s.den == 3);
    auto t = Rational(1, 2) + Rational(1, 3);
    assert(t == Rational(5, 6));
    assert(Rational(3, 4) * Rational(2, 3) == Rational(1, 2));
    assert((Rational(3, 4) / Rational(3, 2)) == Rational(1, 2));
    assert(Rational(-1, 2) < Rational(1, 3));
    assert(fabs(Rational(1, 8).toDouble() - 0.125) < 1e-15);
    auto ratio = ClockRatio.fromRates(44100, 48000);
    assert(ratio.up == 160);
    assert(ratio.down == 147);
    bool threw = false;
    try {
        auto bad = Rational(1, 0);
        assert(bad.num == 0);
    } catch (QuartzError) {
        threw = true;
    }
    assert(threw);
}
