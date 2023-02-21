module quartz.dsp.window;

import quartz.math.approx : near;
import quartz.math.special : besselI0;
import std.math : PI, cos, sin, sqrt;

// Windows for FIR design and for the Welch spectral estimate. The Kaiser
// window is the one the equiripple-ish designs use; its shape is I0 of a
// scaled radius over I0 of the shape parameter.

@safe:

enum WindowKind {
    rectangular,
    hann,
    hamming,
    blackman,
    bartlett,
    kaiser
}

double[] rectangular(int n) {
    double[] w = new double[](n);
    w[] = 1;
    return w;
}

double[] hann(int n) {
    double[] w = new double[](n);
    if (n == 1) {
        w[0] = 1;
        return w;
    }
    foreach (i; 0 .. n) {
        w[i] = 0.5 - 0.5 * cos(2.0 * PI * i / (n - 1));
    }
    return w;
}

double[] hamming(int n) {
    double[] w = new double[](n);
    if (n == 1) {
        w[0] = 1;
        return w;
    }
    foreach (i; 0 .. n) {
        w[i] = 0.54 - 0.46 * cos(2.0 * PI * i / (n - 1));
    }
    return w;
}

double[] blackman(int n) {
    double[] w = new double[](n);
    if (n == 1) {
        w[0] = 1;
        return w;
    }
    foreach (i; 0 .. n) {
        double t = 2.0 * PI * i / (n - 1);
        w[i] = 0.42 - 0.5 * cos(t) + 0.08 * cos(2.0 * t);
    }
    return w;
}

double[] bartlett(int n) {
    double[] w = new double[](n);
    if (n == 1) {
        w[0] = 1;
        return w;
    }
    double mid = (n - 1) / 2.0;
    foreach (i; 0 .. n) {
        double dist = cast(double) i - mid;
        if (dist < 0) {
            dist = -dist;
        }
        w[i] = 1.0 - dist / mid;
    }
    return w;
}

double[] kaiser(int n, double beta) {
    double[] w = new double[](n);
    if (n == 1) {
        w[0] = 1;
        return w;
    }
    double denom = besselI0(beta);
    double alpha = (n - 1) / 2.0;
    foreach (i; 0 .. n) {
        double r = (i - alpha) / alpha;
        double inside = 1.0 - r * r;
        if (inside < 0) {
            inside = 0;
        }
        w[i] = besselI0(beta * sqrt(inside)) / denom;
    }
    return w;
}

double[] windowByKind(WindowKind kind, int n, double beta = 6.0) {
    final switch (kind) {
    case WindowKind.rectangular:
        return rectangular(n);
    case WindowKind.hann:
        return hann(n);
    case WindowKind.hamming:
        return hamming(n);
    case WindowKind.blackman:
        return blackman(n);
    case WindowKind.bartlett:
        return bartlett(n);
    case WindowKind.kaiser:
        return kaiser(n, beta);
    }
}

bool symmetric(const(double)[] w, double tol) {
    foreach (i; 0 .. w.length / 2) {
        if (!near(w[i], w[$ - 1 - i], tol, tol)) {
            return false;
        }
    }
    return true;
}

unittest {
    auto h = hann(17);
    assert(symmetric(h, 1e-12));
    assert(near(h[0], 0.0, 1e-12, 0.0));
    assert(near(h[8], 1.0, 1e-12, 1e-12));
    auto hm = hamming(16);
    assert(symmetric(hm, 1e-12));
    assert(hm[0] > 0.05 && hm[0] < 0.1);
    auto b = blackman(21);
    assert(symmetric(b, 1e-12));
    assert(near(b[10], 1.0, 1e-9, 1e-9));
    auto k = kaiser(15, 0.0);
    foreach (v; k) {
        assert(near(v, 1.0, 1e-9, 1e-9));
    }
    auto k6 = kaiser(31, 6.0);
    assert(symmetric(k6, 1e-12));
    assert(k6[15] > k6[0]);
    auto tri = bartlett(5);
    assert(near(tri[0], 0.0, 1e-12, 0.0));
    assert(near(tri[2], 1.0, 1e-12, 1e-12));
    assert(windowByKind(WindowKind.rectangular, 4).length == 4);
}
