module quartz.lang.sema;

import quartz.error : QuartzError;
import quartz.lang.lexer : TokKind, location;
import quartz.lang.parser : Assign, Block, ExperimentAst, parseSource;
import quartz.sim.plan : ChannelKind, CodeKind, ExperimentPlan, ModemKind, PulseKind, parseChannel, parseCode, parseModem, parsePulse;

// Semantic check turns an experiment tree into a plan. Unknown keys are
// errors. A shorthand `channel awgn;` and a block `channel awgn { }` set the
// same field, so the two spellings cannot drift.

@safe:

ExperimentPlan lower(ExperimentAst ast) {
    ExperimentPlan plan;
    plan.name = ast.name;
    foreach (assign; ast.assigns) {
        applyTop(plan, assign);
    }
    foreach (block; ast.blocks) {
        applyBlock(plan, block);
    }
    if (plan.bits <= 0) {
        throw new QuartzError("bits must be positive");
    }
    if (plan.sps <= 0) {
        throw new QuartzError("sps must be positive");
    }
    if (plan.sampleRate <= 0) {
        throw new QuartzError("sample rate must be positive");
    }
    if (plan.beta < 0 || plan.beta > 1) {
        throw new QuartzError("rolloff beta must lie in [0, 1]");
    }
    return plan;
}

ExperimentPlan lowerSource(string src) {
    return lower(parseSource(src));
}

private void applyTop(ref ExperimentPlan plan, Assign assign) {
    string where = location(assign.value.line, assign.value.col);
    switch (assign.key) {
    case "seed":
        plan.seed = cast(ulong) needInt(assign, where);
        break;
    case "bits":
        plan.bits = cast(int) needInt(assign, where);
        break;
    case "ebn0_db":
        plan.ebn0Db = needNumber(assign);
        break;
    case "rate_hz":
        plan.sampleRate = needNumber(assign);
        break;
    case "name":
        plan.name = needString(assign);
        break;
    default:
        throw new QuartzError("unknown setting " ~ assign.key, where);
    }
}

private void applyBlock(ref ExperimentPlan plan, Block block) {
    string where = location(block.line, block.col);
    switch (block.head) {
    case "modem":
        if (block.label.length) {
            plan.modem = parseModem(block.label);
        }
        foreach (assign; block.assigns) {
            applyModem(plan, assign);
        }
        break;
    case "code":
        if (block.label.length) {
            plan.code = parseCode(block.label);
        }
        foreach (assign; block.assigns) {
            if (assign.key != "repeat") {
                throw new QuartzError("unknown code setting " ~ assign.key, location(assign.value.line, assign.value.col));
            }
            plan.repeat = cast(int) needInt(assign, location(assign.value.line, assign.value.col));
        }
        break;
    case "channel":
        if (block.label.length) {
            plan.channel = parseChannel(block.label);
        }
        foreach (assign; block.assigns) {
            if (assign.key == "crossover") {
                plan.crossover = needNumber(assign);
            } else if (assign.key == "ebn0_db") {
                plan.ebn0Db = needNumber(assign);
            } else {
                throw new QuartzError("unknown channel setting " ~ assign.key, location(assign.value.line, assign.value.col));
            }
        }
        break;
    case "impair":
        foreach (assign; block.assigns) {
            if (assign.key != "cfo_hz") {
                throw new QuartzError("unknown impairment " ~ assign.key, location(assign.value.line, assign.value.col));
            }
            plan.cfoHz = needNumber(assign);
        }
        break;
    case "ofdm":
        foreach (assign; block.assigns) {
            if (assign.key == "nfft") {
                plan.ofdmNfft = cast(int) needInt(assign, location(assign.value.line, assign.value.col));
            } else if (assign.key == "cp") {
                plan.ofdmCp = cast(int) needInt(assign, location(assign.value.line, assign.value.col));
            } else {
                throw new QuartzError("unknown ofdm setting " ~ assign.key, location(assign.value.line, assign.value.col));
            }
        }
        break;
    default:
        throw new QuartzError("unknown block " ~ block.head, where);
    }
}

private void applyModem(ref ExperimentPlan plan, Assign assign) {
    string where = location(assign.value.line, assign.value.col);
    switch (assign.key) {
    case "sps":
        plan.sps = cast(int) needInt(assign, where);
        break;
    case "pulse":
        plan.pulse = parsePulse(needIdent(assign));
        break;
    case "beta":
        plan.beta = needNumber(assign);
        break;
    case "span":
        plan.span = cast(int) needInt(assign, where);
        break;
    case "kind":
        plan.modem = parseModem(needIdent(assign));
        break;
    default:
        throw new QuartzError("unknown modem setting " ~ assign.key, where);
    }
}

private long needInt(Assign assign, string where) {
    if (assign.value.kind != TokKind.number || !assign.value.isInt) {
        throw new QuartzError(assign.key ~ " needs an integer", where);
    }
    return assign.value.ivalue;
}

private double needNumber(Assign assign) {
    if (assign.value.kind != TokKind.number) {
        throw new QuartzError(assign.key ~ " needs a number", location(assign.value.line, assign.value.col));
    }
    return assign.value.number;
}

private string needIdent(Assign assign) {
    if (assign.value.kind != TokKind.ident) {
        throw new QuartzError(assign.key ~ " needs a name", location(assign.value.line, assign.value.col));
    }
    return assign.value.text;
}

private string needString(Assign assign) {
    if (assign.value.kind == TokKind.stringLit || assign.value.kind == TokKind.ident) {
        return assign.value.text;
    }
    throw new QuartzError(assign.key ~ " needs text", location(assign.value.line, assign.value.col));
}

unittest {
    auto plan = lowerSource(`
        experiment bpsk_awgn {
          seed = 7;
          bits = 128;
          ebn0_db = 6.5;
          modem bpsk { sps = 1; pulse = rect; }
          code repetition { repeat = 5; }
          channel awgn;
        }
    `);
    assert(plan.name == "bpsk_awgn");
    assert(plan.seed == 7);
    assert(plan.bits == 128);
    assert(plan.ebn0Db > 6.4 && plan.ebn0Db < 6.6);
    assert(plan.modem == ModemKind.bpsk);
    assert(plan.pulse == PulseKind.rect);
    assert(plan.code == CodeKind.repetition);
    assert(plan.repeat == 5);
    assert(plan.channel == ChannelKind.awgn);
    bool bad = false;
    try {
        auto junk = lowerSource("experiment x { modem typo; }");
        assert(junk.bits == 0);
    } catch (QuartzError) {
        bad = true;
    }
    assert(bad);
}
