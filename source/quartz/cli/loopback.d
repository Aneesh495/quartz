module quartz.cli.loopback;

import quartz.lang.sema : lowerSource;
import quartz.measure.theory : berBpsk, withinPoisson;
import quartz.sim.execute : execute;
import std.stdio : writeln;

// The battery a fresh clone should trust. Each line is a named check. A
// failure returns 1 so `make check` stops.

struct Check {
    string name;
    bool ok;
    string detail;
}

Check[] loopbackChecks() {
    Check[] checks;
    checks ~= runClean();
    checks ~= runTheory();
    checks ~= runShaped();
    checks ~= runOfdm();
    checks ~= runHamming();
    return checks;
}

int loopbackCommand() {
    auto checks = loopbackChecks();
    int failed = 0;
    foreach (check; checks) {
        if (check.ok) {
            writeln("PASS  ", check.name, "  ", check.detail);
        } else {
            writeln("FAIL  ", check.name, "  ", check.detail);
            failed++;
        }
    }
    if (failed == 0) {
        writeln("loopback ok");
        return 0;
    }
    writeln(failed, " checks failed");
    return 1;
}

private Check runClean() {
    auto plan = lowerSource(q"(
        experiment clean {
          seed = 1;
          bits = 1024;
          ebn0_db = 30;
          modem bpsk { sps = 1; pulse = rect; }
          code none;
          channel awgn;
        }
    )");
    auto report = execute(plan);
    Check check;
    check.name = "bpsk-clean";
    check.ok = report.bitErrors == 0;
    check.detail = "errors " ~ text(report.bitErrors);
    return check;
}

private Check runTheory() {
    auto plan = lowerSource(q"(
        experiment theory {
          seed = 11;
          bits = 12000;
          ebn0_db = 0;
          modem bpsk { sps = 1; pulse = rect; }
          code none;
          channel awgn;
        }
    )");
    auto report = execute(plan);
    Check check;
    check.name = "bpsk-0db";
    check.ok = withinPoisson(report.bitErrors, report.infoBits, berBpsk(0.0), 6.0);
    check.detail = "errors " ~ text(report.bitErrors) ~ " of " ~ text(report.infoBits);
    return check;
}

private Check runShaped() {
    auto plan = lowerSource(q"(
        experiment shaped {
          seed = 2;
          bits = 96;
          modem qpsk { sps = 4; pulse = rrc; beta = 0.25; span = 8; }
          code none;
          channel none;
        }
    )");
    auto report = execute(plan);
    Check check;
    check.name = "qpsk-rrc";
    check.ok = report.bitErrors == 0;
    check.detail = "errors " ~ text(report.bitErrors);
    return check;
}

private Check runOfdm() {
    auto plan = lowerSource(q"(
        experiment ofdm {
          seed = 4;
          bits = 208;
          modem ofdm_qpsk;
          code none;
          channel none;
        }
    )");
    auto report = execute(plan);
    Check check;
    check.name = "ofdm-qpsk";
    check.ok = report.bitErrors == 0;
    check.detail = "errors " ~ text(report.bitErrors);
    return check;
}

private Check runHamming() {
    auto plan = lowerSource(q"(
        experiment ham {
          seed = 6;
          bits = 80;
          modem bpsk { sps = 1; pulse = rect; }
          code hamming74;
          channel none;
        }
    )");
    auto report = execute(plan);
    Check check;
    check.name = "hamming74";
    check.ok = report.bitErrors == 0;
    check.detail = "errors " ~ text(report.bitErrors);
    return check;
}

private string text(int n) {
    import std.conv : to;
    return to!string(n);
}

unittest {
    auto checks = loopbackChecks();
    foreach (check; checks) {
        assert(check.ok, check.name ~ " " ~ check.detail);
    }
}
