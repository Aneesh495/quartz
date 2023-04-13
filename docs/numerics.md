# Numerics and Eb/N0

## Complex noise

A symbol has energy `Es = E[|s|^2]`. The constellations in this laboratory
are normalized so that energy is 1. A complex noise sample has independent
real and imaginary parts, each of variance `sigma^2`. The total noise
variance is `N0 = 2 sigma^2` when one symbol occupies one sample.

`bitsPerSymbol` is the number of coded bits on the symbol. `codeRate` is the
nominal ratio of information bits to coded bits. Then

```text
Eb = Es / (bitsPerSymbol * codeRate)
N0 = Eb / (Eb/N0)
sigma = sqrt(N0 / 2)
```

`noiseSigma` in `quartz.units` is that formula. At 0 dB, BPSK, rate 1, it
returns `sqrt(1/2)`.

The coherent BPSK bit error rate is

```text
Pb = (1/2) erfc(sqrt(Eb/N0))
```

At 0 dB that is about `0.07865`. The ideal trial and the experiment executor
both have to land inside a Poisson band around that count. The band is wide
on purpose: it catches a 3 dB mistake and does not flap on a legal seed.

## Rayleigh

A unit-power complex coefficient `h` multiplies the symbol. The receiver
knows `h` and forms `Re(y conj(h))`, or equivalently divides `y conj(h)` by
`|h|^2` before a nearest-neighbor demap. The average error rate is

```text
Pb = (1/2) (1 - sqrt(g / (1 + g)))
```

with `g = Eb/N0`. At 0 dB that is about `0.1464`.

## QPSK

Gray QPSK is two independent BPSK rails. Each rail carries half the symbol
energy, and the noise formula is called with two bits per symbol. The bit
error rate matches BPSK. The points are `(±1, ±1) / sqrt(2)`.

## 16-QAM

The Gray bit-error approximation used in the theory table is

```text
Pb = (3/8) erfc(sqrt((2/5) Eb/N0))
```

It is an approximation. The executor's hard demap is exact nearest neighbor.
Do not treat a small gap between them as a bug in the demapper.

## Raised cosine

The square-root raised cosine is normalized to unit energy. Convolving it
with itself, which is what the matched filter does, puts a 1 on the center
tap. Other symbol instants are small. An 8-symbol span truncates the tails,
so those instants are not a mathematical zero. The silent QPSK loopback still
recovers every label, because the residual is far inside a decision region.

## Fixed point

`Fixed!15` keeps a 32-bit word with 15 fraction bits. Multiplication rounds
half away from zero and saturates. Packed Q15 is a separate `short` with the
range of a 16-bit sample. The wide word is the working format.

## Matrices

`double.init` is NaN. A new matrix is filled with zeros before anyone writes
it. LU uses partial pivoting. Cholesky is the Hermitian factor used by MMSE.
Modified Gram-Schmidt is the QR used by the sphere decoder. The Frobenius
condition number of the identity of size n is n, because both the matrix and
its inverse have Frobenius norm `sqrt(n)`.

## Hashes

SHA-256 is checked against the empty string, `abc`, and the long FIPS vector.
FNV-1a 64 of the byte `a` is locked to `0xaf63dc4c8601ec8c`. CRC-32 of
`123456789` is `0xCBF43926`.
