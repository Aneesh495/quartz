module quartz.coding.convolutional;

import quartz.error : QuartzError;

// Rate 1/n feedforward convolutional encoder. Bit 0 of a polynomial is the
// current input and bit K-1 is the oldest memory tap. The NASA standard
// constraint-7 polynomials are 0o171 and 0o133 in this numbering.

@safe:

struct ConvSpec {
    int constraint;
    uint[] polys;

    int memory() const {
        return constraint - 1;
    }

    int outputs() const {
        return cast(int) polys.length;
    }
}

ConvSpec convNasa() {
    return ConvSpec(7, [0b1111001, 0b1011011]);
}

ConvSpec convExample() {
    return ConvSpec(3, [0b111, 0b101]);
}

bool[] convEncode(ConvSpec spec, const(bool)[] bits, bool terminate) {
    if (spec.constraint < 2 || spec.polys.length == 0) {
        throw new QuartzError("convolutional spec is empty");
    }
    int mem = spec.memory();
    bool[] state = new bool[](mem);
    bool[] encoded;
    void step(bool bit) {
        foreach (poly; spec.polys) {
            bool y = false;
            if ((poly & 1u) != 0 && bit) {
                y = !y;
            }
            foreach (i; 0 .. mem) {
                if (((poly >> (i + 1)) & 1u) != 0 && state[i]) {
                    y = !y;
                }
            }
            encoded ~= y;
        }
        if (mem > 0) {
            for (int i = mem - 1; i > 0; i--) {
                state[i] = state[i - 1];
            }
            state[0] = bit;
        }
    }
    foreach (bit; bits) {
        step(bit);
    }
    if (terminate) {
        foreach (_; 0 .. mem) {
            step(false);
        }
    }
    return encoded;
}

unittest {
    auto spec = convExample();
    bool[] msg = [true, false, true];
    auto coded = convEncode(spec, msg, false);
    assert(coded == [
        true, true,
        true, false,
        false, false
    ]);
    auto tail = convEncode(spec, msg, true);
    assert(tail.length == (msg.length + spec.memory()) * spec.outputs());
    auto nasa = convNasa();
    auto ncoded = convEncode(nasa, [true, true, false, true], true);
    assert(ncoded.length == (4 + 6) * 2);
    auto again = convEncode(nasa, [true, true, false, true], true);
    assert(again == ncoded);
}
