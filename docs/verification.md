# Verification

`dub test` compiles every module with `-unittest` and runs those tests before
`main`. `make check` does that and then runs the loopback battery, the theory
table, and three example files.

The tests are deterministic. A Poisson comparison uses a fixed seed, so a
failure is a real change in the noise model or the demapper, not a flaky
draw.

## What is exhaustive

| Object | What is enumerated |
|---|---|
| Hamming(7, 4) | All 16 messages, all 7 single flips |
| Hamming(15, 11) | All 15 single flips of one message |
| Golay(23, 12) | All 4096 weights, all weight-3 patterns of one codeword |
| Reed-Solomon(7, 3) | All single-symbol and double-symbol errors of one codeword |
| BCH length 15 | All weight-1 and weight-2 errors of one codeword |
| Polar(8, 4) | All 16 information patterns, clean channel |
| Reed-Muller RM(1, m) for m up to 4 | Every codeword, fast decoder versus brute force |
| Convolutional constraint 3 | Viterbi versus exhaustive ML on length 6 |

## What is an identity

| Path | Identity |
|---|---|
| FFT | Round trip, and agreement with a naive DFT, including Bluestein lengths |
| OFDM | Bins in, bins out, and a flat gain scales them |
| Raised-cosine QPSK | Labels in, labels out, on a silent channel |
| Alamouti | Combined symbols equal the originals times the channel energy |
| ZF and MMSE | Noiseless square channel returns the vector |
| Sphere decoder | Agrees with brute-force BPSK ML |
| CRC, SHA-256 | Published check values |
| PNG, WAV | Bytes written are bytes read back |

## What is statistical

BPSK at 0 dB, QPSK at 0 dB, and coherent Rayleigh BPSK at 0 dB must fall
inside a few standard deviations of the textbook rate. The experiment
executor repeats the BPSK check on its own bit-then-noise schedule, which is
not the same interleaving as the ideal trial, so the two counts are not
required to be equal. They are required to be legal for the same formula.

## Running it

```sh
make check
```

If `ldc2` or `dmd` is not on `PATH`, `make` downloads LDC 1.41.0 into
`.toolchain/` and uses that. An existing compiler is left alone.

A shorter look:

```sh
dub test --compiler=ldc2
./quartz loopback
./quartz run examples/bpsk_awgn.qz
```

`quartz loopback` returns 0 only when every named check passes.
