module quartz.modem.fsk;

import quartz.math.approx : near;
import quartz.math.complex : Complex;
import std.math : PI, cos, sin;

// Coherent binary FSK with two complex tones. The demodulator correlates
// against both tones over one symbol and picks the larger energy. A silent
// channel returns the bits. The tones are an integer number of cycles per
// symbol so the correlators are orthogonal when the separation is 0.5 cycles.

@safe:

struct FskSpec {
    int sps = 16;
    double f0 = 0.05;
    double f1 = 0.15;
}

Complex!double[] fskModulate(const(bool)[] bits, FskSpec spec) {
    auto y = new Complex!double[](bits.length * spec.sps);
    foreach (i, bit; bits) {
        double freq = bit ? spec.f1 : spec.f0;
        foreach (n; 0 .. spec.sps) {
            double phase = 2.0 * PI * freq * n;
            y[i * spec.sps + n] = Complex!double(cos(phase), sin(phase));
        }
    }
    return y;
}

bool[] fskDemodulate(const(Complex!double)[] samples, FskSpec spec, int count) {
    bool[] bits = new bool[](count);
    foreach (i; 0 .. count) {
        Complex!double c0 = Complex!double(0, 0);
        Complex!double c1 = Complex!double(0, 0);
        foreach (n; 0 .. spec.sps) {
            size_t idx = i * spec.sps + n;
            if (idx >= samples.length) {
                break;
            }
            double p0 = 2.0 * PI * spec.f0 * n;
            double p1 = 2.0 * PI * spec.f1 * n;
            c0 = c0 + samples[idx] * Complex!double(cos(p0), -sin(p0));
            c1 = c1 + samples[idx] * Complex!double(cos(p1), -sin(p1));
        }
        bits[i] = c1.mag2() > c0.mag2();
    }
    return bits;
}

unittest {
    FskSpec spec;
    bool[] bits = [false, true, true, false, true, false, false, true];
    auto wave = fskModulate(bits, spec);
    assert(wave.length == bits.length * spec.sps);
    assert(fskDemodulate(wave, spec, cast(int) bits.length) == bits);
    double e0 = 0;
    foreach (n; 0 .. spec.sps) {
        e0 += wave[n].mag2();
    }
    assert(near(e0 / spec.sps, 1.0, 1e-9, 1e-9));
}
