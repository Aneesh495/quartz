module quartz.cli.run;

import quartz.error : QuartzError, formatError;
import quartz.lang.sema : lowerSource;
import quartz.sim.execute : execute;
import quartz.sim.receipt : receiptFor;
import std.file : exists, mkdirRecurse, readText, write;
import std.stdio : writeln;

int runFile(string path, string outDir) {
    if (!exists(path)) {
        throw new QuartzError("experiment not found: " ~ path);
    }
    auto plan = lowerSource(cast(string) readText(path));
    auto report = execute(plan);
    auto receipt = receiptFor(plan, report);
    writeln(plan.name, "  bits ", report.infoBits, "  errors ", report.bitErrors, "  ber ", report.ber());
    if (outDir.length) {
        mkdirRecurse(outDir);
        write(outDir ~ "/receipt.json", receipt.toJson());
        write(outDir ~ "/plan.txt", plan.canonical());
    }
    return 0;
}

unittest {
    import std.file : rmdirRecurse;
    string src = "experiment unit {\n  seed = 1;\n  bits = 32;\n  ebn0_db = 40;\n  modem bpsk { sps = 1; pulse = rect; }\n  code none;\n  channel awgn;\n}\n";
    write("/tmp/quartz-unit.qz", src);
    assert(runFile("/tmp/quartz-unit.qz", "/tmp/quartz-unit-out") == 0);
    assert(exists("/tmp/quartz-unit-out/receipt.json"));
}
