module quartz.cli.app;

import quartz.cli.ber : berCommand;
import quartz.cli.explain : explainCommand;
import quartz.cli.loopback : loopbackCommand;
import quartz.cli.run : runFile;
import quartz.cli.theory : theoryCommand;
import quartz.error : QuartzError, formatError;
import std.conv : to;
import std.stdio : stderr, writeln;

int runQuartz(string[] args) {
    try {
        return dispatch(args);
    } catch (QuartzError err) {
        stderr.writeln("quartz: ", formatError(err));
        return 1;
    }
}

int dispatch(string[] args) {
    if (args.length <= 1 || args[1] == "help" || args[1] == "--help" || args[1] == "-h") {
        writeHelp();
        return 0;
    }
    string cmd = args[1];
    if (cmd == "loopback") {
        return loopbackCommand();
    }
    if (cmd == "theory") {
        string modem = args.length > 2 ? args[2] : "bpsk";
        return theoryCommand(modem, option(args, "--ebn0", "0,4,8"));
    }
    if (cmd == "run") {
        if (args.length < 3) {
            stderr.writeln("usage: quartz run <file> [--out dir]");
            return 2;
        }
        return runFile(args[2], option(args, "--out", ""));
    }
    if (cmd == "explain") {
        if (args.length < 3) {
            stderr.writeln("usage: quartz explain <file>");
            return 2;
        }
        return explainCommand(args[2]);
    }
    if (cmd == "ber") {
        if (args.length < 3) {
            stderr.writeln("usage: quartz ber <file> --from a --to b --step s --bits n");
            return 2;
        }
        return berCommand(
            args[2],
            to!double(option(args, "--from", "0")),
            to!double(option(args, "--to", "8")),
            to!double(option(args, "--step", "2")),
            to!int(option(args, "--bits", "0"))
        );
    }
    stderr.writeln("unknown command: ", cmd);
    writeHelp();
    return 2;
}

void writeHelp() {
    writeln("quartz: a deterministic physical-layer laboratory");
    writeln("usage: quartz <command> [args]");
    writeln("commands:");
    writeln("  loopback                 run the built-in battery");
    writeln("  run <file> [--out dir]   execute an experiment");
    writeln("  explain <file>           print the lowered plan");
    writeln("  ber <file> --from --to --step --bits");
    writeln("  theory <modem> --ebn0 0,4,8");
}

string option(string[] args, string key, string fallback) {
    foreach (i, arg; args) {
        if (arg == key && i + 1 < args.length) {
            return args[i + 1];
        }
        if (arg.length > key.length && arg[0 .. key.length] == key && arg[key.length] == '=') {
            return arg[key.length + 1 .. $];
        }
    }
    return fallback;
}

unittest {
    assert(dispatch(["quartz", "help"]) == 0);
    assert(dispatch(["quartz", "no-such"]) == 2);
    assert(option(["quartz", "theory", "--ebn0", "1,2"], "--ebn0", "0") == "1,2");
    assert(option(["quartz", "--bits=9"], "--bits", "0") == "9");
}
