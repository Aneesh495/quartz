module quartz.util.sha256;

import quartz.math.approx : near;
import quartz.util.hex : toHex;

// SHA-256 (FIPS 180-4) with no library behind it. Experiment receipts hash
// the canonical plan text, so the digest has to travel with the source and
// stay stable across compilers.

@safe:

private uint rotr(uint x, uint n) {
    return (x >> n) | (x << (32 - n));
}

private uint loadBe(const(ubyte)[] block, size_t i) {
    return (cast(uint) block[i] << 24)
        | (cast(uint) block[i + 1] << 16)
        | (cast(uint) block[i + 2] << 8)
        | cast(uint) block[i + 3];
}

private void storeBe(uint x, ubyte[] dst, size_t i) {
    dst[i] = cast(ubyte) (x >> 24);
    dst[i + 1] = cast(ubyte) (x >> 16);
    dst[i + 2] = cast(ubyte) (x >> 8);
    dst[i + 3] = cast(ubyte) x;
}

private immutable uint[64] k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
];

private void compress(ref uint[8] state, const(ubyte)[] block) {
    uint[64] w;
    foreach (i; 0 .. 16) {
        w[i] = loadBe(block, i * 4);
    }
    foreach (i; 16 .. 64) {
        uint s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
        uint s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
        w[i] = w[i - 16] + s0 + w[i - 7] + s1;
    }
    uint a = state[0];
    uint b = state[1];
    uint c = state[2];
    uint d = state[3];
    uint e = state[4];
    uint f = state[5];
    uint g = state[6];
    uint h = state[7];
    foreach (i; 0 .. 64) {
        uint s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
        uint ch = (e & f) ^ ((~e) & g);
        uint t1 = h + s1 + ch + k[i] + w[i];
        uint s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
        uint maj = (a & b) ^ (a & c) ^ (b & c);
        uint t2 = s0 + maj;
        h = g;
        g = f;
        f = e;
        e = d + t1;
        d = c;
        c = b;
        b = a;
        a = t1 + t2;
    }
    state[0] += a;
    state[1] += b;
    state[2] += c;
    state[3] += d;
    state[4] += e;
    state[5] += f;
    state[6] += g;
    state[7] += h;
}

ubyte[32] sha256(const(ubyte)[] message) {
    uint[8] state = [
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
    ];
    ulong bitLen = message.length * 8UL;
    size_t off = 0;
    ubyte[64] block;
    while (message.length - off >= 64) {
        compress(state, message[off .. off + 64]);
        off += 64;
    }
    block[] = 0;
    size_t rem = message.length - off;
    block[0 .. rem] = message[off .. $];
    block[rem] = 0x80;
    if (rem >= 56) {
        compress(state, block);
        block[] = 0;
    }
    foreach (i; 0 .. 8) {
        block[63 - i] = cast(ubyte) (bitLen >> (8 * i));
    }
    compress(state, block);
    ubyte[32] dst;
    foreach (i; 0 .. 8) {
        storeBe(state[i], dst, i * 4);
    }
    return dst;
}

ubyte[32] sha256OfString(string text) {
    return sha256(cast(const(ubyte)[]) text);
}

string sha256Hex(const(ubyte)[] message) {
    return toHex(sha256(message));
}

string sha256HexString(string text) {
    return toHex(sha256OfString(text));
}

unittest {
    assert(sha256HexString("") ==
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");
    assert(sha256HexString("abc") ==
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
    assert(sha256HexString("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq") ==
        "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1");
    // Two equal messages, including one that crosses a block boundary, match.
    string longText = "quartz-";
    foreach (_; 0 .. 20) {
        longText ~= "sample-clock-";
    }
    assert(sha256HexString(longText) == sha256HexString(longText.idup));
    assert(near(cast(double) sha256(cast(const(ubyte)[]) "").length, 32.0, 0.0, 0.0));
}
