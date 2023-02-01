module quartz.coding.galois;

import quartz.error : QuartzError;
import quartz.math.special : floorLog2;

// GF(2^m) with an exponential table. Reed-Solomon, BCH, and the Golay
// polynomial engine share the same multiply. The primitive polynomial is
// stored with the high bit set, so x^8 + x^4 + x^3 + x^2 + 1 is 0x11d.

@safe:

int primitivePolynomial(int m) {
    switch (m) {
    case 2:
        return 0x7;
    case 3:
        return 0xb;
    case 4:
        return 0x13;
    case 5:
        return 0x25;
    case 6:
        return 0x43;
    case 7:
        return 0x89;
    case 8:
        return 0x11d;
    default:
        throw new QuartzError("no primitive polynomial is tabulated for this field");
    }
}

struct Galois {
    int m;
    int poly;
    int n;
    int order;
    int[] exp;
    int[] log;

    this(int m, int poly) {
        if (m < 2 || m > 8) {
            throw new QuartzError("field degree is out of range");
        }
        this.m = m;
        this.poly = poly;
        this.n = 1 << m;
        this.order = this.n - 1;
        this.exp = new int[](this.order * 2);
        this.log = new int[](this.n);
        this.log[] = -1;
        int x = 1;
        foreach (i; 0 .. this.order) {
            this.exp[i] = x;
            this.log[x] = cast(int) i;
            x <<= 1;
            if (x & this.n) {
                x ^= poly;
            }
        }
        foreach (i; 0 .. this.order) {
            this.exp[i + this.order] = this.exp[i];
        }
        if (this.log[1] != 0) {
            throw new QuartzError("field construction failed");
        }
        // Every nonzero element must appear exactly once.
        foreach (v; 1 .. this.n) {
            if (this.log[v] < 0) {
                throw new QuartzError("polynomial is not primitive");
            }
        }
    }

    static Galois standard(int m) {
        return Galois(m, primitivePolynomial(m));
    }

    int add(int a, int b) const {
        return a ^ b;
    }

    int sub(int a, int b) const {
        return a ^ b;
    }

    int mul(int a, int b) const {
        if (a == 0 || b == 0) {
            return 0;
        }
        return exp[log[a] + log[b]];
    }

    int div(int a, int b) const {
        if (b == 0) {
            throw new QuartzError("division by zero in the field");
        }
        if (a == 0) {
            return 0;
        }
        return exp[(log[a] + order - log[b]) % order];
    }

    int inv(int a) const {
        if (a == 0) {
            throw new QuartzError("inverse of zero in the field");
        }
        return exp[order - log[a]];
    }

    int pow(int a, int e) const {
        if (e == 0) {
            return 1;
        }
        if (a == 0) {
            return 0;
        }
        int ee = e % order;
        if (ee < 0) {
            ee += order;
        }
        return exp[(log[a] * ee) % order];
    }

    // alpha^i, with alpha the primitive element used to build the tables.
    int alpha(int i) const {
        int ee = i % order;
        if (ee < 0) {
            ee += order;
        }
        return exp[ee];
    }
}

unittest {
    auto gf = Galois.standard(8);
    assert(gf.mul(1, 1) == 1);
    assert(gf.mul(0, 5) == 0);
    foreach (a; 1 .. 256) {
        assert(gf.mul(a, gf.inv(a)) == 1);
    }
    assert(gf.pow(gf.alpha(1), 255) == 1);
    assert(gf.pow(gf.alpha(1), 1) == 2);
    auto gf16 = Galois.standard(4);
    assert(gf16.n == 16);
    assert(gf16.mul(gf16.add(3, 5), 7) == gf16.add(gf16.mul(3, 7), gf16.mul(5, 7)));
    // The tabulated degree-8 polynomial really is primitive: already checked
    // by the constructor when every nonzero log entry is filled.
    assert(floorLog2(gf.poly) == 8);
    foreach (deg; 2 .. 9) {
        auto field = Galois.standard(deg);
        assert(field.order == (1 << deg) - 1);
        assert(field.mul(field.alpha(1), field.inv(field.alpha(1))) == 1);
    }
    bool zero = false;
    try {
        auto bad = gf.div(1, 0);
        assert(bad == 0);
    } catch (QuartzError) {
        zero = true;
    }
    assert(zero);
}
