module quartz.error;

// One exception type for the laboratory. Callers that parse experiments,
// decode frames, or reject a singular matrix share the same failure path
// so the CLI can print a single line and return a nonzero status.

class QuartzError : Exception {
    string where;

    @safe this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
        this.where = "";
    }

    static QuartzError located(string where, string msg) {
        auto err = new QuartzError(msg);
        err.where = where;
        return err;
    }
}

string formatError(QuartzError err) {
    if (err.where.length == 0) {
        return err.msg;
    }
    return err.where ~ ": " ~ err.msg;
}

unittest {
    auto err = QuartzError.located("examples/a.qz:4", "unknown modem");
    assert(formatError(err) == "examples/a.qz:4: unknown modem");
    auto bare = new QuartzError("singular");
    assert(formatError(bare) == "singular");
}
