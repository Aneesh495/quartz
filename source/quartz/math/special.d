module quartz.math.special;

import quartz.math.approx : near;
import std.math : PI, fabs, floor, sin, sqrt;

// Scalar specials that the filter designer, the theory tables, and the FFT
// bit reversal all share. Series are capped so a coefficient computation can
// also run at compile time.

@safe:

double besselI0(double x) {
    // I0(x) = sum_k ((x/2)^k / k!)^2
    double half2 = (0.5 * x) * (0.5 * x);
    double term = 1.0;
    double sum = 1.0;
    foreach (k; 1 .. 80) {
        term *= half2 / (cast(double) k * cast(double) k);
        sum += term;
        if (term < sum * 1e-16) {
            break;
        }
    }
    return sum;
}

double sinc(double x) {
    if (fabs(x) < 1e-12) {
        return 1.0;
    }
    return sin(x) / x;
}

double sincPi(double x) {
    if (fabs(x) < 1e-12) {
        return 1.0;
    }
    return sin(PI * x) / (PI * x);
}

double wrapPi(double angle) {
    double two = 2.0 * PI;
    return angle - two * floor((angle + PI) / two);
}

double wrapHalf(double cycles) {
    // Wrap a frequency in cycles into [-0.5, 0.5).
    double w = cycles - floor(cycles + 0.5);
    if (w == 0.5) {
        return -0.5;
    }
    return w;
}

double log2Floor(double x) {
    import std.math : log;
    return log(x) / log(2.0);
}

size_t nextPow2(size_t n) {
    if (n <= 1) {
        return 1;
    }
    n--;
    n |= n >> 1;
    n |= n >> 2;
    n |= n >> 4;
    n |= n >> 8;
    n |= n >> 16;
    static if (size_t.sizeof > 4) {
        n |= n >> 32;
    }
    return n + 1;
}

bool isPow2(size_t n) {
    return n != 0 && (n & (n - 1)) == 0;
}

size_t bitReverse(size_t x, int bits) {
    size_t y = 0;
    foreach (_; 0 .. bits) {
        y = (y << 1) | (x & 1);
        x >>= 1;
    }
    return y;
}

int popcount(ulong x) {
    int n = 0;
    while (x != 0) {
        x &= x - 1;
        n++;
    }
    return n;
}

int parity(ulong x) {
    return popcount(x) & 1;
}

// Greatest k such that 2^k <= n, or 0 when n is 0.
int floorLog2(size_t n) {
    int k = 0;
    while (n > 1) {
        n >>= 1;
        k++;
    }
    return k;
}

unittest {
    assert(near(besselI0(0.0), 1.0, 1e-15, 0.0));
    assert(near(besselI0(1.0), 1.2660658777520082, 1e-12, 1e-12));
    assert(near(besselI0(2.0), 2.2795853023360673, 1e-12, 1e-12));
    assert(near(sinc(0.0), 1.0, 0.0, 0.0));
    assert(near(sincPi(0.0), 1.0, 0.0, 0.0));
    assert(near(sincPi(1.0), 0.0, 1e-12, 0.0));
    assert(near(wrapPi(0.0), 0.0, 1e-15, 0.0));
    assert(near(wrapPi(3 * PI), PI, 1e-12, 1e-12) || near(wrapPi(3 * PI), -PI, 1e-12, 1e-12));
    assert(near(wrapHalf(1.25), 0.25, 1e-15, 0.0));
    assert(near(wrapHalf(-0.25), -0.25, 1e-15, 0.0));
    assert(near(wrapHalf(0.75), -0.25, 1e-15, 0.0));
    assert(nextPow2(1) == 1);
    assert(nextPow2(3) == 4);
    assert(nextPow2(64) == 64);
    assert(isPow2(128));
    assert(!isPow2(0));
    assert(!isPow2(12));
    assert(bitReverse(1, 4) == 8);
    assert(bitReverse(0b0001, 3) == 0b100);
    assert(popcount(0b1011) == 3);
    assert(parity(0b111) == 1);
    assert(parity(0b110) == 0);
    assert(floorLog2(1) == 0);
    assert(floorLog2(8) == 3);
    assert(floorLog2(9) == 3);
}
