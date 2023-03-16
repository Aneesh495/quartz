module quartz.frame.hdlc;

import quartz.error : QuartzError;

// HDLC bit stuffing. A flag is 01111110. Five one-bits in the payload are
// followed by a stuffed zero. The unstuffer removes that zero and refuses a
// frame that never closes.

@safe:

bool[] flagBits() {
    return [false, true, true, true, true, true, true, false];
}

bool[] hdlcStuff(const(bool)[] payload) {
    bool[] flag = flagBits();
    bool[] body;
    int ones = 0;
    foreach (bit; payload) {
        body ~= bit;
        if (bit) {
            ones++;
            if (ones == 5) {
                body ~= false;
                ones = 0;
            }
        } else {
            ones = 0;
        }
    }
    return flag ~ body ~ flag;
}

bool[] hdlcUnstuff(const(bool)[] frame) {
    bool[] flag = flagBits();
    int open = findFlag(frame, 0);
    if (open < 0) {
        throw new QuartzError("hdlc opening flag mismatch");
    }
    int close = findFlag(frame, open + flag.length);
    if (close < 0) {
        throw new QuartzError("hdlc frame did not close");
    }
    bool[] body = frame[open + flag.length .. close].dup;
    bool[] payload;
    int ones = 0;
    foreach (bit; body) {
        if (ones == 5) {
            ones = 0;
            continue;
        }
        payload ~= bit;
        ones = bit ? ones + 1 : 0;
    }
    return payload;
}

int findFlag(const(bool)[] frame, size_t start) {
    bool[] flag = flagBits();
    if (start >= frame.length) {
        return -1;
    }
    foreach (i; start .. frame.length - flag.length + 1) {
        bool match = true;
        foreach (k; 0 .. flag.length) {
            if (frame[i + k] != flag[k]) {
                match = false;
            }
        }
        if (match) {
            return cast(int) i;
        }
    }
    return -1;
}

unittest {
    bool[] payload = [true, true, true, true, true, true, true, false, true];
    auto frame = hdlcStuff(payload);
    assert(hdlcUnstuff(frame) == payload);
    bool[] zeros = new bool[](20);
    assert(hdlcUnstuff(hdlcStuff(zeros)) == zeros);
    bool[] ones = new bool[](16);
    ones[] = true;
    assert(hdlcUnstuff(hdlcStuff(ones)) == ones);
}
