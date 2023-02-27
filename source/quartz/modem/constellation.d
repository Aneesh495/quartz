module quartz.modem.constellation;

import quartz.math.approx : near;
import quartz.math.complex : Complex, nearC;
import std.math : PI, cos, sin, sqrt;

// Labeled points on the complex plane, normalized to unit average energy.
// Soft bits are max-log LLRs, positive when zero is the closer bit. The
// demapper enumerates the points, which is the right algorithm at 64-QAM
// and a useful oracle if a slicer is ever specialized.

@safe:

struct Point {
    Complex!double at;
    uint bits;
}

struct Constellation {
    string name;
    int bitsPerSymbol;
    Point[] points;

    Complex!double map(uint bits) const {
        uint mask = bitsPerSymbol >= 31 ? uint.max : (1u << bitsPerSymbol) - 1;
        bits &= mask;
        foreach (p; points) {
            if (p.bits == bits) {
                return p.at;
            }
        }
        return points[0].at;
    }

    uint demap(Complex!double y, out double dist2) const {
        double best = double.infinity;
        uint bits = 0;
        foreach (p; points) {
            double d = (y - p.at).mag2();
            if (d < best) {
                best = d;
                bits = p.bits;
            }
        }
        dist2 = best;
        return bits;
    }

    double[] softLlrs(Complex!double y, double noiseVar) const {
        double[] llr = new double[](bitsPerSymbol);
        double nv = noiseVar < 1e-18 ? 1e-18 : noiseVar;
        foreach (bit; 0 .. bitsPerSymbol) {
            uint mask = 1u << (bitsPerSymbol - 1 - bit);
            double best0 = double.infinity;
            double best1 = double.infinity;
            foreach (p; points) {
                double d = (y - p.at).mag2();
                if ((p.bits & mask) != 0) {
                    if (d < best1) {
                        best1 = d;
                    }
                } else if (d < best0) {
                    best0 = d;
                }
            }
            llr[bit] = (best1 - best0) / nv;
        }
        return llr;
    }

    double averageEnergy() const {
        double e = 0;
        foreach (p; points) {
            e += p.at.mag2();
        }
        return e / cast(double) points.length;
    }
}

private int gray(int i) {
    return i ^ (i >> 1);
}

Constellation makePam(int bits, string name) {
    int m = 1 << bits;
    double energy = 0;
    double[] levels = new double[](m);
    foreach (i; 0 .. m) {
        levels[i] = cast(double) (2 * i - (m - 1));
        energy += levels[i] * levels[i];
    }
    double scale = 1.0 / sqrt(energy / m);
    auto c = Constellation(name, bits);
    foreach (i; 0 .. m) {
        c.points ~= Point(Complex!double(levels[i] * scale, 0), cast(uint) gray(i));
    }
    return c;
}

Constellation bpsk() {
    // Bit 0 sits at +1 so the ideal BPSK trial and this constellation agree.
    auto c = Constellation("bpsk", 1);
    c.points = [
        Point(Complex!double(1, 0), 0),
        Point(Complex!double(-1, 0), 1)
    ];
    return c;
}

Constellation qpsk() {
    // Two independent BPSK rails, Gray by construction: I is the high bit.
    auto c = Constellation("qpsk", 2);
    double s = 1.0 / sqrt(2.0);
    c.points = [
        Point(Complex!double(s, s), 0b00),
        Point(Complex!double(-s, s), 0b10),
        Point(Complex!double(s, -s), 0b01),
        Point(Complex!double(-s, -s), 0b11)
    ];
    return c;
}

Constellation psk(int bits) {
    if (bits == 1) {
        return bpsk();
    }
    if (bits == 2) {
        return qpsk();
    }
    int m = 1 << bits;
    auto c = Constellation("psk" ~ digits(m), bits);
    foreach (i; 0 .. m) {
        double ang = (2.0 * PI * i / m) + (bits > 2 ? PI / m : 0);
        uint label = cast(uint) gray(i);
        c.points ~= Point(Complex!double(cos(ang), sin(ang)), label);
    }
    return c;
}

Constellation qamSquare(int bitsPerRail) {
    int side = 1 << bitsPerRail;
    int bits = bitsPerRail * 2;
    double energy = 0;
    double[] levels = new double[](side);
    foreach (i; 0 .. side) {
        levels[i] = cast(double) (2 * i - (side - 1));
        energy += levels[i] * levels[i];
    }
    // Two rails, so average energy is twice the rail energy before scaling.
    double scale = 1.0 / sqrt(2.0 * energy / side);
    auto c = Constellation("qam" ~ digits(1 << bits), bits);
    foreach (iq; 0 .. side) {
        foreach (ii; 0 .. side) {
            uint label = (cast(uint) gray(ii) << bitsPerRail) | cast(uint) gray(iq);
            c.points ~= Point(Complex!double(levels[ii] * scale, levels[iq] * scale), label);
        }
    }
    return c;
}

Constellation qam16() {
    return qamSquare(2);
}

Constellation qam64() {
    return qamSquare(3);
}

private string digits(int n) {
    if (n == 0) {
        return "0";
    }
    char[] buf;
    int v = n;
    while (v > 0) {
        buf = cast(char) ('0' + (v % 10)) ~ buf;
        v /= 10;
    }
    return buf.idup;
}

bool labelsUnique(const Constellation c) {
    foreach (i, p; c.points) {
        foreach (j; i + 1 .. c.points.length) {
            if (c.points[j].bits == p.bits) {
                return false;
            }
        }
    }
    return true;
}

unittest {
    auto b = bpsk();
    assert(near(b.averageEnergy(), 1.0, 1e-12, 1e-12));
    double d2;
    assert(b.demap(b.map(0), d2) == 0);
    assert(b.demap(b.map(1), d2) == 1);
    auto q = qpsk();
    assert(near(q.averageEnergy(), 1.0, 1e-12, 1e-12));
    foreach (bits; 0 .. 4) {
        assert(q.demap(q.map(cast(uint) bits), d2) == bits);
        auto llr = q.softLlrs(q.map(cast(uint) bits), 0.05);
        foreach (bit, value; llr) {
            bool one = ((bits >> (1 - bit)) & 1) != 0;
            if (one) {
                assert(value < 0);
            } else {
                assert(value > 0);
            }
        }
    }
    auto q16 = qam16();
    assert(q16.points.length == 16);
    assert(labelsUnique(q16));
    assert(near(q16.averageEnergy(), 1.0, 1e-9, 1e-9));
    foreach (bits; 0 .. 16) {
        assert(q16.demap(q16.map(cast(uint) bits), d2) == bits);
    }
    auto q64 = qam64();
    assert(q64.points.length == 64);
    assert(near(q64.averageEnergy(), 1.0, 1e-9, 1e-9));
    assert(psk(3).points.length == 8);
    assert(near(psk(3).averageEnergy(), 1.0, 1e-12, 1e-12));
    auto soft = b.softLlrs(Complex!double(1, 0), 0.2);
    assert(soft[0] > 0);
}
