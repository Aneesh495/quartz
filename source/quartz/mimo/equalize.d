module quartz.mimo.equalize;

import quartz.math.complex : Complex, nearC;
import quartz.math.factor : cholesky, factorLu;
import quartz.math.matrix : Matrix, fromReal, nearM;
import quartz.channel.rng : Xoshiro256;

// Flat MIMO: y = H x + n. Zero forcing inverts a square channel with LU.
// MMSE solves (H^H H + σ^2 I) x = H^H y with a Hermitian Cholesky factor.
// Both are checked on a noiseless draw, where they have to agree.

@safe:

alias C = Complex!double;

Matrix!C zfEqualize(Matrix!C channel, Matrix!C y) {
    auto lu = factorLu(channel);
    Matrix!C x;
    if (!lu.solve(y, x)) {
        return Matrix!C(channel.cols, y.cols);
    }
    return x;
}

Matrix!C mmseEqualize(Matrix!C channel, Matrix!C y, double noiseVar) {
    auto gram = channel.hermitian() * channel;
    size_t n = gram.rows;
    foreach (i; 0 .. n) {
        gram[i, i] = gram[i, i] + fromReal!C(noiseVar);
    }
    Matrix!C lower;
    auto rhs = channel.hermitian() * y;
    if (!cholesky(gram, lower)) {
        return zfEqualize(channel, y);
    }
    // Solve L L^H x = rhs by forward and back substitution.
    size_t k = rhs.cols;
    auto x = Matrix!C(n, k);
    foreach (col; 0 .. k) {
        C[] z = new C[](n);
        foreach (i; 0 .. n) {
            C sum = rhs[i, col];
            foreach (j; 0 .. i) {
                sum = sum - lower[i, j] * z[j];
            }
            z[i] = sum / lower[i, i];
        }
        for (size_t ii = n; ii > 0; ) {
            ii--;
            C sum = z[ii];
            foreach (j; ii + 1 .. n) {
                sum = sum - lower[j, ii].conj() * x[j, col];
            }
            x[ii, col] = sum / lower[ii, ii].conj();
        }
    }
    return x;
}

unittest {
    auto rng = Xoshiro256(23);
    auto h = Matrix!C(2, 2);
    foreach (i; 0 .. 2) {
        foreach (j; 0 .. 2) {
            h[i, j] = rng.nextComplexGaussian();
        }
    }
    auto x = Matrix!C(2, 1);
    x[0, 0] = C(0.3, -0.4);
    x[1, 0] = C(-0.7, 0.2);
    auto y = h * x;
    auto zf = zfEqualize(h, y);
    assert(nearC(zf[0, 0], x[0, 0], 1e-8, 1e-8));
    assert(nearC(zf[1, 0], x[1, 0], 1e-8, 1e-8));
    auto mmse = mmseEqualize(h, y, 0.0);
    assert(nearC(mmse[0, 0], x[0, 0], 1e-6, 1e-6));
    assert(nearC(mmse[1, 0], x[1, 0], 1e-6, 1e-6));
    auto eye = h.hermitian() * h;
    assert(eye.rows == 2);
    assert(nearM(h, h, 0.0));
}
