module quartz.math.factor;

import quartz.error : QuartzError;
import quartz.math.approx : near;
import quartz.math.complex : Complex, nearC;
import quartz.math.matrix : Matrix, absOf, fromReal, nearM, realOne, realZero;
import std.math : sqrt;

// Factorizations used by ZF, MMSE, and the sphere decoder's channel matrix.
// LU carries a row permutation. Cholesky is the Hermitian positive definite
// path. Modified Gram-Schmidt is the QR used when a tall pilot matrix is
// inverted in the least-squares sense.

@safe:

struct Lu(T) {
    Matrix!T factors;
    size_t[] pivot;
    int swaps = 0;
    bool singular = false;

    T determinant() const {
        if (singular) {
            return realZero!T();
        }
        T d = realOne!T();
        foreach (i; 0 .. factors.rows) {
            d = d * factors[i, i];
        }
        if ((swaps & 1) != 0) {
            d = -d;
        }
        return d;
    }

    bool solve(Matrix!T b, out Matrix!T x) const {
        if (singular || b.rows != factors.rows) {
            return false;
        }
        size_t n = factors.rows;
        x = Matrix!T(n, b.cols);
        foreach (col; 0 .. b.cols) {
            T[] y = new T[](n);
            foreach (i; 0 .. n) {
                y[i] = b[pivot[i], col];
            }
            foreach (i; 0 .. n) {
                T s = y[i];
                foreach (j; 0 .. i) {
                    s = s - factors[i, j] * y[j];
                }
                y[i] = s;
            }
            size_t i = n;
            while (i > 0) {
                i--;
                T s = y[i];
                foreach (j; i + 1 .. n) {
                    s = s - factors[i, j] * y[j];
                }
                T diag = factors[i, i];
                if (absOf(diag) < 1e-18) {
                    return false;
                }
                y[i] = s / diag;
            }
            foreach (row; 0 .. n) {
                x[row, col] = y[row];
            }
        }
        return true;
    }

    Matrix!T inverse() const {
        if (factors.rows != factors.cols) {
            throw new QuartzError("inverse needs a square matrix");
        }
        Matrix!T eye = Matrix!T.identity(factors.rows);
        Matrix!T inv;
        if (!solve(eye, inv)) {
            throw new QuartzError("matrix is singular");
        }
        return inv;
    }
}

Lu!T factorLu(T)(Matrix!T a) {
    if (a.rows != a.cols || a.rows == 0) {
        throw new QuartzError("LU needs a nonempty square matrix");
    }
    Lu!T factored;
    factored.factors = a.dup();
    size_t n = a.rows;
    factored.pivot = new size_t[](n);
    foreach (i; 0 .. n) {
        factored.pivot[i] = i;
    }
    foreach (k; 0 .. n) {
        size_t best = k;
        double bestAbs = absOf(factored.factors[k, k]);
        foreach (i; k + 1 .. n) {
            double v = absOf(factored.factors[i, k]);
            if (v > bestAbs) {
                bestAbs = v;
                best = i;
            }
        }
        if (bestAbs < 1e-14) {
            factored.singular = true;
            return factored;
        }
        if (best != k) {
            foreach (j; 0 .. n) {
                T tmp = factored.factors[k, j];
                factored.factors[k, j] = factored.factors[best, j];
                factored.factors[best, j] = tmp;
            }
            size_t tp = factored.pivot[k];
            factored.pivot[k] = factored.pivot[best];
            factored.pivot[best] = tp;
            factored.swaps++;
        }
        foreach (i; k + 1 .. n) {
            factored.factors[i, k] = factored.factors[i, k] / factored.factors[k, k];
            foreach (j; k + 1 .. n) {
                factored.factors[i, j] = factored.factors[i, j] - factored.factors[i, k] * factored.factors[k, j];
            }
        }
    }
    return factored;
}

bool cholesky(T)(Matrix!T a, out Matrix!T lower) {
    if (a.rows != a.cols || a.rows == 0) {
        return false;
    }
    size_t n = a.rows;
    lower = Matrix!T(n, n);
    foreach (i; 0 .. n) {
        foreach (j; 0 .. i + 1) {
            T sum = a[i, j];
            foreach (k; 0 .. j) {
                static if (is(T == double) || is(T == float)) {
                    sum = sum - lower[i, k] * lower[j, k];
                } else {
                    sum = sum - lower[i, k] * lower[j, k].conj();
                }
            }
            if (i == j) {
                double diag = absOf(sum);
                // Imaginary leftover on a Hermitian diagonal is roundoff.
                static if (is(T == double) || is(T == float)) {
                    if (sum <= 0) {
                        return false;
                    }
                    lower[i, j] = cast(T) sqrt(cast(double) sum);
                } else {
                    if (diag <= 0 || absOf(sum - fromReal!T(diag)) > 1e-8 * (1 + diag)) {
                        // Nontrivial imaginary part means the matrix is not Hermitian.
                        if (absOf(sum - fromReal!T(sum.re)) > 1e-8) {
                            return false;
                        }
                    }
                    if (sum.re <= 0) {
                        return false;
                    }
                    lower[i, j] = fromReal!T(sqrt(sum.re));
                }
            } else {
                T diag = lower[j, j];
                if (absOf(diag) == 0) {
                    return false;
                }
                lower[i, j] = sum / diag;
            }
        }
    }
    return true;
}

void qrMgs(T)(Matrix!T a, out Matrix!T q, out Matrix!T r) {
    if (a.rows < a.cols || a.cols == 0) {
        throw new QuartzError("QR expects a tall or square matrix");
    }
    size_t m = a.rows;
    size_t n = a.cols;
    q = Matrix!T(m, n);
    r = Matrix!T(n, n);
    Matrix!T v = a.dup();
    foreach (k; 0 .. n) {
        double norm2 = 0;
        foreach (i; 0 .. m) {
            norm2 += absOf(v[i, k]) * absOf(v[i, k]);
        }
        double norm = sqrt(norm2);
        if (norm < 1e-18) {
            throw new QuartzError("QR column is linearly dependent");
        }
        r[k, k] = fromReal!T(norm);
        foreach (i; 0 .. m) {
            q[i, k] = v[i, k] / fromReal!T(norm);
        }
        foreach (j; k + 1 .. n) {
            T dot = realZero!T();
            foreach (i; 0 .. m) {
                static if (is(T == double) || is(T == float)) {
                    dot = dot + q[i, k] * v[i, j];
                } else {
                    dot = dot + q[i, k].conj() * v[i, j];
                }
            }
            r[k, j] = dot;
            foreach (i; 0 .. m) {
                v[i, j] = v[i, j] - q[i, k] * dot;
            }
        }
    }
}

void eig2(double a, double b, double c, double d, out Complex!double l1, out Complex!double l2) {
    double tr = a + d;
    double det = a * d - b * c;
    double disc = tr * tr - 4.0 * det;
    if (disc >= 0) {
        double s = sqrt(disc);
        l1 = Complex!double((tr + s) / 2.0, 0);
        l2 = Complex!double((tr - s) / 2.0, 0);
    } else {
        double s = sqrt(-disc);
        l1 = Complex!double(tr / 2.0, s / 2.0);
        l2 = Complex!double(tr / 2.0, -s / 2.0);
    }
}

double conditionF(T)(Matrix!T a) {
    auto lu = factorLu(a);
    if (lu.singular) {
        return double.infinity;
    }
    return a.normF() * lu.inverse().normF();
}

unittest {
    auto a = Matrix!double.fromRows([[2.0, 1.0], [1.0, 3.0]]);
    auto b = Matrix!double.fromRows([[3.0], [4.0]]);
    auto lu = factorLu(a);
    Matrix!double x;
    assert(lu.solve(b, x));
    assert(near(x[0, 0], 1.0, 1e-10, 1e-10));
    assert(near(x[1, 0], 1.0, 1e-10, 1e-10));
    assert(near(lu.determinant(), 5.0, 1e-10, 1e-10));
    assert(nearM(a * lu.inverse(), Matrix!double.identity(2), 1e-9));

    auto swap = Matrix!double.fromRows([[0.0, 1.0], [1.0, 0.0]]);
    auto lus = factorLu(swap);
    assert(near(lus.determinant(), -1.0, 1e-12, 1e-12));
    auto rhs = Matrix!double.fromRows([[1.0], [2.0]]);
    Matrix!double xs;
    assert(lus.solve(rhs, xs));
    assert(near(xs[0, 0], 2.0, 1e-10, 1e-10));
    assert(near(xs[1, 0], 1.0, 1e-10, 1e-10));

    auto spd = Matrix!double.fromRows([[4.0, 2.0], [2.0, 3.0]]);
    Matrix!double lower;
    assert(cholesky(spd, lower));
    assert(nearM(lower * lower.transposed(), spd, 1e-9));

    alias C = Complex!double;
    auto lref = Matrix!C.fromRows([
        [C(2, 0), C(0, 0)],
        [C(1, 1), C(1, 0)]
    ]);
    auto herm = lref * lref.hermitian();
    Matrix!C lc;
    assert(cholesky(herm, lc));
    assert(nearM(lc * lc.hermitian(), herm, 1e-8));

    auto tall = Matrix!double.fromRows([
        [1.0, 1.0],
        [0.0, 1.0],
        [1.0, 0.0]
    ]);
    Matrix!double q, r;
    qrMgs(tall, q, r);
    assert(nearM(q * r, tall, 1e-9));
    auto gram = q.transposed() * q;
    assert(nearM(gram, Matrix!double.identity(2), 1e-9));

    Complex!double e1, e2;
    eig2(2, 0, 0, 5, e1, e2);
    assert(near(e1.re, 5.0, 1e-12, 1e-12) || near(e1.re, 2.0, 1e-12, 1e-12));
    assert(near(e1.re + e2.re, 7.0, 1e-12, 1e-12));
    eig2(0, -1, 1, 0, e1, e2);
    assert(near(e1.im * e1.im + e1.re * e1.re, 1.0, 1e-12, 1e-12));
    assert(nearC(e1 + e2, C(0, 0), 1e-12, 1e-12));

    auto singular = Matrix!double.fromRows([[1.0, 2.0], [2.0, 4.0]]);
    assert(factorLu(singular).singular);
    // Frobenius condition number of I_n is n, not the 2-norm condition 1.
    assert(near(conditionF(Matrix!double.identity(3)), 3.0, 1e-8, 1e-8));
}
