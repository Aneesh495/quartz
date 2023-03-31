module quartz.io.cfile;

import quartz.error : QuartzError;
import quartz.math.approx : near;
import quartz.math.complex : Complex;
import std.bitmanip : littleEndianToNative, nativeToLittleEndian;

// Interleaved little-endian complex float, the layout used by a lot of
// baseband captures. One complex sample is eight bytes: real, then imag.

ubyte[] encodeCfile(const(Complex!double)[] samples) {
    ubyte[] bytes = new ubyte[](samples.length * 8);
    foreach (i, s; samples) {
        float re = cast(float) s.re;
        float im = cast(float) s.im;
        store(bytes, i * 8, re);
        store(bytes, i * 8 + 4, im);
    }
    return bytes;
}

Complex!double[] decodeCfile(const(ubyte)[] bytes) {
    if ((bytes.length % 8) != 0) {
        throw new QuartzError("cfile length is not a multiple of 8");
    }
    auto samples = new Complex!double[](bytes.length / 8);
    foreach (i; 0 .. samples.length) {
        samples[i] = Complex!double(load(bytes, i * 8), load(bytes, i * 8 + 4));
    }
    return samples;
}

private void store(ubyte[] bytes, size_t at, float value) {
    ubyte[4] raw = nativeToLittleEndian(value);
    bytes[at .. at + 4] = raw[];
}

private float load(const(ubyte)[] bytes, size_t at) {
    ubyte[4] raw = bytes[at .. at + 4];
    return littleEndianToNative!float(raw);
}

unittest {
    Complex!double[] samples = [Complex!double(0.5, -0.25), Complex!double(1, 0)];
    auto back = decodeCfile(encodeCfile(samples));
    assert(back.length == 2);
    assert(near(back[0].re, 0.5, 1e-6, 1e-6));
    assert(near(back[0].im, -0.25, 1e-6, 1e-6));
    assert(near(back[1].re, 1.0, 1e-6, 1e-6));
}
