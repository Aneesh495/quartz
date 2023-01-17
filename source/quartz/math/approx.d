module quartz.math.approx;

import std.math : abs, isNaN;

// Absolute and relative closeness for floating comparisons in tests and in
// the fixed-point ledger. A pair matches when it clears either budget, so a
// true zero next to a roundoff residue still passes.

bool near(T)(T a, T b, T absTol, T relTol) {
    if (isNaN(a) || isNaN(b)) {
        return false;
    }
    T d = abs(a - b);
    if (d <= absTol) {
        return true;
    }
    T scale = abs(a) + abs(b);
    return d <= relTol * scale;
}

bool nearAbs(T)(T a, T b, T absTol) {
    return near(a, b, absTol, cast(T) 0);
}

unittest {
    assert(near(1.0, 1.0 + 1e-13, 1e-12, 0.0));
    assert(near(1e9, 1e9 + 2.0, 0.0, 1e-8));
    assert(!near(1.0, 1.2, 1e-9, 1e-9));
    assert(!near(double.nan, 1.0, 1.0, 1.0));
    assert(nearAbs(0.0, 1e-16, 1e-12));
}
