# Synchronization

Preamble search slides a known pattern across the capture and keeps the lag
with the largest correlation energy. A pattern parked at sample 7 peaks at
sample 7, including after a small perturbation of the first chip.

The phase-locked loop multiplies the input by the conjugate of an NCO. The
imaginary part of that product is the phase error. The loop filter is a
proportional term plus an integral. The integral is initialized to zero.
A fresh `double` field in D would otherwise be NaN, and the frequency would
become NaN on the first update.

The lock test starts the NCO on the tone's frequency with a phase offset of
0.05 cycles. After the transient, the average real part of the derotated
sample is positive and away from zero. That is phase lock. It is not a claim
about acquiring a large frequency offset from a cold start.
