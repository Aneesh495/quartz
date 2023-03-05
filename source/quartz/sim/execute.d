module quartz.sim.execute;

import quartz.channel.rng : Xoshiro256;
import quartz.coding.convolutional : convEncode, convNasa;
import quartz.coding.golay : golayDecode, golayEncode;
import quartz.coding.hamming : HammingCode, hammingDecode, hammingEncode;
import quartz.coding.polar : frozenMask, llrFromCoded, polarDecode, polarEncode;
import quartz.coding.repetition : repetitionDecode, repetitionEncode;
import quartz.coding.viterbi : bipolarFromBits, viterbiDecode;
import quartz.dsp.design : rrcTaps;
import quartz.dsp.nco : Nco;
import quartz.math.complex : Complex;
import quartz.modem.constellation : Constellation, bpsk, psk, qam16, qam64, qpsk;
import quartz.modem.ofdm : OfdmSpec, ofdmDemodulate, ofdmModulate, ofdmSimple, ofdmWifiLike;
import quartz.modem.pulse : demodulate, modulate;
import quartz.sim.plan : ChannelKind, CodeKind, ExperimentPlan, ModemKind, PulseKind, bitsPerSymbol;
import quartz.units : noiseSigma;
import std.math : sqrt;

// One execution of a plan. Rectangular pulses are judged in the symbol
// domain, where Eb/N0 has the textbook meaning. Raised-cosine and OFDM are
// waveform paths: a silent channel must return the payload, and noise is
// added on the samples the modem actually transmits.

@safe:

struct SimReport {
    int infoBits;
    int bitErrors;
    int codedBits;
    string name;

    double ber() const {
        if (infoBits <= 0) {
            return 0;
        }
        return cast(double) bitErrors / cast(double) infoBits;
    }
}

SimReport execute(ExperimentPlan plan) {
    auto rng = Xoshiro256(plan.seed);
    bool[] info = drawBits(rng, plan.bits);
    bool[] coded = encodePlan(plan, info);
    bool[] received;
    if (plan.channel == ChannelKind.bsc) {
        received = coded.dup;
        foreach (ref bit; received) {
            if (rng.nextDouble() < plan.crossover) {
                bit = !bit;
            }
        }
    } else if (plan.pulse == PulseKind.rrc && plan.sps > 1 && plan.modem != ModemKind.ofdmQpsk) {
        received = throughPulse(plan, coded, rng);
    } else if (plan.modem == ModemKind.ofdmQpsk) {
        received = throughOfdm(plan, coded, rng);
    } else {
        received = throughSymbols(plan, coded, rng);
    }
    bool[] decoded = decodePlan(plan, received, cast(int) info.length);
    SimReport report;
    report.name = plan.name;
    report.infoBits = cast(int) info.length;
    report.codedBits = cast(int) coded.length;
    int n = cast(int) info.length;
    if (cast(int) decoded.length < n) {
        n = cast(int) decoded.length;
        report.bitErrors += cast(int) info.length - n;
    }
    foreach (i; 0 .. n) {
        if (decoded[i] != info[i]) {
            report.bitErrors++;
        }
    }
    return report;
}

bool[] drawBits(ref Xoshiro256 rng, int n) {
    bool[] bits = new bool[](n);
    foreach (i; 0 .. n) {
        bits[i] = rng.nextBool();
    }
    return bits;
}

double nominalRate(ExperimentPlan plan) {
    final switch (plan.code) {
    case CodeKind.none:
        return 1;
    case CodeKind.repetition:
        return 1.0 / plan.repeat;
    case CodeKind.hamming74:
        return 4.0 / 7.0;
    case CodeKind.hamming1511:
        return 11.0 / 15.0;
    case CodeKind.conv12:
        return 0.5;
    case CodeKind.golay23:
        return 12.0 / 23.0;
    case CodeKind.polar:
        return 0.5;
    }
}

bool[] encodePlan(ExperimentPlan plan, const(bool)[] info) {
    final switch (plan.code) {
    case CodeKind.none:
        return info.dup;
    case CodeKind.repetition:
        return repetitionEncode(info, plan.repeat);
    case CodeKind.hamming74:
        return encodeHamming(info, HammingCode.binary(3));
    case CodeKind.hamming1511:
        return encodeHamming(info, HammingCode.binary(4));
    case CodeKind.conv12:
        return convEncode(convNasa(), info, true);
    case CodeKind.golay23:
        return encodeGolay(info);
    case CodeKind.polar:
        return encodePolar(info);
    }
}

bool[] decodePlan(ExperimentPlan plan, const(bool)[] coded, int infoBits) {
    final switch (plan.code) {
    case CodeKind.none:
        return coded.dup;
    case CodeKind.repetition:
        if (coded.length % plan.repeat != 0) {
            return [];
        }
        return repetitionDecode(coded, plan.repeat);
    case CodeKind.hamming74:
        return decodeHamming(coded, HammingCode.binary(3));
    case CodeKind.hamming1511:
        return decodeHamming(coded, HammingCode.binary(4));
    case CodeKind.conv12:
        auto soft = bipolarFromBits(coded);
        return viterbiDecode(convNasa(), soft, infoBits, true);
    case CodeKind.golay23:
        return decodeGolay(coded);
    case CodeKind.polar:
        return decodePolar(coded);
    }
}

bool[] encodeHamming(const(bool)[] info, HammingCode code) {
    bool[] padded = info.dup;
    while (padded.length % code.k != 0) {
        padded ~= false;
    }
    bool[] coded;
    for (size_t i = 0; i < padded.length; i += code.k) {
        coded ~= hammingEncode(code, padded[i .. i + code.k]);
    }
    return coded;
}

bool[] decodeHamming(const(bool)[] coded, HammingCode code) {
    bool[] info;
    for (size_t i = 0; i + code.n <= coded.length; i += code.n) {
        info ~= hammingDecode(code, coded[i .. i + code.n]).data;
    }
    return info;
}

bool[] encodeGolay(const(bool)[] info) {
    bool[] padded = info.dup;
    while (padded.length % 12 != 0) {
        padded ~= false;
    }
    bool[] coded;
    for (size_t i = 0; i < padded.length; i += 12) {
        int msg = bitsToInt(padded[i .. i + 12]);
        coded ~= intToBits(golayEncode(msg), 23);
    }
    return coded;
}

bool[] decodeGolay(const(bool)[] coded) {
    bool[] info;
    for (size_t i = 0; i + 23 <= coded.length; i += 23) {
        int word = bitsToInt(coded[i .. i + 23]);
        int fixed = golayDecode(word);
        info ~= intToBits((fixed >> 11) & 0xfff, 12);
    }
    return info;
}

bool[] encodePolar(const(bool)[] info) {
    auto frozen = frozenMask(32, 16, 0.5);
    bool[] padded = info.dup;
    while (padded.length % 16 != 0) {
        padded ~= false;
    }
    bool[] coded;
    for (size_t i = 0; i < padded.length; i += 16) {
        coded ~= polarEncode(padded[i .. i + 16], frozen);
    }
    return coded;
}

bool[] decodePolar(const(bool)[] coded) {
    auto frozen = frozenMask(32, 16, 0.5);
    bool[] info;
    for (size_t i = 0; i + 32 <= coded.length; i += 32) {
        auto llr = llrFromCoded(coded[i .. i + 32], 12.0);
        info ~= polarDecode(llr, frozen);
    }
    return info;
}

int bitsToInt(const(bool)[] bits) {
    int v = 0;
    foreach (bit; bits) {
        v = (v << 1) | (bit ? 1 : 0);
    }
    return v;
}

bool[] intToBits(int value, int width) {
    bool[] bits = new bool[](width);
    foreach (i; 0 .. width) {
        bits[i] = ((value >> (width - 1 - i)) & 1) != 0;
    }
    return bits;
}

Constellation constellationFor(ModemKind kind) {
    final switch (kind) {
    case ModemKind.bpsk:
        return bpsk();
    case ModemKind.qpsk:
    case ModemKind.ofdmQpsk:
    case ModemKind.bfsk:
        return qpsk();
    case ModemKind.psk8:
        return psk(3);
    case ModemKind.qam16:
        return qam16();
    case ModemKind.qam64:
        return qam64();
    }
}

uint[] labelsFromBits(const(bool)[] bits, int bps) {
    int count = cast(int) ((bits.length + bps - 1) / bps);
    uint[] labels = new uint[](count);
    foreach (s; 0 .. count) {
        uint label = 0;
        foreach (b; 0 .. bps) {
            size_t i = s * bps + b;
            bool bit = i < bits.length && bits[i];
            label = (label << 1) | (bit ? 1 : 0);
        }
        labels[s] = label;
    }
    return labels;
}

bool[] bitsFromLabels(const(uint)[] labels, int bps, int bitCount) {
    bool[] bits;
    foreach (label; labels) {
        foreach_reverse (b; 0 .. bps) {
            if (bits.length == bitCount) {
                return bits;
            }
            bits ~= ((label >> b) & 1) != 0;
        }
    }
    return bits;
}

bool[] throughSymbols(ExperimentPlan plan, const(bool)[] coded, ref Xoshiro256 rng) {
    auto cons = constellationFor(plan.modem);
    int bps = cons.bitsPerSymbol;
    auto labels = labelsFromBits(coded, bps);
    double sigma = 0;
    if (plan.channel == ChannelKind.awgn || plan.channel == ChannelKind.rayleigh) {
        sigma = noiseSigma(1.0, plan.ebn0Db, bps, nominalRate(plan));
    }
    uint[] got = new uint[](labels.length);
    foreach (i, label; labels) {
        Complex!double s = cons.map(label);
        Complex!double y = s;
        if (plan.channel == ChannelKind.rayleigh) {
            Complex!double h = rng.nextComplexGaussian() * (1.0 / sqrt(2.0));
            Complex!double n = Complex!double(sigma * rng.nextGaussian(), sigma * rng.nextGaussian());
            y = h * s + n;
            double g = h.mag2();
            if (g > 1e-12) {
                y = y * h.conj() * (1.0 / g);
            }
        } else if (sigma > 0) {
            y = s + Complex!double(sigma * rng.nextGaussian(), sigma * rng.nextGaussian());
        }
        double d2;
        got[i] = cons.demap(y, d2);
    }
    return bitsFromLabels(got, bps, cast(int) coded.length);
}

bool[] throughPulse(ExperimentPlan plan, const(bool)[] coded, ref Xoshiro256 rng) {
    auto cons = constellationFor(plan.modem);
    int bps = cons.bitsPerSymbol;
    auto labels = labelsFromBits(coded, bps);
    auto taps = rrcTaps(plan.sps, plan.span, plan.beta);
    auto burst = modulate(cons, labels, taps, plan.sps);
    if (plan.cfoHz != 0 && plan.sampleRate > 0) {
        auto osc = Nco(plan.cfoHz / plan.sampleRate, 0);
        foreach (ref s; burst.samples) {
            s = s * osc.next();
        }
    }
    if (plan.channel == ChannelKind.awgn) {
        double sigma = noiseSigma(1.0, plan.ebn0Db, bps, nominalRate(plan));
        foreach (ref s; burst.samples) {
            s = s + Complex!double(sigma * rng.nextGaussian(), sigma * rng.nextGaussian());
        }
    }
    auto got = demodulate(cons, burst.samples, taps, plan.sps, cast(int) labels.length);
    return bitsFromLabels(got, bps, cast(int) coded.length);
}

bool[] throughOfdm(ExperimentPlan plan, const(bool)[] coded, ref Xoshiro256 rng) {
    auto cons = qpsk();
    auto labels = labelsFromBits(coded, 2);
    OfdmSpec spec = plan.ofdmNfft == 64 && plan.ofdmCp == 16 ? ofdmWifiLike() : ofdmSimple(plan.ofdmNfft, plan.ofdmCp);
    int per = spec.dataCount();
    if (per <= 0) {
        return [];
    }
    uint[] got;
    for (size_t i = 0; i < labels.length; i += per) {
        auto chunk = new Complex!double[](per);
        foreach (k; 0 .. per) {
            size_t idx = i + k;
            uint label = idx < labels.length ? labels[idx] : 0;
            chunk[k] = cons.map(label);
        }
        auto frame = ofdmModulate(spec, chunk);
        if (plan.channel == ChannelKind.awgn) {
            double sigma = noiseSigma(1.0, plan.ebn0Db, 2, nominalRate(plan));
            foreach (ref s; frame) {
                s = s + Complex!double(sigma * rng.nextGaussian(), sigma * rng.nextGaussian());
            }
        }
        auto back = ofdmDemodulate(spec, frame);
        foreach (sym; back) {
            double d2;
            got ~= cons.demap(sym, d2);
        }
    }
    return bitsFromLabels(got, 2, cast(int) coded.length);
}

unittest {
    import quartz.lang.sema : lowerSource;
    import quartz.measure.theory : berBpsk, withinPoisson;
    auto clean = lowerSource(`
        experiment clean {
          seed = 3;
          bits = 512;
          ebn0_db = 40;
          modem bpsk { sps = 1; pulse = rect; }
          code none;
          channel awgn;
        }
    `);
    auto report = execute(clean);
    assert(report.bitErrors == 0);
    ExperimentPlan noisy = clean;
    noisy.bits = 16000;
    noisy.ebn0Db = 0;
    noisy.seed = 11;
    auto mid = execute(noisy);
    assert(withinPoisson(mid.bitErrors, mid.infoBits, berBpsk(0.0), 6.0));
    auto shaped = lowerSource(`
        experiment shaped {
          seed = 1;
          bits = 80;
          modem qpsk { sps = 4; pulse = rrc; beta = 0.3; span = 8; }
          code none;
          channel none;
        }
    `);
    assert(execute(shaped).bitErrors == 0);
    auto ham = lowerSource(`
        experiment ham {
          seed = 2;
          bits = 64;
          modem bpsk { sps = 1; pulse = rect; }
          code hamming74;
          channel none;
        }
    `);
    assert(execute(ham).bitErrors == 0);
    auto of = lowerSource(`
        experiment ofdm {
          seed = 5;
          bits = 200;
          modem ofdm_qpsk;
          code none;
          channel none;
        }
    `);
    assert(execute(of).bitErrors == 0);
}
