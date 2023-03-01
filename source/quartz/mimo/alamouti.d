module quartz.mimo.alamouti;

import quartz.math.complex : Complex, nearC;
import quartz.channel.rng : Xoshiro256;

// Alamouti's two-transmit orthogonal design. Over two symbol periods the
// receiver sees a channel that collapses to a real scale |h1|^2 + |h2|^2
// after the combiner, which is what the noiseless test locks down.

@safe:

struct AlamoutiPair {
    Complex!double s0;
    Complex!double s1;
}

struct AlamoutiTx {
    Complex!double ant1t0;
    Complex!double ant2t0;
    Complex!double ant1t1;
    Complex!double ant2t1;
}

AlamoutiTx alamoutiSend(AlamoutiPair pair) {
    AlamoutiTx tx;
    tx.ant1t0 = pair.s0;
    tx.ant2t0 = pair.s1;
    tx.ant1t1 = -pair.s1.conj();
    tx.ant2t1 = pair.s0.conj();
    return tx;
}

AlamoutiPair alamoutiCombine(Complex!double h1, Complex!double h2, Complex!double y0, Complex!double y1) {
    AlamoutiPair hat;
    hat.s0 = h1.conj() * y0 + h2 * y1.conj();
    hat.s1 = h2.conj() * y0 - h1 * y1.conj();
    return hat;
}

Complex!double alamoutiScale(Complex!double h1, Complex!double h2) {
    double g = h1.mag2() + h2.mag2();
    return Complex!double(g, 0);
}

unittest {
    auto rng = Xoshiro256(19);
    foreach (trial; 0 .. 20) {
        Complex!double h1 = rng.nextComplexGaussian();
        Complex!double h2 = rng.nextComplexGaussian();
        AlamoutiPair pair;
        pair.s0 = Complex!double(rng.nextDouble() * 2 - 1, rng.nextDouble() * 2 - 1);
        pair.s1 = Complex!double(rng.nextDouble() * 2 - 1, rng.nextDouble() * 2 - 1);
        auto tx = alamoutiSend(pair);
        Complex!double y0 = h1 * tx.ant1t0 + h2 * tx.ant2t0;
        Complex!double y1 = h1 * tx.ant1t1 + h2 * tx.ant2t1;
        auto hat = alamoutiCombine(h1, h2, y0, y1);
        auto scale = alamoutiScale(h1, h2);
        assert(nearC(hat.s0, pair.s0 * scale, 1e-8, 1e-8));
        assert(nearC(hat.s1, pair.s1 * scale, 1e-8, 1e-8));
    }
}
