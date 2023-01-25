module quartz.util.fnv;

// FNV-1a 64. Used for schedule fingerprints where a cryptographic digest is
// heavier than the thing being named. Receipts still use SHA-256.

@safe:

enum ulong fnvOffset = 14695981039346656037UL;
enum ulong fnvPrime = 1099511628211UL;

ulong fnv1a64(const(ubyte)[] data) {
    ulong h = fnvOffset;
    foreach (b; data) {
        h ^= b;
        h *= fnvPrime;
    }
    return h;
}

ulong fnv1a64String(string text) {
    return fnv1a64(cast(const(ubyte)[]) text);
}

unittest {
    assert(fnv1a64String("") == fnvOffset);
    assert(fnv1a64String("a") != fnv1a64String("b"));
    assert(fnv1a64String("quartz") == fnv1a64String("quartz"));
    // Locked prefix so a silent change to the multiplier fails closed.
    assert(fnv1a64String("a") == 0xaf63dc4c8601ec8cUL);
}
