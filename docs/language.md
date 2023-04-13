# Experiment language

An experiment is one block. Keys are assignments. Blocks name a modem, a
code, a channel, or an impairment. A shorthand `code none;` and a block
`code none { }` set the same field.

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

Comments are `#` to the end of the line, or `//` to the end of the line.
Strings use double quotes. Numbers are integers or decimals. An unknown key
is an error at that line and column, not a silent default.

## Top-level keys

| Key | Meaning |
|---|---|
| `seed` | Integer seed for the bit source and the noise |
| `bits` | Information bits |
| `ebn0_db` | Eb/N0 in decibels |
| `rate_hz` | Sample rate, used when a carrier offset is in hertz |
| `name` | Overrides the experiment name in the receipt |

## Modem block

The label is the constellation or the waveform.

| Label | Bits per symbol |
|---|---|
| `bpsk` | 1 |
| `qpsk` | 2 |
| `psk8` | 3 |
| `qam16` | 4 |
| `qam64` | 6 |
| `ofdm_qpsk` | 2, on the data bins of an OFDM symbol |
| `bfsk` | Reserved name, not the symbol-path executor |

Inside the block:

| Key | Meaning |
|---|---|
| `sps` | Samples per symbol |
| `pulse` | `rect` or `rrc` |
| `beta` | Raised-cosine rolloff, from 0 to 1 |
| `span` | Raised-cosine span in symbols |
| `kind` | Modem name, if you did not put it in the label |

`sps = 1` and `pulse = rect` select the symbol path. Anything else with
`pulse = rrc` selects the waveform path. `modem ofdm_qpsk` selects OFDM even
if the pulse line says otherwise.

## Code block

| Label | Nominal rate |
|---|---|
| `none` | 1 |
| `repetition` | `1/repeat` |
| `hamming74` | 4/7 |
| `hamming1511` | 11/15 |
| `conv12` | 1/2, NASA polynomials, terminated |
| `golay23` | 12/23 |
| `polar` | 1/2 on blocks of 16 information bits in length 32 |

`repeat` is the only inner key, and it applies to repetition.

## Channel block

| Label | What is random |
|---|---|
| `none` | Nothing. The payload must come back. |
| `awgn` | Complex Gaussian noise at the Eb/N0 of the plan |
| `rayleigh` | A unit-power complex fade per symbol, known at the receiver, then noise |
| `bsc` | Independent bit flips with probability `crossover` |

`ebn0_db` may also be set inside the channel block. `crossover` defaults to
0.01 and is only read by `bsc`.

## OFDM block

| Key | Meaning |
|---|---|
| `nfft` | FFT length, a power of two |
| `cp` | Cyclic prefix length |

The default is 64 and 16. That pair uses the 52 occupied tones of a 20 MHz
Wi-Fi-shaped symbol, all of them carrying data. Any other pair uses every bin
except DC and Nyquist.

## Impairment block

`cfo_hz` is a carrier offset in hertz on the raised-cosine path. It is a
complex mix by `cfo_hz / rate_hz` cycles per sample. The symbol path has no
samples, so the offset is ignored there.

## Commands

```sh
quartz run examples/bpsk_awgn.qz --out .runtime/bpsk
quartz explain examples/ofdm_wifi.qz
quartz ber examples/bpsk_awgn.qz --from 0 --to 8 --step 2 --bits 8000
quartz theory bpsk --ebn0 0,4,8
quartz loopback
```

`explain` prints the canonical plan. That text is the bytes SHA-256 hashes.
