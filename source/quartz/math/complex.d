module quartz.math.complex;

import quartz.math.approx : near;
import std.math : atan2, cos, fabs, hypot, sin;
import stdmath = std.math;
import std.traits : isFloatingPoint;

// Complex baseband sample. The radio stack uses one definition of magnitude,
// conjugate, and integer power so a constellation point and an FFT bin share
// their rounding.

@safe:

struct Complex(T) if (isFloatingPoint!T) {
    T re = 0;
    T im = 0;

    this(T re, T im) {
        this.re = re;
        this.im = im;
    }

    this(T re) {
        this.re = re;
        this.im = 0;
    }

    Complex conj() const {
        return Complex(re, -im);
    }

    T mag2() const {
        return re * re + im * im;
    }

    T mag() const {
        return hypot(re, im);
    }

    T arg() const {
        return atan2(im, re);
    }

    bool isZero() const {
        return re == 0 && im == 0;
    }

    Complex opUnary(string op)() const if (op == "-") {
        return Complex(cast(T) (-re), cast(T) (-im));
    }

    Complex opUnary(string op)() const if (op == "+") {
        return this;
    }

    Complex opBinary(string op)(Complex rhs) const {
        static if (op == "+") {
            return Complex(cast(T) (re + rhs.re), cast(T) (im + rhs.im));
        } else static if (op == "-") {
            return Complex(cast(T) (re - rhs.re), cast(T) (im - rhs.im));
        } else static if (op == "*") {
            return Complex(
                cast(T) (re * rhs.re - im * rhs.im),
                cast(T) (re * rhs.im + im * rhs.re));
        } else static if (op == "/") {
            T d = rhs.mag2();
            return Complex(
                cast(T) ((re * rhs.re + im * rhs.im) / d),
                cast(T) ((im * rhs.re - re * rhs.im) / d));
        } else {
            static assert(0, "unsupported complex operator " ~ op);
        }
    }

    Complex opBinary(string op)(T rhs) const {
        static if (op == "+") {
            return Complex(cast(T) (re + rhs), im);
        } else static if (op == "-") {
            return Complex(cast(T) (re - rhs), im);
        } else static if (op == "*") {
            return Complex(cast(T) (re * rhs), cast(T) (im * rhs));
        } else static if (op == "/") {
            return Complex(cast(T) (re / rhs), cast(T) (im / rhs));
        } else {
            static assert(0, "unsupported complex operator " ~ op);
        }
    }

    Complex opBinaryRight(string op)(T lhs) const {
        static if (op == "+") {
            return Complex(cast(T) (lhs + re), im);
        } else static if (op == "-") {
            return Complex(cast(T) (lhs - re), cast(T) (-im));
        } else static if (op == "*") {
            return Complex(cast(T) (lhs * re), cast(T) (lhs * im));
        } else static if (op == "/") {
            T d = mag2();
            return Complex(cast(T) ((lhs * re) / d), cast(T) ((-lhs * im) / d));
        } else {
            static assert(0, "unsupported complex operator " ~ op);
        }
    }

    Complex opOpAssign(string op)(Complex rhs) {
        this = opBinary!op(rhs);
        return this;
    }

    Complex opOpAssign(string op)(T rhs) {
        this = opBinary!op(rhs);
        return this;
    }

    // Principal square root. The branch cut is the negative real axis, and
    // the returned real part is nonnegative.
    Complex sqrt() const {
        T m = mag();
        if (m == 0) {
            return Complex(0, 0);
        }
        T u = stdmath.sqrt(cast(T) ((m + re) / 2));
        T v = stdmath.sqrt(cast(T) ((m - re) / 2));
        if (im < 0) {
            v = cast(T) (-v);
        }
        return Complex(u, v);
    }

    Complex log() const {
        return Complex(stdmath.log(mag()), arg());
    }

    Complex exp() const {
        T e = stdmath.exp(re);
        return Complex(cast(T) (e * cos(im)), cast(T) (e * sin(im)));
    }

    // Integer power by squaring. Negative exponents invert first.
    Complex powi(int n) const {
        if (n == 0) {
            return Complex(1, 0);
        }
        if (n < 0) {
            return Complex(1, 0) / powi(-n);
        }
        Complex result = Complex(1, 0);
        Complex base = this;
        int e = n;
        while (e > 0) {
            if ((e & 1) != 0) {
                result = result * base;
            }
            base = base * base;
            e >>= 1;
        }
        return result;
    }

    static Complex cis(T theta) {
        return Complex(cos(theta), sin(theta));
    }

    static Complex fromPolar(T radius, T theta) {
        return Complex(cast(T) (radius * cos(theta)), cast(T) (radius * sin(theta)));
    }
}

alias Complex64 = Complex!double;
alias Complex32 = Complex!float;

bool nearC(T)(Complex!T a, Complex!T b, T absTol, T relTol) {
    return near(a.re, b.re, absTol, relTol) && near(a.im, b.im, absTol, relTol);
}

// Sum of squares without building an intermediate array. Used by energy
// meters and by the EVM denominator.
T energy(T)(const(Complex!T)[] xs) {
    T s = 0;
    foreach (x; xs) {
        s += x.mag2();
    }
    return s;
}

Complex!T mean(T)(const(Complex!T)[] xs) {
    Complex!T s = Complex!T(0, 0);
    if (xs.length == 0) {
        return s;
    }
    foreach (x; xs) {
        s += x;
    }
    return s / cast(T) xs.length;
}

unittest {
    alias C = Complex!double;
    C a = C(3, 4);
    assert(near(a.mag(), 5.0, 1e-12, 1e-12));
    assert(near(a.mag2(), 25.0, 1e-12, 0.0));
    C b = C(1, -2);
    C prod = a * b;
    assert(nearC(prod, C(11, -2), 1e-12, 1e-12));
    assert(nearC(a / a, C(1, 0), 1e-12, 1e-12));
    assert(nearC(2.0 * a - a, a, 1e-12, 1e-12));
    C unit = C.cis(0.4);
    assert(near(unit.mag(), 1.0, 1e-12, 1e-12));
    C root = C(-1, 0).sqrt();
    assert(nearC(root, C(0, 1), 1e-12, 1e-12));
    assert(nearC(root * root, C(-1, 0), 1e-12, 1e-12));
    C z = C(0.3, -0.7);
    assert(nearC((z.exp()).log(), z, 1e-12, 1e-12));
    assert(nearC(z.powi(5), z * z * z * z * z, 1e-10, 1e-10));
    assert(nearC(z.powi(0), C(1, 0), 1e-15, 0.0));
    assert(nearC(z.powi(-1), C(1, 0) / z, 1e-12, 1e-12));
    C[] block = [C(1, 0), C(0, 1)];
    assert(near(energy(block), 2.0, 1e-15, 0.0));
    assert(nearC(mean(block), C(0.5, 0.5), 1e-15, 0.0));
    C zero = C(0, 0);
    assert(zero.isZero());
    assert(near(fabs(C(-4, 0).mag() - 4), 0.0, 1e-15, 0.0));
}
