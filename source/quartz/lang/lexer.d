module quartz.lang.lexer;

import quartz.error : QuartzError;

// A small scanner for experiment files. Numbers may be integers or decimals.
// Identifiers are the modem names, the block names, and the keys. Strings
// exist so a payload can be written as text without leaving the language.

@safe:

enum TokKind {
    ident,
    number,
    stringLit,
    lbrace,
    rbrace,
    equal,
    semi,
    eof
}

struct Token {
    TokKind kind;
    string text;
    double number;
    bool isInt;
    long ivalue;
    int line;
    int col;
}

struct Lexer {
    string src;
    int index;
    int line = 1;
    int col = 1;

    this(string src) {
        this.src = src;
    }

    Token next() {
        skip();
        if (index >= src.length) {
            return Token(TokKind.eof, "", 0, false, 0, line, col);
        }
        int l = line;
        int c = col;
        char ch = src[index];
        if (ch == '{') {
            bump();
            return Token(TokKind.lbrace, "{", 0, false, 0, l, c);
        }
        if (ch == '}') {
            bump();
            return Token(TokKind.rbrace, "}", 0, false, 0, l, c);
        }
        if (ch == '=') {
            bump();
            return Token(TokKind.equal, "=", 0, false, 0, l, c);
        }
        if (ch == ';') {
            bump();
            return Token(TokKind.semi, ";", 0, false, 0, l, c);
        }
        if (ch == '"') {
            return stringAt(l, c);
        }
        if (isIdentStart(ch)) {
            return identAt(l, c);
        }
        if (ch == '-' || isDigit(ch)) {
            return numberAt(l, c);
        }
        throw new QuartzError("unexpected character", location(l, c));
    }

    private void skip() {
        while (index < src.length) {
            char ch = src[index];
            if (ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n') {
                bump();
                continue;
            }
            if (ch == '#') {
                while (index < src.length && src[index] != '\n') {
                    bump();
                }
                continue;
            }
            if (ch == '/' && index + 1 < src.length && src[index + 1] == '/') {
                while (index < src.length && src[index] != '\n') {
                    bump();
                }
                continue;
            }
            break;
        }
    }

    private Token identAt(int l, int c) {
        int start = index;
        bump();
        while (index < src.length && isIdentCont(src[index])) {
            bump();
        }
        return Token(TokKind.ident, src[start .. index], 0, false, 0, l, c);
    }

    private Token numberAt(int l, int c) {
        int start = index;
        if (src[index] == '-') {
            bump();
        }
        while (index < src.length && isDigit(src[index])) {
            bump();
        }
        bool isInt = true;
        if (index < src.length && src[index] == '.') {
            isInt = false;
            bump();
            while (index < src.length && isDigit(src[index])) {
                bump();
            }
        }
        string text = src[start .. index];
        if (text == "-" || text == "." || text == "-.") {
            throw new QuartzError("bad number", location(l, c));
        }
        double value = 0;
        long ivalue = 0;
        if (isInt) {
            ivalue = parseInt(text);
            value = cast(double) ivalue;
        } else {
            value = parseFloat(text);
        }
        return Token(TokKind.number, text, value, isInt, ivalue, l, c);
    }

    private Token stringAt(int l, int c) {
        bump();
        int start = index;
        while (index < src.length && src[index] != '"') {
            if (src[index] == '\n') {
                throw new QuartzError("unterminated string", location(l, c));
            }
            bump();
        }
        if (index >= src.length) {
            throw new QuartzError("unterminated string", location(l, c));
        }
        string text = src[start .. index];
        bump();
        return Token(TokKind.stringLit, text, 0, false, 0, l, c);
    }

    private void bump() {
        if (index < src.length && src[index] == '\n') {
            line++;
            col = 1;
        } else {
            col++;
        }
        index++;
    }
}

bool isDigit(char ch) {
    return ch >= '0' && ch <= '9';
}

bool isIdentStart(char ch) {
    return (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || ch == '_';
}

bool isIdentCont(char ch) {
    return isIdentStart(ch) || isDigit(ch);
}

long parseInt(string text) {
    long sign = 1;
    int i = 0;
    if (text.length > 0 && text[0] == '-') {
        sign = -1;
        i++;
    }
    long v = 0;
    for (; i < text.length; i++) {
        v = v * 10 + (text[i] - '0');
    }
    return v * sign;
}

double parseFloat(string text) {
    int sign = 1;
    int i = 0;
    if (text.length > 0 && text[0] == '-') {
        sign = -1;
        i++;
    }
    double v = 0;
    for (; i < text.length && text[i] != '.'; i++) {
        v = v * 10 + (text[i] - '0');
    }
    if (i < text.length && text[i] == '.') {
        i++;
        double place = 0.1;
        for (; i < text.length; i++) {
            v += (text[i] - '0') * place;
            place *= 0.1;
        }
    }
    return v * sign;
}

string location(int line, int col) {
    import std.conv : to;
    return to!string(line) ~ ":" ~ to!string(col);
}

unittest {
    auto lx = Lexer("experiment hi { seed = 7; ebn0_db = 6.5; name = \"x\"; }");
    assert(lx.next().text == "experiment");
    assert(lx.next().text == "hi");
    assert(lx.next().kind == TokKind.lbrace);
    assert(lx.next().text == "seed");
    assert(lx.next().kind == TokKind.equal);
    auto n = lx.next();
    assert(n.isInt && n.ivalue == 7);
    assert(lx.next().kind == TokKind.semi);
    assert(lx.next().text == "ebn0_db");
    lx.next();
    auto f = lx.next();
    assert(!f.isInt);
    assert(f.number > 6.4 && f.number < 6.6);
    lx.next();
    lx.next();
    lx.next();
    auto s = lx.next();
    assert(s.kind == TokKind.stringLit && s.text == "x");
    bool bad = false;
    try {
        auto boom = Lexer("seed = @;").next();
        auto second = Lexer("seed = @;").next();
        auto third = Lexer("@").next();
        assert(boom.kind == TokKind.ident);
        assert(second.kind == TokKind.ident);
        assert(third.kind == TokKind.eof);
    } catch (QuartzError) {
        bad = true;
    }
    assert(bad);
}
