module quartz.cli.theory;

import quartz.measure.theory : awgnCapacity, berBpsk, berBpskRayleigh, berQam16, berQpsk;
import quartz.units : undb10;
import std.conv : to;
import std.stdio : writeln;
import std.string : split;

int theoryCommand(string modem, string list) {
    double[] points = parseList(list);
    writeln("ebn0_db  ber  capacity_bpsk_snr");
    foreach (db; points) {
        double ber = theoryBer(modem, db);
        double snr = undb10(db);
        writeln(db, "  ", ber, "  ", awgnCapacity(snr));
    }
    return 0;
}

double theoryBer(string modem, double db) {
    switch (modem) {
    case "bpsk":
        return berBpsk(db);
    case "qpsk":
        return berQpsk(db);
    case "qam16":
        return berQam16(db);
    case "bpsk_rayleigh":
        return berBpskRayleigh(db);
    default:
        return berBpsk(db);
    }
}

double[] parseList(string list) {
    if (list.length == 0) {
        return [0, 2, 4, 6, 8];
    }
    double[] values;
    foreach (part; split(list, ",")) {
        if (part.length == 0) {
            continue;
        }
        values ~= to!double(part);
    }
    return values;
}

unittest {
    assert(theoryBer("bpsk", 0) > 0.07 && theoryBer("bpsk", 0) < 0.08);
    assert(parseList("0,4,8").length == 3);
}
