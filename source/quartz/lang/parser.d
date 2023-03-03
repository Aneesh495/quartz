module quartz.lang.parser;

import quartz.error : QuartzError;
import quartz.lang.lexer : Lexer, TokKind, Token, location;

// Recursive descent for one experiment. A block is either `code none;` or
// `modem qpsk { sps = 4; }`. Assignments are `key = value;`. Unknown shapes
// fail at the token that broke the grammar, with a line and a column.

@safe:

struct Assign {
    string key;
    Token value;
}

struct Block {
    string head;
    string label;
    Assign[] assigns;
    int line;
    int col;
}

struct ExperimentAst {
    string name;
    Assign[] assigns;
    Block[] blocks;
}

struct Parser {
    Lexer lexer;
    Token cur;

    this(string src) {
        lexer = Lexer(src);
        cur = lexer.next();
    }

    void bump() {
        cur = lexer.next();
    }

    void expect(TokKind kind, string what) {
        if (cur.kind != kind) {
            throw new QuartzError("expected " ~ what ~ " but found " ~ cur.text, location(cur.line, cur.col));
        }
    }

    ExperimentAst parseExperiment() {
        expect(TokKind.ident, "experiment");
        if (cur.text != "experiment") {
            throw new QuartzError("file must start with experiment", location(cur.line, cur.col));
        }
        bump();
        expect(TokKind.ident, "name");
        ExperimentAst ast;
        ast.name = cur.text;
        bump();
        expect(TokKind.lbrace, "{");
        bump();
        while (cur.kind != TokKind.rbrace && cur.kind != TokKind.eof) {
            parseItem(ast);
        }
        expect(TokKind.rbrace, "}");
        bump();
        if (cur.kind != TokKind.eof) {
            throw new QuartzError("trailing tokens after experiment", location(cur.line, cur.col));
        }
        return ast;
    }

    void parseItem(ref ExperimentAst ast) {
        expect(TokKind.ident, "key");
        string head = cur.text;
        int line = cur.line;
        int col = cur.col;
        bump();
        if (cur.kind == TokKind.equal) {
            bump();
            Token value = parseValue();
            expect(TokKind.semi, ";");
            bump();
            ast.assigns ~= Assign(head, value);
            return;
        }
        Block block;
        block.head = head;
        block.line = line;
        block.col = col;
        if (cur.kind == TokKind.ident) {
            block.label = cur.text;
            bump();
        }
        if (cur.kind == TokKind.semi) {
            bump();
            ast.blocks ~= block;
            return;
        }
        expect(TokKind.lbrace, "{");
        bump();
        while (cur.kind != TokKind.rbrace && cur.kind != TokKind.eof) {
            expect(TokKind.ident, "key");
            string key = cur.text;
            bump();
            expect(TokKind.equal, "=");
            bump();
            Token value = parseValue();
            expect(TokKind.semi, ";");
            bump();
            block.assigns ~= Assign(key, value);
        }
        expect(TokKind.rbrace, "}");
        bump();
        ast.blocks ~= block;
    }

    Token parseValue() {
        if (cur.kind == TokKind.number || cur.kind == TokKind.ident || cur.kind == TokKind.stringLit) {
            Token value = cur;
            bump();
            return value;
        }
        throw new QuartzError("expected a value", location(cur.line, cur.col));
    }
}

ExperimentAst parseSource(string src) {
    auto parser = Parser(src);
    return parser.parseExperiment();
}

unittest {
    auto ast = parseSource(`
        experiment hello {
          seed = 7;
          bits = 100;
          modem qpsk {
            sps = 4;
            pulse = rrc;
          }
          code none;
          channel awgn;
        }
    `);
    assert(ast.name == "hello");
    assert(ast.assigns.length == 2);
    assert(ast.blocks.length == 3);
    assert(ast.blocks[0].label == "qpsk");
    assert(ast.blocks[0].assigns[0].key == "sps");
    assert(ast.blocks[1].label == "none");
    assert(ast.blocks[1].assigns.length == 0);
    bool bad = false;
    try {
        auto junk = parseSource("experiment only");
        assert(junk.name.length == 0);
    } catch (QuartzError) {
        bad = true;
    }
    assert(bad);
}
