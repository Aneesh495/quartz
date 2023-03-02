module quartz.sim.plan;

import quartz.error : QuartzError;

// The lowered form of an experiment. The language fills one of these, the
// scheduler runs it, and the receipt hashes the canonical text. Fields have
// defaults so a short file is still a complete trial.

@safe:

enum ModemKind {
    bpsk,
    qpsk,
    psk8,
    qam16,
    qam64,
    ofdmQpsk,
    bfsk
}

enum PulseKind {
    rect,
    rrc
}

enum CodeKind {
    none,
    repetition,
    hamming74,
    hamming1511,
    conv12,
    golay23,
    polar
}

enum ChannelKind {
    none,
    awgn,
    rayleigh,
    bsc
}

struct ExperimentPlan {
    string name = "trial";
    ulong seed = 1;
    int bits = 4096;
    double ebn0Db = 8;
    double sampleRate = 48_000;
    ModemKind modem = ModemKind.bpsk;
    int sps = 1;
    PulseKind pulse = PulseKind.rect;
    double beta = 0.35;
    int span = 8;
    CodeKind code = CodeKind.none;
    int repeat = 3;
    ChannelKind channel = ChannelKind.awgn;
    double crossover = 0.01;
    double cfoHz = 0;
    int ofdmNfft = 64;
    int ofdmCp = 16;

    string canonical() const {
        import std.conv : to;
        return "name=" ~ name ~ "\n"
            ~ "seed=" ~ to!string(seed) ~ "\n"
            ~ "bits=" ~ to!string(bits) ~ "\n"
            ~ "ebn0_db=" ~ to!string(ebn0Db) ~ "\n"
            ~ "rate_hz=" ~ to!string(sampleRate) ~ "\n"
            ~ "modem=" ~ modemName(modem) ~ "\n"
            ~ "sps=" ~ to!string(sps) ~ "\n"
            ~ "pulse=" ~ pulseName(pulse) ~ "\n"
            ~ "beta=" ~ to!string(beta) ~ "\n"
            ~ "span=" ~ to!string(span) ~ "\n"
            ~ "code=" ~ codeName(code) ~ "\n"
            ~ "repeat=" ~ to!string(repeat) ~ "\n"
            ~ "channel=" ~ channelName(channel) ~ "\n"
            ~ "crossover=" ~ to!string(crossover) ~ "\n"
            ~ "cfo_hz=" ~ to!string(cfoHz) ~ "\n"
            ~ "ofdm_nfft=" ~ to!string(ofdmNfft) ~ "\n"
            ~ "ofdm_cp=" ~ to!string(ofdmCp) ~ "\n";
    }
}

string modemName(ModemKind kind) {
    final switch (kind) {
    case ModemKind.bpsk:
        return "bpsk";
    case ModemKind.qpsk:
        return "qpsk";
    case ModemKind.psk8:
        return "psk8";
    case ModemKind.qam16:
        return "qam16";
    case ModemKind.qam64:
        return "qam64";
    case ModemKind.ofdmQpsk:
        return "ofdm_qpsk";
    case ModemKind.bfsk:
        return "bfsk";
    }
}

string pulseName(PulseKind kind) {
    final switch (kind) {
    case PulseKind.rect:
        return "rect";
    case PulseKind.rrc:
        return "rrc";
    }
}

string codeName(CodeKind kind) {
    final switch (kind) {
    case CodeKind.none:
        return "none";
    case CodeKind.repetition:
        return "repetition";
    case CodeKind.hamming74:
        return "hamming74";
    case CodeKind.hamming1511:
        return "hamming1511";
    case CodeKind.conv12:
        return "conv12";
    case CodeKind.golay23:
        return "golay23";
    case CodeKind.polar:
        return "polar";
    }
}

string channelName(ChannelKind kind) {
    final switch (kind) {
    case ChannelKind.none:
        return "none";
    case ChannelKind.awgn:
        return "awgn";
    case ChannelKind.rayleigh:
        return "rayleigh";
    case ChannelKind.bsc:
        return "bsc";
    }
}

ModemKind parseModem(string name) {
    switch (name) {
    case "bpsk":
        return ModemKind.bpsk;
    case "qpsk":
        return ModemKind.qpsk;
    case "psk8":
        return ModemKind.psk8;
    case "qam16":
        return ModemKind.qam16;
    case "qam64":
        return ModemKind.qam64;
    case "ofdm_qpsk":
        return ModemKind.ofdmQpsk;
    case "bfsk":
        return ModemKind.bfsk;
    default:
        throw new QuartzError("unknown modem " ~ name);
    }
}

PulseKind parsePulse(string name) {
    switch (name) {
    case "rect":
        return PulseKind.rect;
    case "rrc":
        return PulseKind.rrc;
    default:
        throw new QuartzError("unknown pulse " ~ name);
    }
}

CodeKind parseCode(string name) {
    switch (name) {
    case "none":
        return CodeKind.none;
    case "repetition":
        return CodeKind.repetition;
    case "hamming74":
        return CodeKind.hamming74;
    case "hamming1511":
        return CodeKind.hamming1511;
    case "conv12":
        return CodeKind.conv12;
    case "golay23":
        return CodeKind.golay23;
    case "polar":
        return CodeKind.polar;
    default:
        throw new QuartzError("unknown code " ~ name);
    }
}

ChannelKind parseChannel(string name) {
    switch (name) {
    case "none":
        return ChannelKind.none;
    case "awgn":
        return ChannelKind.awgn;
    case "rayleigh":
        return ChannelKind.rayleigh;
    case "bsc":
        return ChannelKind.bsc;
    default:
        throw new QuartzError("unknown channel " ~ name);
    }
}

int bitsPerSymbol(ModemKind kind) {
    final switch (kind) {
    case ModemKind.bpsk:
        return 1;
    case ModemKind.qpsk:
    case ModemKind.ofdmQpsk:
    case ModemKind.bfsk:
        return 2;
    case ModemKind.psk8:
        return 3;
    case ModemKind.qam16:
        return 4;
    case ModemKind.qam64:
        return 6;
    }
}

unittest {
    ExperimentPlan plan;
    assert(plan.canonical().length > 0);
    assert(parseModem("qpsk") == ModemKind.qpsk);
    assert(parseCode("hamming74") == CodeKind.hamming74);
    assert(bitsPerSymbol(ModemKind.qam16) == 4);
    auto again = plan;
    again.seed = 2;
    assert(again.canonical() != plan.canonical());
}
