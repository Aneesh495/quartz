module quartz.mimo.sphere;

import quartz.math.complex : Complex, nearC;
import quartz.math.factor : qrMgs;
import quartz.math.matrix : Matrix;
import quartz.channel.rng : Xoshiro256;

// A Schnorr-Euchner sphere search for a square BPSK MIMO channel. The QR
// form makes each layer a scalar decision with a residual radius. The search
// is checked against exhaustive maximum likelihood on random channels.

@safe:

alias C = Complex!double;

C[] sphereBpsk(Matrix!C channel, C[] received) {
    Matrix!C q, r;
    qrMgs(channel, q, r);
    auto y = q.hermitian() * Matrix!C(received.length, 1, received);
    C[] symbols = [C(1, 0), C(-1, 0)];
    double best = double.infinity;
    C[] bestSyms;
    void search(int layer, double dist, C[] partial) {
        if (dist > best) {
            return;
        }
        if (layer < 0) {
            best = dist;
            bestSyms = partial.dup;
            return;
        }
        foreach (s; symbols) {
            C acc = y[layer, 0];
            foreach (j; layer .. cast(int) received.length) {
                if (j == layer) {
                    acc = acc - r[layer, layer] * s;
                } else if (j < cast(int) partial.length) {
                    acc = acc - r[layer, j] * partial[j];
                }
            }
            C[] next = partial.dup;
            if (next.length < received.length) {
                next.length = received.length;
            }
            next[layer] = s;
            search(layer - 1, dist + acc.mag2(), next);
        }
    }
    C[] seed = new C[](received.length);
    search(cast(int) received.length - 1, 0, seed);
    return bestSyms;
}

C[] bruteBpsk(Matrix!C channel, C[] received) {
    C[] symbols = [C(1, 0), C(-1, 0)];
    double best = double.infinity;
    C[] bestSyms;
    foreach (a; symbols) {
        foreach (b; symbols) {
            auto x = Matrix!C(2, 1);
            x[0, 0] = a;
            x[1, 0] = b;
            auto y = channel * x;
            double dist = (y[0, 0] - received[0]).mag2() + (y[1, 0] - received[1]).mag2();
            if (dist < best) {
                best = dist;
                bestSyms = [a, b];
            }
        }
    }
    return bestSyms;
}

unittest {
    auto rng = Xoshiro256(31);
    foreach (trial; 0 .. 15) {
        auto h = Matrix!C(2, 2);
        foreach (i; 0 .. 2) {
            foreach (j; 0 .. 2) {
                h[i, j] = rng.nextComplexGaussian();
            }
        }
        C[] sent = [rng.nextBool() ? C(1, 0) : C(-1, 0), rng.nextBool() ? C(1, 0) : C(-1, 0)];
        auto x = Matrix!C(2, 1, sent);
        auto y = h * x;
        C[] got = sphereBpsk(h, [y[0, 0], y[1, 0]]);
        C[] ml = bruteBpsk(h, [y[0, 0], y[1, 0]]);
        assert(nearC(got[0], ml[0], 1e-8, 1e-8));
        assert(nearC(got[1], ml[1], 1e-8, 1e-8));
        assert(nearC(got[0], sent[0], 1e-6, 1e-6));
    }
}
