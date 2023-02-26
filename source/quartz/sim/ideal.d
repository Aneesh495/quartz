module quartz.sim.ideal;

import quartz.channel.rng : Xoshiro256;
import quartz.math.complex : Complex;
import quartz.measure.theory : berBpsk, berBpskRayleigh, berQpsk, withinPoisson;
import quartz.units : noiseSigma;
import std.math : sqrt;

// One-sample-per-symbol modems. This is the path a theory table is allowed
// to grade. Pulse shaping and synchronization live elsewhere and are graded
// by noiseless recovery, not by an erfc formula.

@safe:

struct Trial {
    int bits;
    int bitErrors;
    int symbolErrors;
    double ebn0Db;

    double ber() const {
        if (bits <= 0) {
            return 0;
        }
        return cast(double) bitErrors / cast(double) bits;
    }
}

Trial simulateBpsk(ulong seed, int bits, double ebn0Db) {
    auto rng = Xoshiro256(seed);
    double sigma = noiseSigma(1.0, ebn0Db, 1.0, 1.0);
    Trial trial;
    trial.bits = bits;
    trial.ebn0Db = ebn0Db;
    foreach (_; 0 .. bits) {
        bool bit = rng.nextBool();
        double s = bit ? -1.0 : 1.0;
        double y = s + sigma * rng.nextGaussian();
        bool hat = y < 0;
        if (hat != bit) {
            trial.bitErrors++;
            trial.symbolErrors++;
        }
    }
    return trial;
}

Trial simulateQpsk(ulong seed, int bits, double ebn0Db) {
    // Two bits per symbol, Gray labeled. Symbol energy is 1, so each rail
    // carries half the energy and the noise formula uses bitsPerSymbol = 2.
    if ((bits % 2) != 0) {
        bits++;
    }
    auto rng = Xoshiro256(seed);
    double sigma = noiseSigma(1.0, ebn0Db, 2.0, 1.0);
    double scale = 1.0 / sqrt(2.0);
    Trial trial;
    trial.bits = bits;
    trial.ebn0Db = ebn0Db;
    foreach (_; 0 .. bits / 2) {
        bool b0 = rng.nextBool();
        bool b1 = rng.nextBool();
        double i = (b0 ? -scale : scale) + sigma * rng.nextGaussian();
        double q = (b1 ? -scale : scale) + sigma * rng.nextGaussian();
        bool h0 = i < 0;
        bool h1 = q < 0;
        if (h0 != b0) {
            trial.bitErrors++;
        }
        if (h1 != b1) {
            trial.bitErrors++;
        }
        if (h0 != b0 || h1 != b1) {
            trial.symbolErrors++;
        }
    }
    return trial;
}

Trial simulateBpskRayleigh(ulong seed, int bits, double ebn0Db) {
    auto rng = Xoshiro256(seed);
    double sigma = noiseSigma(1.0, ebn0Db, 1.0, 1.0);
    Trial trial;
    trial.bits = bits;
    trial.ebn0Db = ebn0Db;
    foreach (_; 0 .. bits) {
        bool bit = rng.nextBool();
        double s = bit ? -1.0 : 1.0;
        // One complex fade per symbol, unit second moment. Coherent detection
        // uses the known coefficient.
        Complex!double h = rng.nextComplexGaussian() * (1.0 / sqrt(2.0));
        Complex!double noise = Complex!double(sigma * rng.nextGaussian(), sigma * rng.nextGaussian());
        Complex!double y = h * s + noise;
        // Coherent metric: Re(y conj(h)). The instantaneous gain is |h|^2.
        double hatMetric = (y * h.conj()).re;
        bool hat = hatMetric < 0;
        if (hat != bit) {
            trial.bitErrors++;
        }
    }
    return trial;
}

unittest {
    auto clean = simulateBpsk(1, 2000, 40.0);
    assert(clean.bitErrors == 0);
    auto mid = simulateBpsk(3, 20000, 0.0);
    assert(withinPoisson(mid.bitErrors, mid.bits, berBpsk(0.0), 5.0));
    auto q = simulateQpsk(9, 20000, 0.0);
    assert(withinPoisson(q.bitErrors, q.bits, berQpsk(0.0), 5.0));
    auto again = simulateBpsk(3, 20000, 0.0);
    assert(again.bitErrors == mid.bitErrors);
    auto fade = simulateBpskRayleigh(4, 30000, 0.0);
    assert(withinPoisson(fade.bitErrors, fade.bits, berBpskRayleigh(0.0), 5.0));
    auto hi = simulateBpsk(8, 8000, 8.0);
    assert(hi.bitErrors < 20);
}
