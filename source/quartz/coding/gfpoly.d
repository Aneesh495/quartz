module quartz.coding.gfpoly;

import quartz.coding.galois : Galois;
import quartz.error : QuartzError;

// Polynomials over a Galois field, lowest degree first. Reed-Solomon and BCH
// use the same arithmetic, so the generator, the key equation, and Chien
// search do not each grow a private polynomial type.

@safe:

int gfDegree(const(int)[] p) {
    for (int i = cast(int) p.length - 1; i >= 0; i--) {
        if (p[i] != 0) {
            return i;
        }
    }
    return -1;
}

int[] gfTrim(const(int)[] p) {
    int d = gfDegree(p);
    if (d < 0) {
        return [0];
    }
    return p[0 .. d + 1].dup;
}

int[] gfAddPoly(const(int)[] a, const(int)[] b) {
    size_t n = a.length > b.length ? a.length : b.length;
    int[] s = new int[](n);
    foreach (i, v; a) {
        s[i] ^= v;
    }
    foreach (i, v; b) {
        s[i] ^= v;
    }
    return gfTrim(s);
}

int[] gfScalePoly(ref Galois gf, const(int)[] p, int s) {
    int[] o = new int[](p.length);
    foreach (i, v; p) {
        o[i] = gf.mul(v, s);
    }
    return gfTrim(o);
}

int[] gfShiftPoly(const(int)[] p, int k) {
    if (k < 0) {
        throw new QuartzError("polynomial shift is negative");
    }
    if (gfDegree(p) < 0) {
        return [0];
    }
    int[] o = new int[](p.length + k);
    foreach (i, v; p) {
        o[i + k] = v;
    }
    return o;
}

int[] gfMulPoly(ref Galois gf, const(int)[] a, const(int)[] b) {
    if (gfDegree(a) < 0 || gfDegree(b) < 0) {
        return [0];
    }
    int[] o = new int[](a.length + b.length - 1);
    foreach (i, av; a) {
        if (av == 0) {
            continue;
        }
        foreach (j, bv; b) {
            o[i + j] ^= gf.mul(av, bv);
        }
    }
    return gfTrim(o);
}

int gfEvalPoly(ref Galois gf, const(int)[] p, int x) {
    int y = 0;
    for (int i = cast(int) p.length - 1; i >= 0; i--) {
        y = gf.mul(y, x) ^ p[i];
    }
    return y;
}

int[] gfDerivative(const(int)[] p) {
    if (p.length <= 1) {
        return [0];
    }
    int[] d = new int[](p.length - 1);
    foreach (i; 1 .. p.length) {
        // In characteristic 2, the derivative keeps only odd powers, and the
        // integer coefficient i mod 2 is the only multiplier.
        if ((i & 1) != 0) {
            d[i - 1] = p[i];
        }
    }
    return gfTrim(d);
}

struct GfDiv {
    int[] quot;
    int[] rem;
}

GfDiv gfDivMod(ref Galois gf, const(int)[] a, const(int)[] b) {
    int degB = gfDegree(b);
    if (degB < 0) {
        throw new QuartzError("polynomial division by zero");
    }
    int[] r = a.dup;
    if (r.length == 0) {
        r = [0];
    }
    int[] q = [0];
    int lead = b[degB];
    int guard = 0;
    while (gfDegree(r) >= degB) {
        int degR = gfDegree(r);
        int k = degR - degB;
        int coef = gf.div(r[degR], lead);
        if (cast(int) q.length < k + 1) {
            int[] grown = new int[](k + 1);
            grown[0 .. q.length] = q;
            q = grown;
        }
        q[k] ^= coef;
        foreach (j, bj; b) {
            if (bj == 0) {
                continue;
            }
            r[k + j] ^= gf.mul(coef, bj);
        }
        guard++;
        if (guard > 512) {
            throw new QuartzError("field polynomial division did not terminate");
        }
    }
    return GfDiv(gfTrim(q), gfTrim(r));
}

unittest {
    auto gf = Galois.standard(4);
    int[] a = [1, 0, 1];
    int[] b = [1, 1];
    auto d = gfDivMod(gf, a, b);
    auto back = gfAddPoly(gfMulPoly(gf, d.quot, b), d.rem);
    assert(gfEvalPoly(gf, back, 5) == gfEvalPoly(gf, a, 5));
    int[] deriv = gfDerivative([1, 2, 3, 4]);
    // derivative of 1 + 2x + 3x^2 + 4x^3 is 2 + 0 x + 4 x^2 in char 2,
    // because only odd powers survive and their coefficient is copied.
    assert(deriv[0] == 2);
    assert(gfEvalPoly(gf, [3], 9) == 3);
    assert(gfDegree(gfMulPoly(gf, [1, 1], [1, 1])) >= 1);
}
