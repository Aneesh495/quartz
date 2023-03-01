module quartz.modem.ofdm;

import quartz.dsp.fft : fftRadix2;
import quartz.math.complex : Complex, nearC;
import quartz.math.special : isPow2;
import quartz.error : QuartzError;

// One OFDM symbol: data on selected bins, a cyclic prefix, and an FFT pair
// that uses the unnormalized forward transform at the receiver. The inverse
// transform already divides by n, so a clean loopback returns the bins.

@safe:

struct OfdmSpec {
    int nfft;
    int cp;
    int[] dataBins;

    int dataCount() const {
        return cast(int) dataBins.length;
    }
}

int binIndex(int nfft, int carrier) {
    int i = carrier % nfft;
    if (i < 0) {
        i += nfft;
    }
    return i;
}

OfdmSpec ofdmWifiLike() {
    // A 64-point symbol with the 802.11a occupied tones: 52 data plus 4
    // pilots would be the full map. This preset keeps every occupied tone
    // as data so a loopback does not need a pilot equalizer.
    OfdmSpec spec;
    spec.nfft = 64;
    spec.cp = 16;
    foreach (k; -26 .. 0) {
        spec.dataBins ~= binIndex(64, k);
    }
    foreach (k; 1 .. 27) {
        spec.dataBins ~= binIndex(64, k);
    }
    return spec;
}

OfdmSpec ofdmSimple(int nfft, int cp) {
    if (!isPow2(nfft) || cp < 0 || cp >= nfft) {
        throw new QuartzError("OFDM size is not usable");
    }
    OfdmSpec spec;
    spec.nfft = nfft;
    spec.cp = cp;
    foreach (k; 1 .. nfft) {
        if (k == nfft / 2) {
            continue;
        }
        spec.dataBins ~= k;
    }
    return spec;
}

Complex!double[] ofdmModulate(OfdmSpec spec, const(Complex!double)[] symbols) {
    if (symbols.length != spec.dataBins.length) {
        throw new QuartzError("OFDM symbol count does not match the data bins");
    }
    auto freq = new Complex!double[](spec.nfft);
    foreach (ref bin; freq) {
        bin = Complex!double(0, 0);
    }
    foreach (i, sym; symbols) {
        freq[spec.dataBins[i]] = sym;
    }
    fftRadix2(freq, true);
    auto frame = new Complex!double[](spec.cp + spec.nfft);
    foreach (i; 0 .. spec.cp) {
        frame[i] = freq[spec.nfft - spec.cp + i];
    }
    foreach (i; 0 .. spec.nfft) {
        frame[spec.cp + i] = freq[i];
    }
    return frame;
}

Complex!double[] ofdmDemodulate(OfdmSpec spec, const(Complex!double)[] frame) {
    if (frame.length < spec.cp + spec.nfft) {
        throw new QuartzError("OFDM frame is short");
    }
    auto block = new Complex!double[](spec.nfft);
    foreach (i; 0 .. spec.nfft) {
        block[i] = frame[spec.cp + i];
    }
    fftRadix2(block, false);
    auto symbols = new Complex!double[](spec.dataBins.length);
    foreach (i, bin; spec.dataBins) {
        symbols[i] = block[bin];
    }
    return symbols;
}

Complex!double[] ofdmThroughChannel(OfdmSpec spec, const(Complex!double)[] frame, Complex!double gain) {
    // A one-tap channel. The prefix keeps the circular convolution equal to
    // a multiply per bin when the delay spread fits in the prefix. A flat
    // gain is the degenerate case and scales every bin.
    auto y = new Complex!double[](frame.length);
    foreach (i, s; frame) {
        y[i] = s * gain;
    }
    return y;
}

unittest {
    auto spec = ofdmSimple(32, 8);
    auto symbols = new Complex!double[](spec.dataCount());
    foreach (i; 0 .. symbols.length) {
        symbols[i] = Complex!double((i % 5) - 2.0, (i % 3) - 1.0);
    }
    auto frame = ofdmModulate(spec, symbols);
    assert(frame.length == 40);
    auto back = ofdmDemodulate(spec, frame);
    foreach (i; 0 .. symbols.length) {
        assert(nearC(back[i], symbols[i], 1e-8, 1e-8));
    }
    auto wifi = ofdmWifiLike();
    assert(wifi.dataCount() == 52);
    auto tones = new Complex!double[](wifi.dataCount());
    foreach (i; 0 .. tones.length) {
        tones[i] = Complex!double(i % 2 == 0 ? 1 : -1, i % 3 == 0 ? 0.5 : -0.5);
    }
    auto wframe = ofdmModulate(wifi, tones);
    auto scaled = ofdmThroughChannel(wifi, wframe, Complex!double(0.5, -0.25));
    auto received = ofdmDemodulate(wifi, scaled);
    foreach (i; 0 .. tones.length) {
        assert(nearC(received[i], tones[i] * Complex!double(0.5, -0.25), 1e-8, 1e-8));
    }
}
