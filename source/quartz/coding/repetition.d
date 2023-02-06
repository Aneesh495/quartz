module quartz.coding.repetition;

import quartz.error : QuartzError;

// Repetition is the control case for the coded BER curves. Majority vote on
// an odd length is unambiguous. Even lengths break ties toward zero.

@safe:

bool[] repetitionEncode(const(bool)[] bits, int repeat) {
    if (repeat <= 0) {
        throw new QuartzError("repetition count must be positive");
    }
    bool[] coded = new bool[](bits.length * repeat);
    foreach (i, bit; bits) {
        foreach (r; 0 .. repeat) {
            coded[i * repeat + r] = bit;
        }
    }
    return coded;
}

bool[] repetitionDecode(const(bool)[] coded, int repeat) {
    if (repeat <= 0 || (coded.length % repeat) != 0) {
        throw new QuartzError("repetition block is not an integer number of copies");
    }
    bool[] bits = new bool[](coded.length / repeat);
    foreach (i; 0 .. bits.length) {
        int ones = 0;
        foreach (r; 0 .. repeat) {
            if (coded[i * repeat + r]) {
                ones++;
            }
        }
        bits[i] = ones * 2 > repeat;
    }
    return bits;
}

unittest {
    bool[] msg = [true, false, true, true, false];
    auto coded = repetitionEncode(msg, 3);
    assert(coded.length == 15);
    assert(repetitionDecode(coded, 3) == msg);
    coded[1] = false;
    coded[3] = true;
    coded[6] = false;
    assert(repetitionDecode(coded, 3) == msg);
    assert(repetitionDecode(repetitionEncode(msg, 1), 1) == msg);
}
