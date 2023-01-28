module quartz.math.polynomial;

import quartz.math.approx : near;
import quartz.error : QuartzError;
import std.math : fabs;

// Real polynomials, low degree first: c[0] + c[1] x + c[2] x^2 + ...
// The Reed-Solomon field polynomials live next to the Galois field. This
// module is the real-coefficient tool used by filter algebra and by the
// Lagrange fractional delay.

@safe:

struct Poly {
    double[] c;

    this(double[] coefs) {
        c = coefs.dup;
        trim();
        if (c.length == 0) {
            c = [0.0];
        }
    }

    void trim() {
        while (c.length > 1 && fabs(c[$ - 1]) <= 0) {
            c = c[0 .. $ - 1];
        }
    }

    size_t degree() const {
        if (c.length == 0) {
            return 0;
        }
        return c.length - 1;
    }

    bool isZero() const {
        return c.length == 1 && c[0] == 0;
    }

    double eval(double x) const {
        double y = 0;
        foreach_reverse (coef; c) {
            y = y * x + coef;
        }
        return y;
    }

    Poly opBinary(string op)(Poly rhs) const {
        static if (op == "+") {
            return addScaled(rhs, 1.0);
        } else static if (op == "-") {
            return addScaled(rhs, -1.0);
        } else static if (op == "*") {
            double[] acc = new double[](c.length + rhs.c.length - 1);
            acc[] = 0;
            foreach (i, a; c) {
                foreach (j, b; rhs.c) {
                    acc[i + j] += a * b;
                }
            }
            return Poly(acc);
        } else {
            static assert(0);
        }
    }

    Poly addScaled(Poly rhs, double scale) const {
        size_t n = c.length > rhs.c.length ? c.length : rhs.c.length;
        double[] acc = new double[](n);
        acc[] = 0;
        foreach (i, a; c) {
            acc[i] += a;
        }
        foreach (i, b; rhs.c) {
            acc[i] += scale * b;
        }
        return Poly(acc);
    }

    Poly scaled(double s) const {
        double[] acc = new double[](c.length);
        foreach (i, a; c) {
            acc[i] = a * s;
        }
        return Poly(acc);
    }

    Poly derivative() const {
        if (c.length <= 1) {
            return Poly([0.0]);
        }
        double[] acc = new double[](c.length - 1);
        foreach (i; 1 .. c.length) {
            acc[i - 1] = c[i] * cast(double) i;
        }
        return Poly(acc);
    }

    // Indefinite integral with constant term zero.
    Poly integral() const {
        double[] acc = new double[](c.length + 1);
        acc[] = 0;
        foreach (i, a; c) {
            acc[i + 1] = a / cast(double) (i + 1);
        }
        return Poly(acc);
    }
}

struct PolyDiv {
    Poly quot;
    Poly rem;
}

PolyDiv divmod(Poly a, Poly b) {
    if (b.isZero()) {
        throw new QuartzError("polynomial division by zero");
    }
    double[] q = new double[](1);
    q[] = 0;
    double[] r = a.c.dup;
    long degB = cast(long) b.degree();
    double lead = b.c[b.degree()];
    int guard = 0;
    while (true) {
        guard++;
        if (guard > 128) {
            throw new QuartzError("polynomial division did not reduce the degree");
        }
        long degR = 0;
        bool any = false;
        for (long i = cast(long) r.length - 1; i >= 0; i--) {
            if (fabs(r[cast(size_t) i]) > 1e-15) {
                degR = i;
                any = true;
                break;
            }
        }
        if (!any || degR < degB) {
            break;
        }
        long k = degR - degB;
        double coef = r[cast(size_t) degR] / lead;
        if (q.length < cast(size_t) k + 1) {
            double[] grown = new double[](cast(size_t) k + 1);
            grown[] = 0;
            grown[0 .. q.length] = q;
            q = grown;
        }
        q[cast(size_t) k] += coef;
        foreach (j, bj; b.c) {
            r[cast(size_t) k + j] -= coef * bj;
        }
    }
    return PolyDiv(Poly(q), Poly(r));
}

Poly gcdPoly(Poly a, Poly b) {
    Poly x = a;
    Poly y = b;
    int guard = 0;
    while (!y.isZero()) {
        auto d = divmod(x, y);
        x = y;
        y = d.rem;
        guard++;
        if (guard > 64) {
            throw new QuartzError("polynomial gcd did not terminate");
        }
    }
    if (x.isZero()) {
        return x;
    }
    return x.scaled(1.0 / x.c[$ - 1]);
}

Poly lagrange(const(double)[] xs, const(double)[] ys) {
    if (xs.length != ys.length || xs.length == 0) {
        throw new QuartzError("lagrange inputs must be the same nonzero length");
    }
    Poly acc = Poly([0.0]);
    foreach (j; 0 .. xs.length) {
        Poly term = Poly([1.0]);
        double denom = 1.0;
        foreach (m; 0 .. xs.length) {
            if (m == j) {
                continue;
            }
            term = term * Poly([-xs[m], 1.0]);
            denom *= xs[j] - xs[m];
        }
        if (fabs(denom) < 1e-18) {
            throw new QuartzError("lagrange nodes are not distinct");
        }
        acc = acc + term.scaled(ys[j] / denom);
    }
    return acc;
}

unittest {
    Poly p = Poly([2.0, 3.0, 1.0]);
    assert(near(p.eval(2.0), 12.0, 1e-12, 1e-12));
    Poly q = Poly([1.0, 1.0]);
    auto d = divmod(p, q);
    assert(near(d.quot.eval(5.0), Poly([2.0, 1.0]).eval(5.0), 1e-9, 1e-9));
    assert(near(d.rem.eval(5.0), 0.0, 1e-9, 0.0));
    Poly g = gcdPoly(Poly([-1.0, 0.0, 1.0]), Poly([-1.0, 1.0]));
    assert(g.degree() == 1);
    assert(near(g.eval(1.0), 0.0, 1e-8, 0.0));
    Poly deriv = p.derivative();
    assert(near(deriv.eval(2.0), 7.0, 1e-12, 1e-12));
    Poly integ = Poly([0.0, 1.0]).integral();
    assert(near(integ.eval(3.0), 4.5, 1e-12, 1e-12));
    double[] xs = [0, 1, 2];
    double[] ys = [1, 4, 9];
    Poly fit = lagrange(xs, ys);
    assert(near(fit.eval(0.5), 2.25, 1e-8, 1e-8));
    assert(near(fit.eval(3.0), 16.0, 1e-6, 1e-8));
    Poly prod = Poly([1.0, 1.0]) * Poly([1.0, -1.0]);
    assert(near(prod.eval(3.0), (1.0 + 3.0) * (1.0 - 3.0), 1e-12, 1e-12));
}
