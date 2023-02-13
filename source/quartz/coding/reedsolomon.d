module quartz.coding.reedsolomon;

import quartz.coding.galois : Galois;
import quartz.coding.gfpoly : gfAddPoly, gfDegree, gfDivMod, gfEvalPoly, gfMulPoly, gfScalePoly, gfShiftPoly, gfTrim;
import quartz.channel.rng : Xoshiro256;
import quartz.error : QuartzError;

// Reed-Solomon over GF(2^m). The generator has roots alpha^b ... alpha^{b+2t-1}.
// A codeword is systematic: the low coefficients are parity and the high
// coefficients are the message. Decoding is Berlekamp-Massey, a Chien search,
// and a Vandermonde solve for the magnitudes, so the Forney sign convention
// never has to be guessed.

@safe:

struct RsCode {
    int nsym;
    int firstRoot;
    int n;
    int k;
    int[] generator;
    Galois field;

    static RsCode make(int m, int nsym, int firstRoot = 0) {
        if (nsym <= 0 || (nsym % 2) != 0) {
            throw new QuartzError("Reed-Solomon parity length must be a positive even number");
        }
        RsCode code;
        code.field = Galois.standard(m);
        code.n = code.field.order;
        code.nsym = nsym;
        code.k = code.n - nsym;
        code.firstRoot = firstRoot;
        if (code.k <= 0) {
            throw new QuartzError("Reed-Solomon dimension is not positive");
        }
        int[] g = [1];
        foreach (j; 0 .. nsym) {
            int root = code.field.alpha(firstRoot + j);
            int[] factor = [root, 1];
            g = gfMulPoly(code.field, g, factor);
        }
        code.generator = g;
        return code;
    }

    int correctable() const {
        return nsym / 2;
    }
}

int[] rsEncode(RsCode code, const(int)[] message) {
    if (cast(int) message.length != code.k) {
        throw new QuartzError("Reed-Solomon message length does not match k");
    }
    foreach (sym; message) {
        if (sym < 0 || sym >= code.field.n) {
            throw new QuartzError("Reed-Solomon symbol is outside the field");
        }
    }
    int[] shifted = gfShiftPoly(message, code.nsym);
    auto divided = gfDivMod(code.field, shifted, code.generator);
    int[] word = new int[](code.n);
    foreach (i; 0 .. code.nsym) {
        if (i < divided.rem.length) {
            word[i] = divided.rem[i];
        }
    }
    foreach (i, sym; message) {
        word[code.nsym + i] = sym;
    }
    return word;
}

int[] rsSyndromes(RsCode code, const(int)[] word) {
    int[] s = new int[](code.nsym);
    foreach (j; 0 .. code.nsym) {
        s[j] = gfEvalPoly(code.field, word, code.field.alpha(code.firstRoot + j));
    }
    return s;
}

bool rsSyndromesClear(const(int)[] s) {
    foreach (v; s) {
        if (v != 0) {
            return false;
        }
    }
    return true;
}

int[] rsErrorLocator(RsCode code, const(int)[] synd) {
    Galois gf = code.field;
    int[] locator = [1];
    int[] previous = [1];
    int length = 0;
    int gap = 1;
    int scale = 1;
    foreach (n; 0 .. synd.length) {
        int delta = synd[n];
        foreach (i; 1 .. length + 1) {
            if (i < locator.length) {
                delta ^= gf.mul(locator[i], synd[n - i]);
            }
        }
        if (delta == 0) {
            gap++;
            continue;
        }
        int coef = gf.div(delta, scale);
        int[] correction = gfScalePoly(gf, gfShiftPoly(previous, gap), coef);
        int[] updated = gfAddPoly(locator, correction);
        if (2 * length <= cast(int) n) {
            previous = locator;
            length = cast(int) n + 1 - length;
            scale = delta;
            gap = 1;
            locator = updated;
        } else {
            locator = updated;
            gap++;
        }
    }
    return gfTrim(locator);
}

int[] rsChien(RsCode code, const(int)[] locator) {
    int[] positions;
    foreach (i; 0 .. code.n) {
        int x = code.field.alpha(-i);
        if (gfEvalPoly(code.field, locator, x) == 0) {
            positions ~= i;
        }
    }
    return positions;
}

bool rsSolveMagnitudes(RsCode code, const(int)[] positions, const(int)[] synd, out int[] values) {
    int v = cast(int) positions.length;
    values = new int[](v);
    if (v == 0) {
        return true;
    }
    Galois gf = code.field;
    int[] xs = new int[](v);
    foreach (i, pos; positions) {
        xs[i] = gf.alpha(pos);
    }
    int[][] rows = new int[][](v, v + 1);
    foreach (row; 0 .. v) {
        int power = 1;
        int rootShift = code.firstRoot;
        // Row j matches syndrome S_j = sum Y X^{b+j}.
        int xPower = 1;
        foreach (col; 0 .. v) {
            int xp = 1;
            int times = rootShift + row;
            foreach (_; 0 .. times) {
                xp = gf.mul(xp, xs[col]);
            }
            rows[row][col] = xp;
        }
        rows[row][v] = synd[row];
        power = xPower;
    }
    foreach (col; 0 .. v) {
        int pivot = -1;
        foreach (row; col .. v) {
            if (rows[row][col] != 0) {
                pivot = row;
                break;
            }
        }
        if (pivot < 0) {
            return false;
        }
        if (pivot != col) {
            auto tmp = rows[pivot];
            rows[pivot] = rows[col];
            rows[col] = tmp;
        }
        int inv = gf.inv(rows[col][col]);
        foreach (j; col .. v + 1) {
            rows[col][j] = gf.mul(rows[col][j], inv);
        }
        foreach (row; 0 .. v) {
            if (row == col || rows[row][col] == 0) {
                continue;
            }
            int factor = rows[row][col];
            foreach (j; col .. v + 1) {
                rows[row][j] ^= gf.mul(factor, rows[col][j]);
            }
        }
    }
    foreach (i; 0 .. v) {
        values[i] = rows[i][v];
    }
    return true;
}

struct RsDecoded {
    int[] codeword;
    int[] message;
    int errors;
    bool ok;
}

RsDecoded rsDecode(RsCode code, const(int)[] received) {
    RsDecoded result;
    if (cast(int) received.length != code.n) {
        throw new QuartzError("Reed-Solomon word length does not match n");
    }
    int[] word = received.dup;
    int[] synd = rsSyndromes(code, word);
    if (rsSyndromesClear(synd)) {
        result.codeword = word;
        result.message = word[code.nsym .. $].dup;
        result.ok = true;
        return result;
    }
    int[] locator = rsErrorLocator(code, synd);
    int degree = gfDegree(locator);
    if (degree <= 0 || degree > code.correctable()) {
        result.codeword = word;
        result.message = word[code.nsym .. $].dup;
        result.ok = false;
        return result;
    }
    int[] positions = rsChien(code, locator);
    if (positions.length != degree) {
        result.codeword = word;
        result.message = word[code.nsym .. $].dup;
        result.ok = false;
        return result;
    }
    int[] values;
    if (!rsSolveMagnitudes(code, positions, synd, values)) {
        result.codeword = word;
        result.message = word[code.nsym .. $].dup;
        result.ok = false;
        return result;
    }
    foreach (i, pos; positions) {
        word[pos] ^= values[i];
    }
    int[] check = rsSyndromes(code, word);
    result.codeword = word;
    result.message = word[code.nsym .. $].dup;
    result.errors = degree;
    result.ok = rsSyndromesClear(check);
    return result;
}

private int[] symbolsFromSeed(ref Xoshiro256 rng, int k, int fieldN) {
    int[] msg = new int[](k);
    foreach (i; 0 .. k) {
        msg[i] = rng.nextInt(fieldN);
    }
    return msg;
}

unittest {
    auto small = RsCode.make(3, 4, 0);
    assert(small.n == 7 && small.k == 3);
    int[] msg = [1, 2, 3];
    auto word = rsEncode(small, msg);
    assert(rsSyndromesClear(rsSyndromes(small, word)));
    assert(rsDecode(small, word).message == msg);

    // Every single-symbol error, every nonzero magnitude.
    foreach (pos; 0 .. small.n) {
        foreach (mag; 1 .. small.field.n) {
            int[] bad = word.dup;
            bad[pos] ^= mag;
            auto dec = rsDecode(small, bad);
            assert(dec.ok);
            assert(dec.message == msg);
            assert(dec.errors == 1);
        }
    }

    // Every double-symbol error on this one codeword.
    foreach (p0; 0 .. small.n) {
        foreach (p1; p0 + 1 .. small.n) {
            foreach (m0; 1 .. small.field.n) {
                foreach (m1; 1 .. small.field.n) {
                    int[] bad = word.dup;
                    bad[p0] ^= m0;
                    bad[p1] ^= m1;
                    auto dec = rsDecode(small, bad);
                    assert(dec.ok);
                    assert(dec.message == msg);
                }
            }
        }
    }

    auto rs15 = RsCode.make(4, 4, 0);
    auto rng = Xoshiro256(11);
    foreach (trial; 0 .. 12) {
        auto message = symbolsFromSeed(rng, rs15.k, rs15.field.n);
        auto clean = rsEncode(rs15, message);
        int[] bad = clean.dup;
        int a = rng.nextInt(rs15.n);
        int b = rng.nextInt(rs15.n - 1);
        if (b >= a) {
            b++;
        }
        bad[a] ^= 1 + rng.nextInt(rs15.field.n - 1);
        bad[b] ^= 1 + rng.nextInt(rs15.field.n - 1);
        auto dec = rsDecode(rs15, bad);
        assert(dec.ok);
        assert(dec.message == message);
    }

    // Three errors on a longer code, one fixed pattern.
    auto rs31 = RsCode.make(5, 6, 0);
    int[] longMsg = new int[](rs31.k);
    foreach (i; 0 .. rs31.k) {
        longMsg[i] = i % rs31.field.n;
    }
    auto longWord = rsEncode(rs31, longMsg);
    int[] damaged = longWord.dup;
    damaged[1] ^= 3;
    damaged[8] ^= 5;
    damaged[20] ^= 9;
    auto longDec = rsDecode(rs31, damaged);
    assert(longDec.ok);
    assert(longDec.message == longMsg);
    assert(longDec.errors == 3);
}
