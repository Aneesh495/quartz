module quartz.io.wav;

import quartz.error : QuartzError;
import std.math : PI, sin;

// A minimal PCM WAV writer and reader. Samples are 16-bit little-endian
// mono. The laboratory uses it for a waveform you can open in any player,
// not as a general audio library.

struct Wav {
    int rate;
    short[] samples;
}

ubyte[] encodeWav(const(double)[] samples, int rate) {
    if (rate <= 0) {
        throw new QuartzError("wav sample rate must be positive");
    }
    short[] pcm = new short[](samples.length);
    foreach (i, x; samples) {
        double c = x;
        if (c > 1) {
            c = 1;
        }
        if (c < -1) {
            c = -1;
        }
        pcm[i] = cast(short) (c * 32767.0);
    }
    return encodePcm(pcm, rate);
}

ubyte[] encodePcm(const(short)[] samples, int rate) {
    uint dataBytes = cast(uint) samples.length * 2;
    uint riffSize = 36 + dataBytes;
    ubyte[] bytes;
    bytes ~= cast(ubyte[]) "RIFF";
    bytes ~= le32(riffSize);
    bytes ~= cast(ubyte[]) "WAVE";
    bytes ~= cast(ubyte[]) "fmt ";
    bytes ~= le32(16);
    bytes ~= le16(1);
    bytes ~= le16(1);
    bytes ~= le32(cast(uint) rate);
    bytes ~= le32(cast(uint) rate * 2);
    bytes ~= le16(2);
    bytes ~= le16(16);
    bytes ~= cast(ubyte[]) "data";
    bytes ~= le32(dataBytes);
    foreach (s; samples) {
        bytes ~= le16(cast(ushort) s);
    }
    return bytes;
}

Wav decodeWav(const(ubyte)[] bytes) {
    if (bytes.length < 44 || cast(string) bytes[0 .. 4] != "RIFF" || cast(string) bytes[8 .. 12] != "WAVE") {
        throw new QuartzError("wav header is not PCM");
    }
    int rate = cast(int) (bytes[24] | (bytes[25] << 8) | (bytes[26] << 16) | (bytes[27] << 24));
    int dataAt = 44;
    int dataBytes = cast(int) (bytes[40] | (bytes[41] << 8) | (bytes[42] << 16) | (bytes[43] << 24));
    if (dataAt + dataBytes > bytes.length) {
        throw new QuartzError("wav data overruns the file");
    }
    Wav wav;
    wav.rate = rate;
    wav.samples = new short[](dataBytes / 2);
    foreach (i; 0 .. wav.samples.length) {
        int o = dataAt + cast(int) i * 2;
        wav.samples[i] = cast(short) (bytes[o] | (bytes[o + 1] << 8));
    }
    return wav;
}

private ubyte[] le16(ushort v) {
    return [cast(ubyte) v, cast(ubyte) (v >> 8)];
}

private ubyte[] le32(uint v) {
    return [cast(ubyte) v, cast(ubyte) (v >> 8), cast(ubyte) (v >> 16), cast(ubyte) (v >> 24)];
}

unittest {
    double[] tone = new double[](32);
    foreach (i; 0 .. tone.length) {
        tone[i] = 0.5 * sin(2.0 * PI * i / 16.0);
    }
    auto back = decodeWav(encodeWav(tone, 8000));
    assert(back.rate == 8000);
    assert(back.samples.length == 32);
    assert(back.samples[0] == 0);
    assert(back.samples[4] > 10000);
    auto clipped = decodeWav(encodeWav([2.0, -2.0], 16000));
    assert(clipped.samples[0] == 32767);
    assert(clipped.samples[1] == -32767);
}
