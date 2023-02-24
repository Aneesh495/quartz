module quartz.dsp.cordic;

import quartz.math.approx : near;
import std.math : PI, atan, cos, sin, sqrt;

// Circular CORDIC in vectoring and rotation modes. The gain is the product
// of the secants of the arctangents of 2^{-k} and is divided out so the
// result matches atan2 and cis, not the raw CORDIC magnitude.

@safe:

enum int cordicIters = 24;

double[cordicIters] cordicAngles() {
    double[cordicIters] table;
    foreach (k; 0 .. cordicIters) {
        table[k] = atan(1.0 / (2.0 ^^ k));
    }
    return table;
}

double cordicGain() {
    double g = 1;
    foreach (k; 0 .. cordicIters) {
        double d = 1.0 / (2.0 ^^ k);
        g *= sqrt(1.0 + d * d);
    }
    return g;
}

void cordicRotate(double theta, out double cosine, out double sine) {
    auto table = cordicAngles();
    double x = 1.0 / cordicGain();
    double y = 0;
    double z = theta;
    // Reduce to [-pi, pi] roughly by folding once into range the iterations cover.
    while (z > PI) {
        z -= 2 * PI;
    }
    while (z < -PI) {
        z += 2 * PI;
    }
    foreach (k, ang; table) {
        double x2 = x;
        double y2 = y;
        double shift = 1.0 / (2.0 ^^ k);
        if (z >= 0) {
            x = x2 - y2 * shift;
            y = y2 + x2 * shift;
            z -= ang;
        } else {
            x = x2 + y2 * shift;
            y = y2 - x2 * shift;
            z += ang;
        }
    }
    cosine = x;
    sine = y;
}

double cordicAtan2(double y, double x) {
    auto table = cordicAngles();
    double xx = x;
    double yy = y;
    double z = 0;
    bool flip = false;
    if (xx < 0) {
        xx = -xx;
        yy = -yy;
        flip = true;
    }
    foreach (k, ang; table) {
        double x2 = xx;
        double y2 = yy;
        double shift = 1.0 / (2.0 ^^ k);
        if (yy >= 0) {
            xx = x2 + y2 * shift;
            yy = y2 - x2 * shift;
            z += ang;
        } else {
            xx = x2 - y2 * shift;
            yy = y2 + x2 * shift;
            z -= ang;
        }
    }
    if (flip) {
        // Negating both components subtracted pi from the angle.
        if (y >= 0) {
            z = PI + z;
        } else {
            z = -PI + z;
        }
    }
    return z;
}

unittest {
    double c;
    double s;
    cordicRotate(0.7, c, s);
    assert(near(c, cos(0.7), 1e-6, 1e-6));
    assert(near(s, sin(0.7), 1e-6, 1e-6));
    cordicRotate(-1.2, c, s);
    assert(near(c, cos(-1.2), 1e-6, 1e-6));
    assert(near(s, sin(-1.2), 1e-6, 1e-6));
    assert(near(cordicAtan2(1, 1), PI / 4, 1e-6, 1e-6));
    assert(near(cordicAtan2(-1, 1), -PI / 4, 1e-6, 1e-6));
    assert(near(cordicAtan2(1, -1), 3 * PI / 4, 1e-5, 1e-5));
    assert(near(cordicAtan2(-1, -2), atan2Ref(-1, -2), 1e-5, 1e-5));
}

private double atan2Ref(double y, double x) {
    import std.math : atan2;
    return atan2(y, x);
}
