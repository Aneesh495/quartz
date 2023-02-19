module quartz.coding.bcjr;

import quartz.coding.convolutional : ConvSpec, convEncode, convExample;
import quartz.coding.viterbi : bipolarFromBits, viterbiDecode;
import quartz.error : QuartzError;
import std.math : exp;

// Probability-domain BCJR for a rate 1/n feedforward code. Alpha and beta are
// normalized at every step so a long block does not underflow. The hard
// decision is compared with Viterbi on the same observations.

@safe:

private int stepState(int state, int bit, int memory) {
    int nstate = 1 << memory;
    return bit | ((state << 1) & (nstate - 1));
}

private bool branchBit(ConvSpec spec, int state, int bit, int polyIndex) {
    int mem = spec.memory();
    uint poly = spec.polys[polyIndex];
    bool y = false;
    if ((poly & 1u) != 0 && bit == 1) {
        y = !y;
    }
    foreach (i; 0 .. mem) {
        bool tap = ((state >> i) & 1) != 0;
        if (((poly >> (i + 1)) & 1u) != 0 && tap) {
            y = !y;
        }
    }
    return y;
}

double[] bcjrLlr(ConvSpec spec, const(double)[] p0, int infoBits, bool terminated) {
    int mem = spec.memory();
    int nstate = 1 << mem;
    int nout = spec.outputs();
    int steps = infoBits + (terminated ? mem : 0);
    if (p0.length < steps * nout) {
        throw new QuartzError("BCJR observation is short");
    }
    double[][] alpha = new double[][](steps + 1, nstate);
    double[][] beta = new double[][](steps + 1, nstate);
    foreach (ref row; alpha) {
        row[] = 0;
    }
    foreach (ref row; beta) {
        row[] = 0;
    }
    alpha[0][0] = 1;
    foreach (t; 0 .. steps) {
        bool allowInput = !terminated || t < infoBits;
        foreach (state; 0 .. nstate) {
            if (alpha[t][state] == 0) {
                continue;
            }
            foreach (bit; 0 .. 2) {
                if (!allowInput && bit != 0) {
                    continue;
                }
                int nxt = stepState(state, bit, mem);
                double gamma = 0.5;
                foreach (p; 0 .. nout) {
                    bool y = branchBit(spec, state, bit, p);
                    double prob0 = p0[t * nout + p];
                    gamma *= y ? (1.0 - prob0) : prob0;
                }
                alpha[t + 1][nxt] += alpha[t][state] * gamma;
            }
        }
        double sum = 0;
        foreach (s; 0 .. nstate) {
            sum += alpha[t + 1][s];
        }
        if (sum > 0) {
            foreach (s; 0 .. nstate) {
                alpha[t + 1][s] /= sum;
            }
        }
    }
    if (terminated) {
        beta[steps][0] = 1;
    } else {
        beta[steps][] = 1.0 / nstate;
    }
    for (int t = steps - 1; t >= 0; t--) {
        bool allowInput = !terminated || t < infoBits;
        foreach (state; 0 .. nstate) {
            foreach (bit; 0 .. 2) {
                if (!allowInput && bit != 0) {
                    continue;
                }
                int nxt = stepState(state, bit, mem);
                double gamma = 0.5;
                foreach (p; 0 .. nout) {
                    bool y = branchBit(spec, state, bit, p);
                    double prob0 = p0[t * nout + p];
                    gamma *= y ? (1.0 - prob0) : prob0;
                }
                beta[t][state] += gamma * beta[t + 1][nxt];
            }
        }
        double sum = 0;
        foreach (s; 0 .. nstate) {
            sum += beta[t][s];
        }
        if (sum > 0) {
            foreach (s; 0 .. nstate) {
                beta[t][s] /= sum;
            }
        }
    }
    double[] llr = new double[](infoBits);
    foreach (t; 0 .. infoBits) {
        double pBit0 = 0;
        double pBit1 = 0;
        foreach (state; 0 .. nstate) {
            foreach (bit; 0 .. 2) {
                int nxt = stepState(state, bit, mem);
                double gamma = 0.5;
                foreach (p; 0 .. nout) {
                    bool y = branchBit(spec, state, bit, p);
                    double prob0 = p0[t * nout + p];
                    gamma *= y ? (1.0 - prob0) : prob0;
                }
                double post = alpha[t][state] * gamma * beta[t + 1][nxt];
                if (bit == 0) {
                    pBit0 += post;
                } else {
                    pBit1 += post;
                }
            }
        }
        if (pBit0 < 1e-300) {
            pBit0 = 1e-300;
        }
        if (pBit1 < 1e-300) {
            pBit1 = 1e-300;
        }
        llr[t] = logRatio(pBit0, pBit1);
    }
    return llr;
}

private double logRatio(double a, double b) {
    import std.math : log;
    return log(a / b);
}

double[] softToP0(const(double)[] bipolar) {
    double[] p0 = new double[](bipolar.length);
    foreach (i, s; bipolar) {
        // A bipolar ±1 observation at unit scale, squashed into (0, 1).
        double e = exp(s);
        p0[i] = e / (e + exp(-s));
    }
    return p0;
}

bool[] hardFromLlr(const(double)[] llr) {
    bool[] bits = new bool[](llr.length);
    foreach (i, v; llr) {
        bits[i] = v < 0;
    }
    return bits;
}

unittest {
    auto spec = convExample();
    bool[] msg = [true, false, true, true, false, false, true];
    auto coded = convEncode(spec, msg, true);
    auto soft = bipolarFromBits(coded);
    auto p0 = softToP0(soft);
    auto llr = bcjrLlr(spec, p0, cast(int) msg.length, true);
    assert(hardFromLlr(llr) == msg);
    auto vit = viterbiDecode(spec, soft, cast(int) msg.length, true);
    assert(vit == msg);
    // A mild sign error on two coded bits. Both decoders see the same soft
    // values and must agree, even if the word is no longer trivial.
    soft[2] = -0.2;
    soft[5] = 0.15;
    auto p1 = softToP0(soft);
    auto hardBcjr = hardFromLlr(bcjrLlr(spec, p1, cast(int) msg.length, true));
    auto hardVit = viterbiDecode(spec, soft, cast(int) msg.length, true);
    assert(hardBcjr == hardVit);
}
