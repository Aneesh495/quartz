# MIMO

Two transmit antennas, one receive antenna, two symbol periods. Alamouti
sends `s0` and `s1`, then `-conj(s1)` and `conj(s0)`. The combiner is

```text
s0_hat = conj(h1) y0 + h2 conj(y1)
s1_hat = conj(h2) y0 - h1 conj(y1)
```

On a silent channel both equal the originals times `|h1|^2 + |h2|^2`.

A square channel `y = H x` is inverted by LU for zero forcing. MMSE adds
`sigma^2` to the diagonal of `H^H H` and factors that Gram matrix with
Cholesky. The forward substitution is through `L`. The back substitution is
through `L^H`, so the upper entries are conjugated lower entries.

The sphere search is depth-first over BPSK symbols in the QR domain. It is
checked against the four-point brute force on random 2 by 2 channels, noiseless,
where both must return the transmitted vector.
