module quartz.frame.packet;

import quartz.coding.crc : crc32Of;
import quartz.error : QuartzError;
import quartz.util.hex : toHex;

// A byte frame: a fixed preamble, a 16-bit length, the payload, and CRC-32
// over the length and the payload. The parser refuses a bad CRC instead of
// returning a payload that only looks plausible.

@safe:

enum uint framePreamble = 0xA53CF0E1;

struct Frame {
    ubyte[] payload;
    uint crc;
}

ubyte[] buildFrame(const(ubyte)[] payload) {
    if (payload.length > 65535) {
        throw new QuartzError("frame payload is too long");
    }
    ubyte[] body = new ubyte[](2 + payload.length);
    body[0] = cast(ubyte) (payload.length >> 8);
    body[1] = cast(ubyte) payload.length;
    body[2 .. $] = payload;
    uint crc = cast(uint) crc32Of(body);
    ubyte[] frame = new ubyte[](4 + body.length + 4);
    frame[0] = cast(ubyte) (framePreamble >> 24);
    frame[1] = cast(ubyte) (framePreamble >> 16);
    frame[2] = cast(ubyte) (framePreamble >> 8);
    frame[3] = cast(ubyte) framePreamble;
    frame[4 .. 4 + body.length] = body;
    frame[4 + body.length] = cast(ubyte) (crc >> 24);
    frame[5 + body.length] = cast(ubyte) (crc >> 16);
    frame[6 + body.length] = cast(ubyte) (crc >> 8);
    frame[7 + body.length] = cast(ubyte) crc;
    return frame;
}

Frame parseFrame(const(ubyte)[] bytes) {
    if (bytes.length < 10) {
        throw new QuartzError("frame is short");
    }
    uint pre = (cast(uint) bytes[0] << 24) | (cast(uint) bytes[1] << 16) | (cast(uint) bytes[2] << 8) | bytes[3];
    if (pre != framePreamble) {
        throw new QuartzError("frame preamble mismatch");
    }
    int length = (bytes[4] << 8) | bytes[5];
    if (bytes.length < 10 + length) {
        throw new QuartzError("frame length exceeds the buffer");
    }
    ubyte[] body = bytes[4 .. 6 + length].dup;
    uint expect = cast(uint) crc32Of(body);
    size_t at = 6 + length;
    uint got = (cast(uint) bytes[at] << 24) | (cast(uint) bytes[at + 1] << 16) | (cast(uint) bytes[at + 2] << 8) | bytes[at + 3];
    if (got != expect) {
        throw new QuartzError("frame crc mismatch");
    }
    Frame frame;
    frame.payload = bytes[6 .. 6 + length].dup;
    frame.crc = got;
    return frame;
}

unittest {
    ubyte[] payload = [1, 2, 3, 9, 255];
    auto frame = buildFrame(payload);
    auto parsed = parseFrame(frame);
    assert(parsed.payload == payload);
    frame[8] ^= 0x01;
    bool bad = false;
    try {
        auto junk = parseFrame(frame);
        assert(junk.payload.length == 0);
    } catch (QuartzError) {
        bad = true;
    }
    assert(bad);
    assert(toHex(buildFrame([])[0 .. 4]) == "a53cf0e1");
}
