module quartz.math.matrix;

import quartz.error : QuartzError;
import quartz.math.approx : near;
import quartz.math.complex : Complex, nearC;
import std.math : fabs, sqrt;
import std.traits : isFloatingPoint;

// Dense row-major matrices for the MIMO paths. Sizes stay small (a handful
// of antennas, a handful of taps), so the interesting part is the algebra
// rather than a blocked GEMM. Float arrays are zeroed explicitly because a
// freshly allocated double is NaN in D.

@safe:

double abs2Of(T)(T v) {
    static if (isFloatingPoint!T) {
        return cast(double) (v * v);
    } else {
        return cast(double) v.mag2();
    }
}

double absOf(T)(T v) {
    static if (isFloatingPoint!T) {
        return fabs(cast(double) v);
    } else {
        return cast(double) v.mag();
    }
}

T conjOf(T)(T v) {
    static if (isFloatingPoint!T) {
        return v;
    } else {
        return v.conj();
    }
}

T realOne(T)() {
    static if (isFloatingPoint!T) {
        return cast(T) 1;
    } else {
        return T(cast(typeof(T.init.re)) 1, cast(typeof(T.init.re)) 0);
    }
}

T realZero(T)() {
    static if (isFloatingPoint!T) {
        return cast(T) 0;
    } else {
        return T(cast(typeof(T.init.re)) 0, cast(typeof(T.init.re)) 0);
    }
}

T fromReal(T)(double x) {
    static if (isFloatingPoint!T) {
        return cast(T) x;
    } else {
        return T(cast(typeof(T.init.re)) x, cast(typeof(T.init.re)) 0);
    }
}

void fillZero(T)(T[] a) {
    a[] = realZero!T();
}

struct Matrix(T) {
    size_t rows;
    size_t cols;
    T[] a;

    this(size_t rows, size_t cols) {
        this.rows = rows;
        this.cols = cols;
        this.a = new T[](rows * cols);
        fillZero(this.a);
    }

    this(size_t rows, size_t cols, const(T)[] data) {
        if (data.length != rows * cols) {
            throw new QuartzError("matrix data length does not match shape");
        }
        this.rows = rows;
        this.cols = cols;
        this.a = data.dup;
    }

    static Matrix identity(size_t n) {
        auto m = Matrix(n, n);
        foreach (i; 0 .. n) {
            m[i, i] = realOne!T();
        }
        return m;
    }

    static Matrix fromRows(const(T[])[] rowsIn) {
        if (rowsIn.length == 0) {
            throw new QuartzError("matrix needs at least one row");
        }
        size_t c = rowsIn[0].length;
        auto m = Matrix(rowsIn.length, c);
        foreach (i, row; rowsIn) {
            if (row.length != c) {
                throw new QuartzError("matrix rows have different lengths");
            }
            foreach (j, v; row) {
                m[i, j] = v;
            }
        }
        return m;
    }

    ref T opIndex(size_t i, size_t j) {
        if (i >= rows || j >= cols) {
            throw new QuartzError("matrix index out of range");
        }
        return a[i * cols + j];
    }

    T opIndex(size_t i, size_t j) const {
        if (i >= rows || j >= cols) {
            throw new QuartzError("matrix index out of range");
        }
        return a[i * cols + j];
    }

    Matrix dup() const {
        return Matrix(rows, cols, a);
    }

    Matrix transposed() const {
        auto m = Matrix(cols, rows);
        foreach (i; 0 .. rows) {
            foreach (j; 0 .. cols) {
                m[j, i] = this[i, j];
            }
        }
        return m;
    }

    Matrix hermitian() const {
        auto m = Matrix(cols, rows);
        foreach (i; 0 .. rows) {
            foreach (j; 0 .. cols) {
                m[j, i] = conjOf(this[i, j]);
            }
        }
        return m;
    }

    Matrix scaled(double s) const {
        auto m = dup();
        foreach (ref v; m.a) {
            v = v * fromReal!T(s);
        }
        return m;
    }

    Matrix opBinary(string op)(Matrix rhs) const {
        static if (op == "+") {
            if (rows != rhs.rows || cols != rhs.cols) {
                throw new QuartzError("matrix add shape mismatch");
            }
            auto m = dup();
            foreach (i, ref v; m.a) {
                v = v + rhs.a[i];
            }
            return m;
        } else static if (op == "-") {
            if (rows != rhs.rows || cols != rhs.cols) {
                throw new QuartzError("matrix sub shape mismatch");
            }
            auto m = dup();
            foreach (i, ref v; m.a) {
                v = v - rhs.a[i];
            }
            return m;
        } else static if (op == "*") {
            if (cols != rhs.rows) {
                throw new QuartzError("matrix multiply shape mismatch");
            }
            auto m = Matrix(rows, rhs.cols);
            foreach (i; 0 .. rows) {
                foreach (k; 0 .. cols) {
                    T aik = this[i, k];
                    foreach (j; 0 .. rhs.cols) {
                        m[i, j] = m[i, j] + aik * rhs[k, j];
                    }
                }
            }
            return m;
        } else {
            static assert(0);
        }
    }

    Matrix opUnary(string op)() const if (op == "-") {
        auto m = dup();
        foreach (ref v; m.a) {
            v = -v;
        }
        return m;
    }

    T trace() const {
        if (rows != cols) {
            throw new QuartzError("trace needs a square matrix");
        }
        T s = realZero!T();
        foreach (i; 0 .. rows) {
            s = s + this[i, i];
        }
        return s;
    }

    double normF() const {
        double s = 0;
        foreach (v; a) {
            s += abs2Of(v);
        }
        return sqrt(s);
    }

    Matrix kronecker(Matrix rhs) const {
        auto m = Matrix(rows * rhs.rows, cols * rhs.cols);
        foreach (i; 0 .. rows) {
            foreach (j; 0 .. cols) {
                T vij = this[i, j];
                foreach (bi; 0 .. rhs.rows) {
                    foreach (bj; 0 .. rhs.cols) {
                        m[i * rhs.rows + bi, j * rhs.cols + bj] = vij * rhs[bi, bj];
                    }
                }
            }
        }
        return m;
    }

    Matrix hadamard(Matrix rhs) const {
        if (rows != rhs.rows || cols != rhs.cols) {
            throw new QuartzError("hadamard shape mismatch");
        }
        auto m = Matrix(rows, cols);
        foreach (i, v; a) {
            m.a[i] = v * rhs.a[i];
        }
        return m;
    }

    T[] column(size_t j) const {
        T[] columnValues = new T[](rows);
        fillZero(columnValues);
        foreach (i; 0 .. rows) {
            columnValues[i] = this[i, j];
        }
        return columnValues;
    }
}

bool nearM(T)(Matrix!T a, Matrix!T b, double tol) {
    if (a.rows != b.rows || a.cols != b.cols) {
        return false;
    }
    foreach (i; 0 .. a.a.length) {
        if (absOf(a.a[i] - b.a[i]) > tol) {
            return false;
        }
    }
    return true;
}

unittest {
    auto a = Matrix!double.fromRows([[1.0, 2.0], [3.0, 4.0]]);
    auto b = Matrix!double.fromRows([[5.0, 6.0], [7.0, 8.0]]);
    auto p = a * b;
    assert(near(p[0, 0], 19.0, 1e-12, 1e-12));
    assert(near(p[0, 1], 22.0, 1e-12, 1e-12));
    assert(near(p[1, 0], 43.0, 1e-12, 1e-12));
    assert(near(p[1, 1], 50.0, 1e-12, 1e-12));
    auto eye = Matrix!double.identity(2);
    assert(nearM(a * eye, a, 1e-15));
    assert(near(a.trace(), 5.0, 1e-15, 0.0));
    auto kt = Matrix!double.fromRows([[1.0, 2.0]]) 
        .kronecker(Matrix!double.fromRows([[0.0, 5.0], [6.0, 7.0]]));
    assert(kt.rows == 2 && kt.cols == 4);
    assert(near(kt[0, 0], 0.0, 0.0, 0.0));
    assert(near(kt[0, 1], 5.0, 0.0, 0.0));
    assert(near(kt[1, 2], 12.0, 0.0, 0.0));
    alias C = Complex!double;
    auto h = Matrix!C.fromRows([[C(1, -1), C(0, 2)]]);
    auto hh = h.hermitian();
    assert(hh.rows == 2 && hh.cols == 1);
    assert(nearC(hh[0, 0], C(1, 1), 1e-15, 0.0));
    assert(nearC(hh[1, 0], C(0, -2), 1e-15, 0.0));
    auto gram = h.hermitian() * h;
    assert(gram.rows == 2 && gram.cols == 2);
    assert(near(a.normF(), sqrt(30.0), 1e-12, 1e-12));
}
