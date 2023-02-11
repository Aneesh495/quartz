module quartz.coding.viterbi;

import quartz.coding.convolutional : ConvSpec, convEncode, convExample;
import quartz.coding.bits : hammingDistance;
import quartz.error : QuartzError;

// Hard and soft Viterbi for a rate 1/n feedforward code. The branch metric is
// a correlation: a coded 0 wants a positive observation and a coded 1 wants a
// negative one. Terminated codes end in the zero state. Short messages are
// checked against exhaustive maximum likelihood.

@safe:

bool[] viterbiDecode(ConvSpec spec, const(double)[] soft, int infoBits, bool terminated) {
    if (spec.constraint < 2 || spec.polys.length == 0) {
        throw new QuartzError("viterbi spec is empty");
    }
    int mem = spec.memory();
    int nstate = 1 << mem;
    int nout = spec.outputs();
    int steps = infoBits + (terminated ? mem : 0);
    if (soft.length < steps * nout) {
        throw new QuartzError("viterbi observation is short");
    }
    double[] prev = new double[](nstate);
    double[] next = new double[](nstate);
    prev[] = -1.0e300;
    prev[0] = 0;
    int[][] survivor = new int[][](steps, nstate);
    bool[][] inputBit = new bool[][](steps, nstate);
    foreach (t; 0 .. steps) {
        next[] = -1.0e300;
        bool allow = !terminated || t < infoBits;
        foreach (state; 0 .. nstate) {
            if (prev[state] < -1.0e290) {
                continue;
            }
            foreach (bitVal; 0 .. 2) {
                if (!allow && bitVal != 0) {
                    continue;
                }
                int nextState = bitVal | ((state << 1) & (nstate - 1));
                // Register: current bit, then state[0] as newest memory.
                double metric = prev[state];
                foreach (p, poly; spec.polys) {
                    bool y = false;
                    if ((poly & 1u) != 0 && bitVal == 1) {
                        y = !y;
                    }
                    foreach (i; 0 .. mem) {
                        bool tap = ((state >> i) & 1) != 0;
                        if (((poly >> (i + 1)) & 1u) != 0 && tap) {
                            y = !y;
                        }
                    }
                    double obs = soft[t * nout + p];
                    metric += y ? -obs : obs;
                }
                if (metric > next[nextState]) {
                    next[nextState] = metric;
                    survivor[t][nextState] = state;
                    inputBit[t][nextState] = bitVal == 1;
                }
            }
        }
        prev[] = next[];
    }
    int state = 0;
    if (!terminated) {
        double best = prev[0];
        foreach (s; 1 .. nstate) {
            if (prev[s] > best) {
                best = prev[s];
                state = s;
            }
        }
    }
    bool[] decoded = new bool[](steps);
    for (int t = steps - 1; t >= 0; t--) {
        decoded[t] = inputBit[t][state];
        state = survivor[t][state];
    }
    return decoded[0 .. infoBits].dup;
}

double[] bipolarFromBits(const(bool)[] bits) {
    double[] s = new double[](bits.length);
    foreach (i, bit; bits) {
        s[i] = bit ? -1.0 : 1.0;
    }
    return s;
}

bool[] bruteMl(ConvSpec spec, const(double)[] soft, int infoBits) {
    int mem = spec.memory();
    int steps = infoBits + mem;
    int nout = spec.outputs();
    double best = -1.0e300;
    bool[] bestMsg;
    foreach (mask; 0 .. (1 << infoBits)) {
        bool[] msg = new bool[](infoBits);
        foreach (i; 0 .. infoBits) {
            msg[i] = ((mask >> i) & 1) != 0;
        }
        auto coded = convEncode(spec, msg, true);
        double metric = 0;
        foreach (i; 0 .. steps * nout) {
            metric += coded[i] ? -soft[i] : soft[i];
        }
        if (metric > best) {
            best = metric;
            bestMsg = msg;
        }
    }
    return bestMsg;
}

unittest {
    auto spec = convExample();
    bool[] msg = [true, false, true, true, false, true];
    auto coded = convEncode(spec, msg, true);
    auto soft = bipolarFromBits(coded);
    auto got = viterbiDecode(spec, soft, cast(int) msg.length, true);
    assert(got == msg);
    auto ml = bruteMl(spec, soft, cast(int) msg.length);
    assert(ml == msg);
    // Flip two coded bits. The free distance of this small code is 5, so
    // two flips are still closer to the original word than to another.
    soft[0] = -soft[0];
    soft[3] = -soft[3];
    assert(viterbiDecode(spec, soft, cast(int) msg.length, true) == bruteMl(spec, soft, cast(int) msg.length));
    bool[] hard = convEncode(spec, msg, true);
    hard[1] = !hard[1];
    hard[4] = !hard[4];
    assert(hammingDistance(hard, coded) == 2);
}
