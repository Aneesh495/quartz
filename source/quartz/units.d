module quartz.units;

import quartz.error : QuartzError;
import quartz.math.approx : near;
import quartz.math.rational : ClockRatio, Rational;
import std.math : log10, sqrt;

// Decibels, hertz, and the Eb/N0 conversion used by every noise source.
// Amplitude dB and power dB are different constructors so a link budget
// cannot silently add a voltage ratio to a power ratio.

@safe:

struct PowerDecibel {
    double db = 0;

    static PowerDecibel fromLinear(double power) {
        if (!(power > 0)) {
            throw new QuartzError("power decibel of a nonpositive value");
        }
        return PowerDecibel(10.0 * log10(power));
    }

    double linear() const {
        return 10.0 ^^ (db / 10.0);
    }
}

struct AmplitudeDecibel {
    double db = 0;

    static AmplitudeDecibel fromLinear(double amp) {
        if (!(amp > 0)) {
            throw new QuartzError("amplitude decibel of a nonpositive value");
        }
        return AmplitudeDecibel(20.0 * log10(amp));
    }

    double linear() const {
        return 10.0 ^^ (db / 20.0);
    }
}

struct Hertz {
    double hz = 0;

    this(double hz) {
        if (hz != hz) {
            throw new QuartzError("hertz is not a number");
        }
        this.hz = hz;
    }

    Hertz opBinary(string op)(Hertz rhs) const {
        static if (op == "+") {
            return Hertz(hz + rhs.hz);
        } else static if (op == "-") {
            return Hertz(hz - rhs.hz);
        } else {
            static assert(0);
        }
    }

    Hertz opBinary(string op)(double scale) const if (op == "*") {
        return Hertz(hz * scale);
    }
}

// Samples per second stored as a reduced rational when the rate is integral.
struct SampleClock {
    long numer = 1;
    long denom = 1;

    this(long samplesPerSecond) {
        if (samplesPerSecond <= 0) {
            throw new QuartzError("sample clock must be positive");
        }
        this.numer = samplesPerSecond;
        this.denom = 1;
    }

    this(Rational rate) {
        if (rate.num <= 0) {
            throw new QuartzError("sample clock must be positive");
        }
        this.numer = rate.num;
        this.denom = rate.den;
    }

    double toDouble() const {
        return cast(double) numer / cast(double) denom;
    }

    ClockRatio resampleTo(SampleClock other) const {
        // (out/in) = (other.numer/other.denom) / (numer/denom)
        // = (other.numer * denom) / (other.denom * numer)
        import quartz.math.rational : checkedMul, gcdLong;
        long up = checkedMul(other.numer, denom);
        long down = checkedMul(other.denom, numer);
        long g = gcdLong(up, down);
        return ClockRatio(up / g, down / g);
    }
}

double db10(double powerRatio) {
    return 10.0 * log10(powerRatio);
}

double undb10(double db) {
    return 10.0 ^^ (db / 10.0);
}

double db20(double ampRatio) {
    return 20.0 * log10(ampRatio);
}

double undb20(double db) {
    return 10.0 ^^ (db / 20.0);
}

// Noise standard deviation per real dimension of a complex baseband sample.
// symbolEnergy is E[|s|^2]. bitsPerSymbol counts bits mapped onto one symbol
// before coding. codeRate is k/n. The complex noise then has variance
// 2*sigma^2, which is N0 for a symbol interval of one sample.
double noiseSigma(double symbolEnergy, double ebn0Db, double bitsPerSymbol, double codeRate) {
    if (!(symbolEnergy > 0) || !(bitsPerSymbol > 0) || !(codeRate > 0)) {
        throw new QuartzError("noise calibration needs positive energy, bits, and rate");
    }
    double gamma = undb10(ebn0Db);
    double n0 = symbolEnergy / (bitsPerSymbol * codeRate * gamma);
    return sqrt(n0 / 2.0);
}

// Es/N0 in dB from Eb/N0. Es/N0 = Eb/N0 + 10 log10(bitsPerSymbol * codeRate).
double esN0Db(double ebn0Db, double bitsPerSymbol, double codeRate) {
    return ebn0Db + db10(bitsPerSymbol * codeRate);
}

double cyclesPerSample(double freqHz, double sampleRateHz) {
    if (!(sampleRateHz > 0)) {
        throw new QuartzError("sample rate must be positive");
    }
    return freqHz / sampleRateHz;
}

unittest {
    auto p = PowerDecibel.fromLinear(100.0);
    assert(near(p.db, 20.0, 1e-12, 1e-12));
    assert(near(p.linear(), 100.0, 1e-9, 1e-12));
    auto a = AmplitudeDecibel.fromLinear(10.0);
    assert(near(a.db, 20.0, 1e-12, 1e-12));
    assert(near(undb20(-6.0), 0.5011872336272722, 1e-12, 1e-12));
    Hertz f = Hertz(1000) + Hertz(250);
    assert(near(f.hz, 1250.0, 0.0, 0.0));
    auto clock = SampleClock(44100);
    auto other = SampleClock(48000);
    auto ratio = clock.resampleTo(other);
    assert(ratio.up == 160 && ratio.down == 147);
    double sigma = noiseSigma(1.0, 0.0, 1.0, 1.0);
    assert(near(sigma, sqrt(0.5), 1e-12, 1e-12));
    assert(near(esN0Db(0.0, 2.0, 0.5), 0.0, 1e-12, 1e-12));
    assert(near(cyclesPerSample(1200.0, 48000.0), 0.025, 1e-15, 0.0));
    bool threw = false;
    try {
        auto bad = noiseSigma(1.0, 0.0, 0.0, 1.0);
        assert(bad == 0);
    } catch (QuartzError) {
        threw = true;
    }
    assert(threw);
}
