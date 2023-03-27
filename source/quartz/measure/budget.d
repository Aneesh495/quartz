module quartz.measure.budget;

import quartz.math.approx : near;
import quartz.units : db10, undb10;

// A one-way link budget in decibels. Thermal noise is kT times bandwidth,
// with T in kelvin and k the Boltzmann constant in joules per kelvin. The
// result is a received SNR, not a promise about a particular antenna.

@safe:

enum double boltzmann = 1.380649e-23;

struct LinkBudget {
    double txDbm;
    double gainDb;
    double pathLossDb;
    double noiseFigureDb;
    double bandwidthHz;
    double temperatureK = 290;

    double noiseDbm() const {
        double watts = boltzmann * temperatureK * bandwidthHz;
        return db10(watts) + 30.0 + noiseFigureDb;
    }

    double rxDbm() const {
        return txDbm + gainDb - pathLossDb;
    }

    double snrDb() const {
        return rxDbm() - noiseDbm();
    }
}

unittest {
    auto link = LinkBudget(0, 0, 0, 0, 1.0, 290);
    double expectedNoise = db10(boltzmann * 290.0) + 30.0;
    assert(near(link.noiseDbm(), expectedNoise, 1e-6, 1e-9));
    auto budget = LinkBudget(30, 10, 100, 5, 1e6, 290);
    assert(near(budget.rxDbm(), -60.0, 1e-12, 0.0));
    assert(budget.snrDb() == budget.rxDbm() - budget.noiseDbm());
    assert(undb10(0) == 1);
}
