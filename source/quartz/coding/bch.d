module quartz.coding.bch;

import quartz.coding.galois : Galois;
import quartz.coding.gfpoly : gfDegree, gfDivMod, gfEvalPoly, gfMulPoly, gfTrim;
import quartz.coding.reedsolomon : rsChien, rsErrorLocator, RsCode;
import quartz.error : QuartzError;

// Binary BCH built as a cyclic code whose generator is the product of the
// distinct minimal polynomials of alpha, alpha^3, ... . Decoding reuses the
// Reed-Solomon Berlekamp-Massey and Chien search, then flips those positions.
// Error magnitudes are not estimated: a binary error is a one.

@safe:

int[] minimalPolynomial(Galois gf, int element) {
    bool[] seen = new bool[](gf.order + 1);
    int[] roots;
    int x = element;
    while (!seen[x]) {
        seen[x] = true;
        roots ~= x;
        x = gf.mul(x, x);
    }
    int[] poly = [1];
    foreach (root; roots) {
        poly = gfMulPoly(gf, poly, [root, 1]);
    }
    foreach (coef; poly) {
        if (coef != 0 && coef != 1) {
            throw new QuartzError("minimal polynomial left the base field");
        }
    }
    return gfTrim(poly);
}

int[] bchGenerator(Galois gf, int designedT) {
    int[] gen = [1];
    bool[] used = new bool[](gf.order + 1);
    foreach (i; 1 .. 2 * designedT) {
        int el = gf.alpha(i);
        if (used[el]) {
            continue;
        }
        int[] minpoly = minimalPolynomial(gf, el);
        // Mark the whole conjugacy class.
        int x = el;
        foreach (_; 0 .. gf.m + 1) {
            used[x] = true;
            x = gf.mul(x, x);
        }
        gen = gfMulPoly(gf, gen, minpoly);
    }
    return gfTrim(gen);
}

struct BchCode {
    int n;
    int k;
    int t;
    int[] generator;
    Galois field;

    static BchCode make(int m, int t) {
        BchCode code;
        code.field = Galois.standard(m);
        code.n = code.field.order;
        code.t = t;
        code.generator = bchGenerator(code.field, t);
        int deg = gfDegree(code.generator);
        code.k = code.n - deg;
        if (code.k <= 0) {
            throw new QuartzError("BCH dimension is not positive");
        }
        return code;
    }
}

int[] bchEncode(BchCode code, const(int)[] message) {
    if (cast(int) message.length != code.k) {
        throw new QuartzError("BCH message length does not match k");
    }
    int nsym = code.n - code.k;
    int[] shifted = new int[](message.length + nsym);
    foreach (i, bit; message) {
        if (bit != 0 && bit != 1) {
            throw new QuartzError("BCH message bit is not binary");
        }
        shifted[nsym + i] = bit;
    }
    auto divided = gfDivMod(code.field, shifted, code.generator);
    int[] word = new int[](code.n);
    foreach (i; 0 .. nsym) {
        if (i < divided.rem.length) {
            word[i] = divided.rem[i] & 1;
        }
    }
    foreach (i, bit; message) {
        word[nsym + i] = bit;
    }
    return word;
}

int[] bchSyndromes(BchCode code, const(int)[] word) {
    int[] s = new int[](2 * code.t);
    foreach (j; 0 .. s.length) {
        s[j] = gfEvalPoly(code.field, word, code.field.alpha(cast(int) j + 1));
    }
    return s;
}

bool bchDecode(BchCode code, int[] word) {
    int[] synd = bchSyndromes(code, word);
    bool clean = true;
    foreach (v; synd) {
        if (v != 0) {
            clean = false;
        }
    }
    if (clean) {
        return true;
    }
    // The locator routine is the same arithmetic as Reed-Solomon. The RsCode
    // value is only a carrier for the field, the length, and the root offset.
    RsCode carrier;
    carrier.field = code.field;
    carrier.n = code.n;
    carrier.nsym = cast(int) synd.length;
    carrier.k = code.k;
    carrier.firstRoot = 1;
    int[] locator = rsErrorLocator(carrier, synd);
    int degree = gfDegree(locator);
    if (degree <= 0 || degree > code.t) {
        return false;
    }
    int[] pos = rsChien(carrier, locator);
    if (pos.length != degree) {
        return false;
    }
    foreach (p; pos) {
        word[p] ^= 1;
    }
    int[] check = bchSyndromes(code, word);
    foreach (v; check) {
        if (v != 0) {
            return false;
        }
    }
    return true;
}

unittest {
    auto code = BchCode.make(4, 2);
    assert(code.n == 15);
    assert(code.k > 0 && code.k < 15);
    int[] msg = new int[](code.k);
    foreach (i; 0 .. code.k) {
        msg[i] = (i * 3) & 1;
    }
    auto word = bchEncode(code, msg);
    foreach (bit; word) {
        assert(bit == 0 || bit == 1);
    }
    int[] clean = word.dup;
    assert(bchDecode(code, clean));
    assert(clean == word);
    foreach (i; 0 .. code.n) {
        int[] bad = word.dup;
        bad[i] ^= 1;
        assert(bchDecode(code, bad));
        assert(bad == word);
    }
    foreach (i; 0 .. code.n) {
        foreach (j; i + 1 .. code.n) {
            int[] bad = word.dup;
            bad[i] ^= 1;
            bad[j] ^= 1;
            assert(bchDecode(code, bad));
            assert(bad == word);
        }
    }
}
