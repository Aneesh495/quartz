# quartz

A deterministic physical-layer laboratory, written in D.

A radio trial is easy to run once and hard to run twice. The sample clock,
the noise draw, the scale of the pulse, and the instant the matched filter is
sampled all change the bits that come out. Quartz treats one trial as a
program over a rational clock. The same source, the same seed, and the same
binary produce the same receipt.

The question that started this project was: **what is the smallest laboratory
in which a coded waveform, a channel, and a demodulator can be rerun exactly?**

## Run it

You need a D compiler (`ldc2` or `dmd`) and `dub`, which ships with LDC.
Nothing else: no native libraries, no network, no dataset.

```sh
git clone https://github.com/Aneesh495/quartz.git
cd quartz
make check
```

If no compiler is on `PATH`, `make` downloads a user-local LDC into
`.toolchain/` and uses it. You can also install LDC yourself
(`brew install ldc` on macOS, or a package build on Linux) and run the same
command.

`make check` builds the binary, runs the in-source tests, then executes the
loopback battery, the theory table, and three example experiments. Receipts
land in `.runtime/`.

```sh
./quartz loopback
./quartz theory bpsk --ebn0 0,4,8
./quartz run examples/bpsk_awgn.qz
./quartz ber examples/bpsk_awgn.qz --from 0 --to 8 --step 2 --bits 12000
./quartz explain examples/ofdm_wifi.qz
./quartz run examples/ofdm_wifi.qz --out .runtime/wifi
```

`quartz run` writes `receipt.json` and the canonical plan when you pass
`--out`. A BPSK trial at 6 dB comes back with an error count in the
neighborhood of the erfc formula. The silent QPSK and OFDM examples come back
with none.

## A small experiment

```text
experiment bpsk_awgn {
  seed = 7;
  bits = 8192;
  ebn0_db = 6;
  rate_hz = 48000;
  modem bpsk {
    sps = 1;
    pulse = rect;
  }
  code none;
  channel awgn;
}
```

`sps = 1` and `pulse = rect` select the textbook path: one sample per symbol,
no pulse-shaping loss, noise variance set from Eb/N0. That is the path the
theory table is allowed to judge. Raised-cosine, OFDM, fading, and timing
recovery are separate experiments with their own checks (noiseless recovery,
lock of a loop, monotonic BER).

## What is inside

| Layer | Implementation |
|---|---|
| Clock | Rational sample ratios, reduced resampling fractions, Eb/N0 and link budget |
| Numeric | Complex baseband, Q-format fixed point, polynomials, LU, Cholesky, QR |
| Coding | CRC, Hamming, Golay, Reed-Solomon, BCH, convolutional Viterbi and BCJR, polar SC, IRA-LDPC, Reed-Muller |
| DSP | Windowed FIR, RRC, Butterworth SOS, radix-2 and Bluestein FFT, polyphase resampling, CORDIC, CIC, LMS, CMA |
| Modem | PSK, QAM, FSK, MSK, GMSK, pi/4-QPSK, differential PSK, 802.11-style OFDM |
| Recovery | Preamble correlation, a phase-locked loop that pulls a tone onto the real axis |
| Channel | Seeded AWGN, BSC, coherent Rayleigh, a tapped delay line, carrier offset on the raised-cosine path |
| MIMO | Alamouti, zero forcing, MMSE, a BPSK sphere search checked against brute force |
| Language | Lexer, parser, semantic check, canonical plan text |
| Runtime | Seeded executor for symbols, raised cosine, and OFDM, plus a DAG schedule check and SHA-256 receipts |
| Pictures | Uncompressed PNG, including a constellation scatter, and 16-bit WAV |

The DAG is acyclic on purpose. A phase-locked loop holds its feedback inside
one node. The scheduler never has to solve a cyclic sample dependency, and a
receipt can hash the schedule.

## Documentation

- [Architecture](docs/architecture.md)
- [Language](docs/language.md)
- [Numerics and Eb/N0](docs/numerics.md)
- [Coding](docs/coding.md)
- [Waveforms](docs/waveforms.md)
- [Channels](docs/channels.md)
- [MIMO](docs/mimo.md)
- [Synchronization](docs/sync.md)
- [Receipts](docs/receipts.md)
- [Build](docs/build.md)
- [Verification](docs/verification.md)

## License

MIT. See [LICENSE](LICENSE).
