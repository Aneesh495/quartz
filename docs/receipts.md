# Receipts

A receipt is a JSON object written by `quartz run --out <dir>`.

```text
{
  "name": "bpsk_awgn",
  "version": "1.0.0",
  "seed": 7,
  "ebn0_db": 6,
  "info_bits": 8192,
  "coded_bits": 8192,
  "bit_errors": 22,
  "ber": 0.00268555,
  "plan_sha256": "..."
}
```

The error count above is an illustration. The file you generate is the
authority. `plan_sha256` is SHA-256 of `plan.canonical()`, which is one
`key=value` line per field in a fixed order. Changing a default that the
file never mentioned still changes the digest, because the defaults are part
of the plan.

`plan.txt` in the same directory is that canonical text, so you can see the
bytes that were hashed without opening the binary.

The version string is `quartz.meta.quartzVersion`. It is stamped so two
receipts can be told apart when the laboratory itself has changed and the
plan text has not.

The seed is the only randomness. Bits are drawn first, then noise, from one
xoshiro256** generator. A BSC draw consumes the generator in place of the
symbol noise. A Rayleigh trial consumes a complex coefficient and two noise
samples per symbol.
