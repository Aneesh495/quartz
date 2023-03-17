module quartz.frame.whiten;

import quartz.coding.scramble : scramble;

// The 802.11-shaped whitener: polynomial x^7 + x^4 + 1, seed 0x7f, width 7.
// It is the additive scrambler already in the coding layer, with the
// polynomial written out so a frame and a modem call the same sequence.

@safe:

enum uint whitenPoly = 0b1001000;
enum uint whitenSeed = 0x7f;
enum int whitenWidth = 7;

bool[] whiten(const(bool)[] bits) {
    return scramble(bits, whitenPoly, whitenSeed, whitenWidth);
}

unittest {
    bool[] payload = [true, false, true, true, false, true, false, false, true];
    auto mixed = whiten(payload);
    assert(mixed != payload);
    assert(whiten(mixed) == payload);
}
