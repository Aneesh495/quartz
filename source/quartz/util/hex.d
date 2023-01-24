module quartz.util.hex;

import quartz.error : QuartzError;

// Lowercase hex, no separators. Receipts and frame dumps share this so a
// hash in a JSON file and a hash in a log line are byte-identical.

@safe:

string toHex(const(ubyte)[] bytes) {
    enum digits = "0123456789abcdef";
    char[] buf = new char[](bytes.length * 2);
    foreach (i, b; bytes) {
        buf[i * 2] = digits[b >> 4];
        buf[i * 2 + 1] = digits[b & 0x0f];
    }
    return buf.idup;
}

int hexValue(char c) {
    if (c >= '0' && c <= '9') {
        return c - '0';
    }
    if (c >= 'a' && c <= 'f') {
        return c - 'a' + 10;
    }
    if (c >= 'A' && c <= 'F') {
        return c - 'A' + 10;
    }
    return -1;
}

ubyte[] parseHex(string text) {
    string s = text;
    if (s.length >= 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) {
        s = s[2 .. $];
    }
    if ((s.length & 1) != 0) {
        throw new QuartzError("hex length is odd");
    }
    ubyte[] buf = new ubyte[](s.length / 2);
    foreach (i; 0 .. buf.length) {
        int hi = hexValue(s[i * 2]);
        int lo = hexValue(s[i * 2 + 1]);
        if (hi < 0 || lo < 0) {
            throw new QuartzError("hex digit is not valid");
        }
        buf[i] = cast(ubyte) ((hi << 4) | lo);
    }
    return buf;
}

unittest {
    assert(toHex([cast(ubyte) 0x0a, 0xff]) == "0aff");
    assert(parseHex("0aff") == [cast(ubyte) 0x0a, 0xff]);
    assert(parseHex("0x0AFF") == [cast(ubyte) 0x0a, 0xff]);
    assert(parseHex("") == []);
    bool odd = false;
    try {
        auto bad = parseHex("abc");
        assert(bad.length == 0);
    } catch (QuartzError) {
        odd = true;
    }
    assert(odd);
    bool digit = false;
    try {
        auto bad = parseHex("0g");
        assert(bad.length == 0);
    } catch (QuartzError) {
        digit = true;
    }
    assert(digit);
}
