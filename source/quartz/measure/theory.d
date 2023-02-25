module quartz.measure.theory;

import quartz.math.approx : near;
import quartz.units : undb10;
import std.math : PI, exp, log, sqrt;
import std.mathspecial : erfc;

// Textbook error rates the ideal simulator is allowed to be judged against.
// These are functions of linear Eb/N0. Pulse shaping, timing error, and
// implementation loss are not folded in. A waveform experiment that claims
// the textbook curve has to use one sample per symbol and a rectangular pulse.

@safe:

double qfunc(double x) {
    return 0.5 * erfc(x / sqrt(2.0));
}

double berBpsk(double ebn0Db) {
    double g = undb10(ebn0Db);
    return 0.5 * erfc(sqrt(g));
}

double berQpsk(double ebn0Db) {
    // Gray-labeled QPSK has the same bit error rate as BPSK.
    return berBpsk(ebn0Db);
}

double berBfskCoherent(double ebn0Db) {
    double g = undb10(ebn0Db);
    return qfunc(sqrt(g));
}

double berQam16(double ebn0Db) {
    // Gray 16-QAM bit error rate:
    // Pb = (3/8) erfc(sqrt((2/5) Eb/N0)).
    double g = undb10(ebn0Db);
    return 0.375 * erfc(sqrt(0.4 * g));
}

double berBpskRayleigh(double ebn0Db) {
    double g = undb10(ebn0Db);
    return 0.5 * (1.0 - sqrt(g / (1.0 + g)));
}

double awgnCapacity(double snrLinear) {
    if (snrLinear < 0) {
        snrLinear = 0;
    }
    return log(1.0 + snrLinear) / log(2.0);
}

double ebn0FromCapacity(double rateBitsPerSymbol) {
    // Complex-baseband SNR that supports `rate` bits per symbol, converted
    // to Eb/N0: SNR = 2^R - 1, Eb/N0 = SNR / R.
    if (rateBitsPerSymbol <= 0) {
        return 0;
    }
    double snr = (2.0 ^^ rateBitsPerSymbol) - 1.0;
    return snr / rateBitsPerSymbol;
}

bool withinPoisson(int errors, int trials, double probability, double sigmas) {
    if (trials <= 0) {
        return false;
    }
    double mean = probability * trials;
    double var = mean * (1.0 - probability);
    double sd = sqrt(var < 0 ? 0 : var);
    double d = errors - mean;
    if (d < 0) {
        d = -d;
    }
    return d <= sigmas * sd + 1.0;
}

unittest {
    assert(near(berBpsk(0.0), 0.07864960352514257, 1e-12, 1e-12));
    assert(near(berQpsk(0.0), berBpsk(0.0), 0.0, 0.0));
    assert(near(berBpskRayleigh(0.0), 0.1464466094067262, 1e-12, 1e-12));
    assert(berBpsk(8.0) < berBpsk(4.0));
    assert(berBpsk(8.0) < 3e-4);
    assert(near(berBfskCoherent(0.0), qfunc(1.0), 1e-12, 1e-12));
    assert(near(awgnCapacity(1.0), 1.0, 1e-12, 1e-12));
    assert(near(awgnCapacity(0.0), 0.0, 1e-15, 0.0));
    double minEbn0 = ebn0FromCapacity(1.0);
    assert(near(minEbn0, 1.0, 1e-12, 1e-12));
    assert(withinPoisson(1573, 20000, berBpsk(0.0), 4.0));
    assert(!withinPoisson(0, 20000, berBpsk(0.0), 4.0));
    assert(berQam16(10.0) < berQam16(4.0));
    assert(near(PI / PI, 1.0, 1e-15, 0.0));
}
