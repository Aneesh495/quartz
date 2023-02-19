module quartz.coding.ldpc;

import quartz.channel.rng : Xoshiro256;
import quartz.error : QuartzError;

// A systematic irregular repeat-accumulate code. The parity checks are an
// accumulator, so encoding is a prefix XOR and does not need a dense
// generator matrix. Decoding is flooding min-sum with a tanh-free sign rule.

@safe:

struct Edge {
    int check;
    int variable;
}

struct LdpcCode {
    int k;
    int m;
    int n;
    int[][] checks;
    Edge[] edges;

    int rows() const {
        return m;
    }
}

LdpcCode iraCode(int k, int m, int degree, ulong seed) {
    if (k <= 0 || m <= 0 || degree <= 0) {
        throw new QuartzError("LDPC dimensions must be positive");
    }
    LdpcCode code;
    code.k = k;
    code.m = m;
    code.n = k + m;
    code.checks = new int[][](m, 0);
    auto rng = Xoshiro256(seed);
    foreach (info; 0 .. k) {
        bool[] used = new bool[](m);
        int placed = 0;
        int guard = 0;
        while (placed < degree && guard < degree * m * 4) {
            int c = rng.nextInt(m);
            guard++;
            if (used[c]) {
                continue;
            }
            used[c] = true;
            code.checks[c] ~= info;
            placed++;
        }
        if (placed < degree) {
            foreach (c; 0 .. m) {
                if (placed >= degree) {
                    break;
                }
                if (!used[c]) {
                    used[c] = true;
                    code.checks[c] ~= info;
                    placed++;
                }
            }
        }
    }
    foreach (c; 0 .. m) {
        code.checks[c] ~= k + c;
        if (c > 0) {
            code.checks[c] ~= k + c - 1;
        }
    }
    foreach (c, vars; code.checks) {
        foreach (v; vars) {
            code.edges ~= Edge(cast(int) c, v);
        }
    }
    return code;
}

bool[] ldpcEncode(LdpcCode code, const(bool)[] message) {
    if (cast(int) message.length != code.k) {
        throw new QuartzError("LDPC message length does not match k");
    }
    bool[] word = new bool[](code.n);
    foreach (i, bit; message) {
        word[i] = bit;
    }
    foreach (c; 0 .. code.m) {
        bool parity = false;
        foreach (v; code.checks[c]) {
            if (v < code.k) {
                parity ^= word[v];
            } else if (v == code.k + c - 1 && c > 0) {
                parity ^= word[v];
            }
        }
        word[code.k + c] = parity;
    }
    return word;
}

bool ldpcSyndromeClear(LdpcCode code, const(bool)[] word) {
    if (cast(int) word.length != code.n) {
        return false;
    }
    foreach (vars; code.checks) {
        bool sum = false;
        foreach (v; vars) {
            sum ^= word[v];
        }
        if (sum) {
            return false;
        }
    }
    return true;
}

bool[] ldpcMinSum(LdpcCode code, const(double)[] llr, int iterations) {
    if (cast(int) llr.length != code.n) {
        throw new QuartzError("LDPC LLR length does not match n");
    }
    int ecount = cast(int) code.edges.length;
    double[] varToCheck = new double[](ecount);
    double[] checkToVar = new double[](ecount);
    varToCheck[] = 0;
    checkToVar[] = 0;
    int[][] varEdges = new int[][](code.n, 0);
    foreach (ei, edge; code.edges) {
        varEdges[edge.variable] ~= cast(int) ei;
    }
    bool[] hard = new bool[](code.n);
    foreach (iter; 0 .. iterations) {
        foreach (ei, edge; code.edges) {
            double sum = llr[edge.variable];
            foreach (other; varEdges[edge.variable]) {
                if (other != ei) {
                    sum += checkToVar[other];
                }
            }
            varToCheck[ei] = sum;
        }
        foreach (c; 0 .. code.m) {
            int[] members;
            foreach (ei, edge; code.edges) {
                if (edge.check == c) {
                    members ~= cast(int) ei;
                }
            }
            foreach (ei; members) {
                double sign = 1.0;
                double mag = 1.0e300;
                foreach (other; members) {
                    if (other == ei) {
                        continue;
                    }
                    double v = varToCheck[other];
                    if (v < 0) {
                        sign = -sign;
                    }
                    double a = v < 0 ? -v : v;
                    if (a < mag) {
                        mag = a;
                    }
                }
                if (members.length == 1) {
                    mag = 0;
                    sign = 1;
                }
                checkToVar[ei] = sign * mag;
            }
        }
        foreach (v; 0 .. code.n) {
            double total = llr[v];
            foreach (ei; varEdges[v]) {
                total += checkToVar[ei];
            }
            hard[v] = total < 0;
        }
        if (ldpcSyndromeClear(code, hard) && iter > 0) {
            break;
        }
    }
    return hard;
}

unittest {
    auto code = iraCode(12, 8, 3, 9);
    bool[] msg = [true, false, true, true, false, false, true, false, true, false, false, true];
    auto word = ldpcEncode(code, msg);
    assert(ldpcSyndromeClear(code, word));
    double[] llr = new double[](code.n);
    foreach (i, bit; word) {
        llr[i] = bit ? -25.0 : 25.0;
    }
    assert(ldpcMinSum(code, llr, 8) == word);
    // A weak wrong channel hint on one information bit. The checks still see
    // strong LLRs everywhere else, so most of those bits are pulled back.
    int fixed = 0;
    foreach (flipped; 0 .. code.k) {
        double[] trial = llr.dup;
        trial[flipped] = word[flipped] ? 2.0 : -2.0;
        auto recovered = ldpcMinSum(code, trial, 30);
        if (ldpcSyndromeClear(code, recovered) && recovered[0 .. code.k] == msg) {
            fixed++;
        }
    }
    assert(fixed * 2 >= code.k);
}
