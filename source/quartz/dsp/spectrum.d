module quartz.dsp.spectrum;

import quartz.dsp.fft : fftRadix2;
import quartz.dsp.window : hann;
import quartz.math.complex : Complex;
import quartz.math.special : isPow2;

// A single-segment periodogram. The peak bin of a pure tone sits on the
// frequency that was asked for, which is the check that the window and the
// FFT agree on what "bin k" means.

@safe:

double[] periodogram(const(double)[] samples) {
    size_t n = samples.length;
    if (!isPow2(n) || n == 0) {
        return [];
    }
    auto window = hann(cast(int) n);
    auto spec = new Complex!double[](n);
    foreach (i, x; samples) {
        spec[i] = Complex!double(x * window[i], 0);
    }
    fftRadix2(spec, false);
    double[] power = new double[](n);
    foreach (i, bin; spec) {
        power[i] = bin.mag2();
    }
    return power;
}

int peakBin(const(double)[] power) {
    int best = 0;
    double mag = -1;
    size_t limit = power.length / 2;
    foreach (i; 0 .. limit) {
        if (power[i] > mag) {
            mag = power[i];
            best = cast(int) i;
        }
    }
    return best;
}

unittest {
    import std.math : PI, cos;
    int n = 256;
    double cycles = 8;
    double[] tone = new double[](n);
    foreach (i; 0 .. n) {
        tone[i] = cos(2.0 * PI * cycles * i / n);
    }
    auto power = periodogram(tone);
    assert(peakBin(power) == cast(int) cycles);
}
