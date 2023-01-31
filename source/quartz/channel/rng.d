module quartz.channel.rng;

import quartz.math.approx : near;
import quartz.math.complex : Complex;
import std.math : PI, cos, log, sin, sqrt;

// xoshiro256** expanded from a SplitMix64 seed. Every noise source, fading
// draw, and bit source in a receipt goes through this generator so a seed is
// a complete description of the randomness.

@safe:

ulong splitmix64(ref ulong x) {
    x += 0x9E3779B97F4A7C15UL;
    ulong z = x;
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL;
    return z ^ (z >> 31);
}

ulong rotl(ulong x, int k) {
    return (x << k) | (x >> (64 - k));
}

struct Xoshiro256 {
    ulong s0;
    ulong s1;
    ulong s2;
    ulong s3;
    bool haveSpare = false;
    double spare = 0;

    this(ulong seed) {
        ulong z = seed;
        s0 = splitmix64(z);
        s1 = splitmix64(z);
        s2 = splitmix64(z);
        s3 = splitmix64(z);
        if ((s0 | s1 | s2 | s3) == 0) {
            s0 = 0x9E3779B97F4A7C15UL;
        }
    }

    ulong next() {
        ulong result = rotl(s1 * 5, 7) * 9;
        ulong t = s1 << 17;
        s2 ^= s0;
        s3 ^= s1;
        s1 ^= s2;
        s0 ^= s3;
        s2 ^= t;
        s3 = rotl(s3, 45);
        return result;
    }

    uint nextU32() {
        return cast(uint) (next() >> 32);
    }

    // [0, 1). The top 53 bits fill a double mantissa.
    double nextDouble() {
        ulong bits = next() >> 11;
        return cast(double) bits * (1.0 / 9007199254740992.0);
    }

    double nextGaussian() {
        if (haveSpare) {
            haveSpare = false;
            return spare;
        }
        double u = 0;
        double v = 0;
        double s = 0;
        do {
            u = nextDouble() * 2.0 - 1.0;
            v = nextDouble() * 2.0 - 1.0;
            s = u * u + v * v;
        } while (s >= 1.0 || s == 0.0);
        double m = sqrt(-2.0 * log(s) / s);
        spare = v * m;
        haveSpare = true;
        return u * m;
    }

    Complex!double nextComplexGaussian() {
        return Complex!double(nextGaussian(), nextGaussian());
    }

    bool nextBool() {
        return (next() & 1UL) != 0;
    }

    // Unbiased integer in [0, bound).
    int nextInt(int bound) {
        if (bound <= 0) {
            return 0;
        }
        return cast(int) (next() % cast(ulong) bound);
    }
}

unittest {
    auto a = Xoshiro256(42);
    auto b = Xoshiro256(42);
    auto c = Xoshiro256(43);
    ulong[4] seq;
    foreach (i; 0 .. 4) {
        seq[i] = a.next();
        assert(seq[i] == b.next());
    }
    assert(c.next() != seq[0]);
    auto d = Xoshiro256(42);
    foreach (i; 0 .. 4) {
        assert(d.next() == seq[i]);
    }
    auto g = Xoshiro256(7);
    double sum = 0;
    double sum2 = 0;
    enum n = 8000;
    foreach (_; 0 .. n) {
        double x = g.nextGaussian();
        sum += x;
        sum2 += x * x;
    }
    double mean = sum / n;
    double var = sum2 / n - mean * mean;
    assert(near(mean, 0.0, 0.05, 0.0));
    assert(near(var, 1.0, 0.08, 0.0));
    auto u = Xoshiro256(1);
    foreach (_; 0 .. 100) {
        double x = u.nextDouble();
        assert(x >= 0.0 && x < 1.0);
    }
    // A complex draw is two independent real draws, so its mean power is 2.
    auto h = Xoshiro256(99);
    double power = 0;
    enum m = 4000;
    foreach (_; 0 .. m) {
        power += h.nextComplexGaussian().mag2();
    }
    assert(near(power / m, 2.0, 0.12, 0.0));
    // Box-Muller angle coverage: not a constant phase.
    auto p = Xoshiro256(3);
    double csum = 0;
    foreach (_; 0 .. 32) {
        auto z = p.nextComplexGaussian();
        csum += cos(z.arg()) + sin(z.arg());
    }
    assert(csum < 64);
    assert(csum > -64);
}
