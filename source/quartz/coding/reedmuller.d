module quartz.coding.reedmuller;

import quartz.coding.bits : hammingDistance;
import quartz.coding.hadamard : fwht;
import quartz.error : QuartzError;

// First-order Reed-Muller RM(1, m). Information bit 0 is the constant term
// and the remaining bits are the linear form. Decoding is a Walsh transform
// spike, checked against a brute-force decoder on every codeword of RM(1, 4).

@safe:

bool[] rmEncode(const(bool)[] info, int m) {
    if (m < 1 || m > 8 || cast(int) info.length != m + 1) {
        throw new QuartzError("Reed-Muller parameters are inconsistent");
    }
    int n = 1 << m;
    bool[] word = new bool[](n);
    foreach (x; 0 .. n) {
        bool bit = info[0];
        foreach (i; 0 .. m) {
            if (((x >> i) & 1) != 0 && info[i + 1]) {
                bit = !bit;
            }
        }
        word[x] = bit;
    }
    return word;
}

bool[] rmDecodeFast(const(bool)[] word, int m) {
    int n = 1 << m;
    if (cast(int) word.length != n) {
        throw new QuartzError("Reed-Muller word length is wrong");
    }
    int[] spec = new int[](n);
    foreach (i, bit; word) {
        spec[i] = bit ? -1 : 1;
    }
    fwht(spec);
    int best = 0;
    int bestAbs = -1;
    foreach (i, v; spec) {
        int a = v < 0 ? -v : v;
        if (a > bestAbs) {
            bestAbs = a;
            best = cast(int) i;
        }
    }
    bool[] info = new bool[](m + 1);
    info[0] = spec[best] < 0;
    foreach (i; 0 .. m) {
        info[i + 1] = ((best >> i) & 1) != 0;
    }
    return info;
}

bool[] rmDecodeBrute(const(bool)[] word, int m) {
    int nInfo = m + 1;
    int bestDist = int.max;
    bool[] best;
    foreach (mask; 0 .. (1 << nInfo)) {
        bool[] info = new bool[](nInfo);
        foreach (i; 0 .. nInfo) {
            info[i] = ((mask >> i) & 1) != 0;
        }
        auto cw = rmEncode(info, m);
        int dist = hammingDistance(cw, word);
        if (dist < bestDist) {
            bestDist = dist;
            best = info;
        }
    }
    return best;
}

unittest {
    foreach (m; 1 .. 5) {
        int nInfo = m + 1;
        foreach (mask; 0 .. (1 << nInfo)) {
            bool[] info = new bool[](nInfo);
            foreach (i; 0 .. nInfo) {
                info[i] = ((mask >> i) & 1) != 0;
            }
            auto cw = rmEncode(info, m);
            assert(rmDecodeFast(cw, m) == info);
            assert(rmDecodeBrute(cw, m) == info);
            // RM(1, m) has distance 2^(m-1), so a single flip is correctable
            // only once that distance is at least 3, which starts at m = 3.
            if (m >= 3) {
                bool[] noisy = cw.dup;
                noisy[0] = !noisy[0];
                assert(rmDecodeFast(noisy, m) == info);
                assert(rmDecodeBrute(noisy, m) == info);
            }
        }
    }
}
