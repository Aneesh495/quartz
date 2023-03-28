module quartz.coding.soft;

import quartz.math.approx : near;
import quartz.units : noiseSigma;

// Bit LLRs for a real BPSK observation. Positive favors zero, matching the
// constellation soft demapper. The scale is 2y/sigma^2 for a symbol at plus
// or minus one.

@safe:

double bpskLlr(double observation, double sigma) {
    double v = sigma * sigma;
    if (v < 1e-18) {
        v = 1e-18;
    }
    return 2.0 * observation / v;
}

double[] hardToLlr(const(bool)[] bits, double magnitude) {
    double[] llr = new double[](bits.length);
    foreach (i, bit; bits) {
        llr[i] = bit ? -magnitude : magnitude;
    }
    return llr;
}

unittest {
    double sigma = noiseSigma(1.0, 0.0, 1.0, 1.0);
    double llr = bpskLlr(1.0, sigma);
    assert(llr > 0);
    assert(near(llr, 2.0 / (sigma * sigma), 1e-9, 1e-9));
    assert(bpskLlr(-1.0, sigma) < 0);
    auto mapped = hardToLlr([false, true], 8);
    assert(mapped[0] == 8 && mapped[1] == -8);
}
