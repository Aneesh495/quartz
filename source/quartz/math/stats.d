module quartz.math.stats;

import quartz.math.approx : near;
import std.algorithm : sort;
import std.math : floor, sqrt;

// One-pass mean and variance (Welford) plus a two-pass moment check.
// BER ledgers and AGC meters both need a variance that does not overflow
// when the sample counter gets large.

@safe:

struct RunningMoments {
    long count = 0;
    double mean = 0;
    double m2 = 0;
    double minValue = 0;
    double maxValue = 0;

    void reset() {
        count = 0;
        mean = 0;
        m2 = 0;
        minValue = 0;
        maxValue = 0;
    }

    void add(double x) {
        count++;
        if (count == 1) {
            minValue = x;
            maxValue = x;
        } else {
            if (x < minValue) {
                minValue = x;
            }
            if (x > maxValue) {
                maxValue = x;
            }
        }
        double delta = x - mean;
        mean += delta / cast(double) count;
        double delta2 = x - mean;
        m2 += delta * delta2;
    }

    void addAll(const(double)[] xs) {
        foreach (x; xs) {
            add(x);
        }
    }

    double populationVariance() const {
        if (count <= 0) {
            return 0;
        }
        return m2 / cast(double) count;
    }

    double sampleVariance() const {
        if (count <= 1) {
            return 0;
        }
        return m2 / cast(double) (count - 1);
    }

    double stddev() const {
        return sqrt(sampleVariance());
    }
}

struct TwoPassMoments {
    double mean;
    double variance;
    double skewness;
    double excessKurtosis;
    long count;
}

TwoPassMoments twoPass(const(double)[] xs) {
    TwoPassMoments m;
    m.count = cast(long) xs.length;
    if (xs.length == 0) {
        return m;
    }
    double sum = 0;
    foreach (x; xs) {
        sum += x;
    }
    m.mean = sum / cast(double) xs.length;
    double m2 = 0;
    double m3 = 0;
    double m4 = 0;
    foreach (x; xs) {
        double d = x - m.mean;
        double d2 = d * d;
        m2 += d2;
        m3 += d2 * d;
        m4 += d2 * d2;
    }
    m.variance = m2 / cast(double) xs.length;
    if (m2 == 0) {
        m.skewness = 0;
        m.excessKurtosis = 0;
        return m;
    }
    double n = cast(double) xs.length;
    m.skewness = (m3 / n) / (sqrt(m.variance) ^^ 3);
    double kurt = (m4 / n) / (m.variance * m.variance);
    m.excessKurtosis = kurt - 3.0;
    return m;
}

double quantile(double[] xs, double p) {
    if (xs.length == 0) {
        return 0;
    }
    if (p < 0) {
        p = 0;
    }
    if (p > 1) {
        p = 1;
    }
    auto copy = xs.dup;
    sort(copy);
    if (copy.length == 1) {
        return copy[0];
    }
    double idx = p * cast(double) (copy.length - 1);
    size_t i = cast(size_t) floor(idx);
    double frac = idx - cast(double) i;
    if (i + 1 >= copy.length) {
        return copy[$ - 1];
    }
    return copy[i] * (1.0 - frac) + copy[i + 1] * frac;
}

double[] autocorrelation(const(double)[] x, size_t maxLag) {
    double[] r = new double[](maxLag + 1);
    if (x.length == 0) {
        return r;
    }
    double n = cast(double) x.length;
    foreach (lag; 0 .. maxLag + 1) {
        double s = 0;
        if (lag >= x.length) {
            r[lag] = 0;
            continue;
        }
        foreach (i; 0 .. x.length - lag) {
            s += x[i] * x[i + lag];
        }
        r[lag] = s / n;
    }
    return r;
}

struct Histogram {
    double lo;
    double hi;
    size_t[] bins;
    size_t under = 0;
    size_t over = 0;
    size_t total = 0;

    this(double lo, double hi, size_t nbins) {
        this.lo = lo;
        this.hi = hi;
        this.bins = new size_t[](nbins);
    }

    void add(double x) {
        total++;
        if (x < lo) {
            under++;
            return;
        }
        if (x >= hi) {
            over++;
            return;
        }
        double u = (x - lo) / (hi - lo);
        size_t i = cast(size_t) (u * cast(double) bins.length);
        if (i >= bins.length) {
            i = bins.length - 1;
        }
        bins[i]++;
    }
}

unittest {
    double[] xs = [1, 2, 3, 4, 5];
    RunningMoments run;
    run.addAll(xs);
    assert(run.count == 5);
    assert(near(run.mean, 3.0, 1e-12, 1e-12));
    assert(near(run.populationVariance(), 2.0, 1e-12, 1e-12));
    assert(near(run.sampleVariance(), 2.5, 1e-12, 1e-12));
    assert(near(run.minValue, 1.0, 0.0, 0.0));
    assert(near(run.maxValue, 5.0, 0.0, 0.0));
    auto two = twoPass(xs);
    assert(near(two.mean, run.mean, 1e-12, 1e-12));
    assert(near(two.variance, run.populationVariance(), 1e-12, 1e-12));
    assert(near(two.skewness, 0.0, 1e-12, 1e-12));
    assert(near(quantile(xs, 0.0), 1.0, 0.0, 0.0));
    assert(near(quantile(xs, 1.0), 5.0, 0.0, 0.0));
    assert(near(quantile([1.0, 2, 3, 4], 0.5), 2.5, 1e-12, 1e-12));
    auto ac = autocorrelation([1.0, 0, 0, 0], 3);
    assert(near(ac[0], 0.25, 1e-12, 1e-12));
    assert(near(ac[1], 0.0, 1e-12, 0.0));
    auto hist = Histogram(0.0, 1.0, 4);
    hist.add(-1);
    hist.add(0.1);
    hist.add(0.9);
    hist.add(2);
    assert(hist.under == 1);
    assert(hist.over == 1);
    assert(hist.total == 4);
    assert(hist.bins[0] == 1);
    assert(hist.bins[3] == 1);
}
