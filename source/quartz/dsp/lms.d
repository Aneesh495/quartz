module quartz.dsp.lms;

import quartz.math.approx : near;
import quartz.math.complex : Complex;

// Complex LMS. During training the error is the desired symbol minus the
// filter output. A short channel with a strong cursor is inverted well
// enough that a following block of decisions, using the trained taps on a
// noiseless repeat of the same channel, has no BPSK errors.

@safe:

struct Lms {
    Complex!double[] weights;
    Complex!double[] delay;
    int at;
    double mu;

    this(int taps, double mu) {
        weights = new Complex!double[](taps);
        delay = new Complex!double[](taps);
        foreach (ref w; weights) {
            w = Complex!double(0, 0);
        }
        foreach (ref d; delay) {
            d = Complex!double(0, 0);
        }
        if (taps > 0) {
            weights[taps / 2] = Complex!double(1, 0);
        }
        this.mu = mu;
    }

    Complex!double push(Complex!double x) {
        delay[at] = x;
        Complex!double y = Complex!double(0, 0);
        size_t idx = at;
        foreach (w; weights) {
            y = y + w * delay[idx];
            if (idx == 0) {
                idx = delay.length - 1;
            } else {
                idx--;
            }
        }
        at++;
        if (at == cast(int) delay.length) {
            at = 0;
        }
        return y;
    }

    Complex!double train(Complex!double x, Complex!double desired) {
        Complex!double y = push(x);
        Complex!double err = desired - y;
        size_t idx = at == 0 ? delay.length - 1 : at - 1;
        foreach (ref w; weights) {
            w = w + delay[idx].conj() * err * mu;
            if (idx == 0) {
                idx = delay.length - 1;
            } else {
                idx--;
            }
        }
        return y;
    }
}

Complex!double[] applyChannel(const(Complex!double)[] symbols, const(Complex!double)[] channel) {
    auto y = new Complex!double[](symbols.length);
    foreach (i, s; symbols) {
        Complex!double acc = Complex!double(0, 0);
        foreach (k, h; channel) {
            if (i >= k) {
                acc = acc + h * symbols[i - k];
            }
        }
        y[i] = acc;
    }
    return y;
}

unittest {
    Complex!double[] channel = [
        Complex!double(0.2, 0),
        Complex!double(1.0, 0),
        Complex!double(-0.3, 0)
    ];
    bool[] bits;
    foreach (i; 0 .. 1500) {
        bits ~= (i % 3) != 0;
    }
    auto symbols = new Complex!double[](bits.length);
    foreach (i, bit; bits) {
        symbols[i] = Complex!double(bit ? -1.0 : 1.0, 0);
    }
    auto received = applyChannel(symbols, channel);
    auto eq = Lms(5, 0.05);
    foreach (i; 0 .. 1200) {
        eq.train(received[i], symbols[i]);
    }
    int errors = 0;
    foreach (i; 1200 .. 1500) {
        auto y = eq.push(received[i]);
        bool hat = y.re < 0;
        if (hat != bits[i]) {
            errors++;
        }
    }
    assert(errors == 0);
    assert(near(eq.weights[2].re, eq.weights[2].re, 0, 0));
}
