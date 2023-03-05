module quartz.sim.receipt;

import quartz.meta : quartzVersion;
import quartz.sim.execute : SimReport;
import quartz.sim.plan : ExperimentPlan;
import quartz.util.sha256 : sha256HexString;
import std.conv : to;

// A receipt is the thing you keep. It names the plan hash, the seed, and the
// error count. Two runs with the same source and the same binary produce the
// same text.

@safe:

struct Receipt {
    string name;
    ulong seed;
    int infoBits;
    int bitErrors;
    int codedBits;
    double ebn0Db;
    string planSha256;
    string labVersion;

    string toJson() const {
        return "{\n"
            ~ "  \"name\": \"" ~ jsonEscape(name) ~ "\",\n"
            ~ "  \"version\": \"" ~ jsonEscape(labVersion) ~ "\",\n"
            ~ "  \"seed\": " ~ to!string(seed) ~ ",\n"
            ~ "  \"ebn0_db\": " ~ to!string(ebn0Db) ~ ",\n"
            ~ "  \"info_bits\": " ~ to!string(infoBits) ~ ",\n"
            ~ "  \"coded_bits\": " ~ to!string(codedBits) ~ ",\n"
            ~ "  \"bit_errors\": " ~ to!string(bitErrors) ~ ",\n"
            ~ "  \"ber\": " ~ to!string(ber()) ~ ",\n"
            ~ "  \"plan_sha256\": \"" ~ planSha256 ~ "\"\n"
            ~ "}\n";
    }

    double ber() const {
        if (infoBits <= 0) {
            return 0;
        }
        return cast(double) bitErrors / cast(double) infoBits;
    }
}

Receipt receiptFor(ExperimentPlan plan, SimReport report) {
    Receipt receipt;
    receipt.name = plan.name;
    receipt.seed = plan.seed;
    receipt.infoBits = report.infoBits;
    receipt.bitErrors = report.bitErrors;
    receipt.codedBits = report.codedBits;
    receipt.ebn0Db = plan.ebn0Db;
    receipt.planSha256 = sha256HexString(plan.canonical());
    receipt.labVersion = quartzVersion;
    return receipt;
}

string jsonEscape(string text) {
    char[] buf;
    foreach (ch; text) {
        if (ch == '\\' || ch == '"') {
            buf ~= '\\';
        }
        buf ~= ch;
    }
    return buf.idup;
}

unittest {
    ExperimentPlan plan;
    plan.name = "quote\"x";
    plan.seed = 4;
    SimReport report;
    report.infoBits = 10;
    report.bitErrors = 1;
    report.codedBits = 10;
    auto receipt = receiptFor(plan, report);
    assert(receipt.ber() == 0.1);
    assert(receipt.toJson().length > 0);
    string escaped = jsonEscape("a\"b\\c");
    assert(escaped == "a\\\"b\\\\c");
    auto again = receiptFor(plan, report);
    assert(again.planSha256 == receipt.planSha256);
}
