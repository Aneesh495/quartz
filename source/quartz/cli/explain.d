module quartz.cli.explain;

import quartz.lang.sema : lowerSource;
import quartz.sim.plan : channelName, codeName, modemName, pulseName;
import std.file : readText;
import std.stdio : writeln;

int explainCommand(string path) {
    auto plan = lowerSource(cast(string) readText(path));
    writeln("experiment ", plan.name);
    writeln("modem ", modemName(plan.modem), " pulse ", pulseName(plan.pulse), " sps ", plan.sps);
    writeln("code ", codeName(plan.code));
    writeln("channel ", channelName(plan.channel), " ebn0_db ", plan.ebn0Db);
    writeln("seed ", plan.seed, " bits ", plan.bits, " rate_hz ", plan.sampleRate);
    writeln("--- canonical ---");
    writeln(plan.canonical());
    return 0;
}
