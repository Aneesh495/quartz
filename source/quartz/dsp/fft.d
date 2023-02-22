module quartz.dsp.fft;

import quartz.math.approx : near;
import quartz.math.complex : Complex, energy, nearC;
import quartz.math.special : bitReverse, floorLog2, isPow2, nextPow2;
import std.math : PI, cos, sin;

// Radix-2 FFT plus Bluestein's algorithm for every other length. The forward
// transform is unnormalized. The inverse divides by n, so a round trip is the
// identity up to roundoff. A naive DFT sits in this file as the oracle.

@safe:

alias C = Complex!double;

void swapAt(C[] data, size_t i, size_t j) {
    C tmp = data[i];
    data[i] = data[j];
    data[j] = tmp;
}

void fftRadix2(C[] data, bool inverse) {
    size_t n = data.length;
    if (!isPow2(n) || n == 0) {
        return;
    }
    int bits = floorLog2(n);
    foreach (i; 0 .. n) {
        size_t j = bitReverse(i, bits);
        if (j > i) {
            swapAt(data, i, j);
        }
    }
    for (size_t len = 2; len <= n; len <<= 1) {
        double ang = (inverse ? 2.0 : -2.0) * PI / cast(double) len;
        C wlen = C.cis(ang);
        for (size_t i = 0; i < n; i += len) {
            C w = C(1, 0);
            size_t half = len / 2;
            foreach (j; 0 .. half) {
                C u = data[i + j];
                C v = data[i + j + half] * w;
                data[i + j] = u + v;
                data[i + j + half] = u - v;
                w = w * wlen;
            }
        }
    }
    if (inverse) {
        double scale = 1.0 / cast(double) n;
        foreach (ref bin; data) {
            bin = bin * scale;
        }
    }
}

C[] dftNaive(const(C)[] input, bool inverse) {
    size_t n = input.length;
    C[] y = new C[](n);
    foreach (ref bin; y) {
        bin = C(0, 0);
    }
    double sign = inverse ? 1.0 : -1.0;
    foreach (k; 0 .. n) {
        C sum = C(0, 0);
        foreach (t; 0 .. n) {
            double ang = sign * 2.0 * PI * cast(double) k * cast(double) t / cast(double) n;
            sum = sum + input[t] * C.cis(ang);
        }
        if (inverse && n > 0) {
            sum = sum * (1.0 / cast(double) n);
        }
        y[k] = sum;
    }
    return y;
}

C[] fftAny(const(C)[] input, bool inverse) {
    if (input.length == 0) {
        return [];
    }
    if (isPow2(input.length)) {
        C[] y = input.dup;
        fftRadix2(y, inverse);
        return y;
    }
    return bluestein(input, inverse);
}

private C[] bluestein(const(C)[] input, bool inverse) {
    size_t n = input.length;
    size_t m = nextPow2(2 * n - 1);
    double sign = inverse ? -1.0 : 1.0;
    C[] chirp = new C[](n);
    foreach (k; 0 .. n) {
        double ang = sign * PI * cast(double) k * cast(double) k / cast(double) n;
        chirp[k] = C.cis(ang);
    }
    C[] a = new C[](m);
    C[] b = new C[](m);
    foreach (ref v; a) {
        v = C(0, 0);
    }
    foreach (ref v; b) {
        v = C(0, 0);
    }
    foreach (k; 0 .. n) {
        a[k] = input[k] * chirp[k].conj();
        b[k] = chirp[k];
        if (k > 0) {
            b[m - k] = chirp[k];
        }
    }
    fftRadix2(a, false);
    fftRadix2(b, false);
    foreach (i; 0 .. m) {
        a[i] = a[i] * b[i];
    }
    fftRadix2(a, true);
    C[] y = new C[](n);
    double inv = inverse ? (1.0 / cast(double) n) : 1.0;
    foreach (k; 0 .. n) {
        y[k] = a[k] * chirp[k].conj() * inv;
    }
    return y;
}

unittest {
    C[] impulse = new C[](8);
    foreach (ref v; impulse) {
        v = C(0, 0);
    }
    impulse[0] = C(1, 0);
    auto spec = impulse.dup;
    fftRadix2(spec, false);
    foreach (bin; spec) {
        assert(nearC(bin, C(1, 0), 1e-9, 1e-9));
    }
    C[] tone = [C(1, 0), C(2, -1), C(0, 0.5), C(-1, 1)];
    auto fast = tone.dup;
    fftRadix2(fast, false);
    auto slow = dftNaive(tone, false);
    foreach (i; 0 .. tone.length) {
        assert(nearC(fast[i], slow[i], 1e-9, 1e-9));
    }
    auto back = fast.dup;
    fftRadix2(back, true);
    foreach (i; 0 .. tone.length) {
        assert(nearC(back[i], tone[i], 1e-9, 1e-9));
    }
    C[] odd = [C(1, 0), C(-0.5, 0.25), C(0.3, -0.7), C(0, 1), C(0.2, 0.2), C(-1, 0)];
    auto any = fftAny(odd, false);
    auto naive = dftNaive(odd, false);
    foreach (i; 0 .. odd.length) {
        assert(nearC(any[i], naive[i], 1e-8, 1e-8));
    }
    auto round = fftAny(any, true);
    foreach (i; 0 .. odd.length) {
        assert(nearC(round[i], odd[i], 1e-8, 1e-8));
    }
    assert(near(energy(tone), energy(tone), 0.0, 0.0));
}
