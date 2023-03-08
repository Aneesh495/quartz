module quartz.cli.ber;

import quartz.lang.sema : lowerSource;
import quartz.sim.execute : execute;
import std.conv : to;
import std.file : readText;
import std.stdio : writeln;

int berCommand(string path, double from, double to, double step, int bits) {
    auto base = lowerSource(cast(string) readText(path));
    if (bits > 0) {
        base.bits = bits;
    }
    if (step <= 0) {
        step = 1;
    }
    writeln("ebn0_db  errors  bits  ber");
    for (double db = from; db <= to + step * 0.25; db += step) {
        auto plan = base;
        plan.ebn0Db = db;
        plan.channel = base.channel;
        auto report = execute(plan);
        writeln(db, "  ", report.bitErrors, "  ", report.infoBits, "  ", report.ber());
    }
    return 0;
}

unittest {
    import std.file : write;
    write("/tmp/quartz-ber.qz", "experiment b { seed = 1; bits = 200; ebn0_db = 8; modem bpsk { sps = 1; pulse = rect; } code none; channel awgn; }\n");
    assert(berCommand("/tmp/quartz-ber.qz", 30, 30, 1, 200) == 0);
}
