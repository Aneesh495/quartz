module quartz.dsp.cic;

import quartz.math.approx : near;

// A cascaded integrator-comb decimator. The DC gain of an N-stage comb with
// rate change R and differential delay M is (R*M)^N. The test locks that
// gain and checks that a constant input decimates to a constant output.

@safe:

struct CicDecimator {
    int stages;
    int rate;
    int delay;
    double[] integ;
    double[] combPrev;
    double[] combState;
    int phase;

    this(int stages, int rate, int delay) {
        this.stages = stages;
        this.rate = rate;
        this.delay = delay < 1 ? 1 : delay;
        integ = new double[](stages);
        combPrev = new double[](stages);
        combState = new double[](stages);
        integ[] = 0;
        combPrev[] = 0;
        combState[] = 0;
    }

    double dcGain() const {
        double g = 1;
        foreach (_; 0 .. stages) {
            g *= rate * delay;
        }
        return g;
    }

    bool next(double x, out double y) {
        double v = x;
        foreach (ref acc; integ) {
            acc += v;
            v = acc;
        }
        phase++;
        if (phase < rate) {
            return false;
        }
        phase = 0;
        foreach (s; 0 .. stages) {
            double delayed = combState[s];
            combState[s] = v;
            double diff = v - delayed;
            v = diff;
        }
        y = v;
        return true;
    }
}

unittest {
    auto cic = CicDecimator(2, 4, 1);
    assert(near(cic.dcGain(), 16.0, 0.0, 0.0));
    int produced = 0;
    double last = 0;
    foreach (i; 0 .. 64) {
        double y;
        if (cic.next(1.0, y)) {
            produced++;
            last = y;
        }
    }
    assert(produced == 16);
    assert(near(last, cic.dcGain(), 1e-9, 1e-9));
}
