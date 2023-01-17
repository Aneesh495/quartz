module quartz.cli.app;

import std.stdio : stderr, writeln;

// Temporary driver. Later commits hang the real commands off this switch.
// Keeping a compiling entry point means every module unittest can run through
// Dub before the waveform path exists.

int classify(string[] args) {
    if (args.length <= 1 || args[1] == "help" || args[1] == "--help" || args[1] == "-h") {
        return 0;
    }
    return 2;
}

int runQuartz(string[] args) {
    int code = classify(args);
    if (code == 0) {
        writeln("quartz: a deterministic physical-layer laboratory");
        writeln("usage: quartz <command> [args]");
        writeln("commands: help");
        return 0;
    }
    stderr.writeln("unknown command: ", args[1]);
    return code;
}

unittest {
    assert(classify(["quartz", "help"]) == 0);
    assert(classify(["quartz"]) == 0);
    assert(classify(["quartz", "no-such"]) == 2);
}
