module quartz.modem.linecode;

import quartz.error : QuartzError;

// Manchester and NRZ. Manchester puts a transition in the middle of every
// bit: zero is low then high, one is high then low. The decoder looks only
// at that pair, so a long run of identical bits still has a transition.

@safe:

bool[] manchesterEncode(const(bool)[] bits) {
    bool[] line = new bool[](bits.length * 2);
    foreach (i, bit; bits) {
        line[i * 2] = bit;
        line[i * 2 + 1] = !bit;
    }
    return line;
}

bool[] manchesterDecode(const(bool)[] line) {
    if ((line.length % 2) != 0) {
        throw new QuartzError("manchester line is not an even length");
    }
    bool[] bits = new bool[](line.length / 2);
    foreach (i; 0 .. bits.length) {
        bool first = line[i * 2];
        bool second = line[i * 2 + 1];
        if (first == second) {
            throw new QuartzError("manchester transition is missing");
        }
        bits[i] = first;
    }
    return bits;
}

bool[] nrzEncode(const(bool)[] bits) {
    return bits.dup;
}

unittest {
    bool[] bits = [true, true, false, true, false, false];
    assert(manchesterDecode(manchesterEncode(bits)) == bits);
    assert(nrzEncode(bits) == bits);
    bool bad = false;
    try {
        auto junk = manchesterDecode([true, true]);
        assert(junk.length == 0);
    } catch (QuartzError) {
        bad = true;
    }
    assert(bad);
}
