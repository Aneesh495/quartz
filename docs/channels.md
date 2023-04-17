# Channels

## Noise

`Xoshiro256` is seeded with SplitMix64. `nextDouble` uses the top 53 bits.
Gaussians are Box-Muller, with one spare sample cached. A complex Gaussian is
two real draws. The same seed replays the same sequence. A long run has mean
near zero and variance near one. That is a statistical lock, not a published
test vector. The first four integers of seed 42 are stable across two
constructions in the same process, which is the reproducibility property the
receipts depend on.

## AWGN

On the symbol path, noise is added to each constellation point with the sigma
from the Eb/N0 formula. On the raised-cosine and OFDM paths, the same sigma
is added per sample. That is a convenient laboratory knob. It is not a claim
that the sample-rate noise has been matched to a particular noise bandwidth.
Silent checks (`channel none`) are the exact tests for those paths.

## Rayleigh

One complex coefficient per symbol, scaled so `E[|h|^2] = 1`. The executor
equalizes with the known coefficient before the demapper. This is coherent
detection with perfect channel knowledge, which is the setting of the
closed-form curve.

## BSC

Each coded bit flips with probability `crossover`, independently. The
constellation is not used. This is the channel a block code's correction
radius is easiest to stare at.

## Tapped delay

`TappedDelay` is a complex FIR. An impulse comes out as the taps, in order.
A one-tap line is ordinary scaling. OFDM's cyclic prefix is what would make a
longer line diagonal in the frequency domain. The flat-gain OFDM test is the
degenerate case of that fact.

## CIC as a rate change

The cascaded integrator-comb is a channel only in the sense that it is a
deterministic linear system you can drop in front of a demodulator. Two
stages, decimation 4, differential delay 1, have DC gain 16. A constant input
decimates to that constant gain once the combs have seen a previous sample.

## What is intentionally absent

There is no antenna model, no regulatory spectral mask, and no claim that a
number in a receipt is a link budget for a piece of hardware. Carrier offset
on the raised-cosine path is a complex mix. It is not a full timing-recovery
demonstration. The Gardner and Mueller detectors are not in this tree. The
phase-locked loop that is here is a phase pull-in on a tone that is already
near the right frequency.
