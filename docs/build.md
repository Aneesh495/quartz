# Building

Quartz is a Dub executable. The compiler is LDC or DMD. There are no
third-party D libraries.

```sh
make check
```

`make` looks for `ldc2`, then `dmd`. If neither is on `PATH`,
`tools/ensure_ldc.sh` downloads the LDC 1.41.0 release for the host into
`.toolchain/` and prepends its `bin` directory. Supported hosts are macOS
arm64, macOS x86_64, Linux x86_64, and Linux aarch64.

Override the compiler with `make COMPILER=ldc2` or `make COMPILER=dmd`.

The debug build keeps assertions on and still optimizes. `make release`
turns assertions off. The tests use the unittest build, which also
optimizes, because a 0 dB BPSK count of several thousand bits should not
take a minute.

Artifacts:

| Path | What it is |
|---|---|
| `./quartz` | The executable |
| `.runtime/` | Receipts from `quartz run --out` |
| `.toolchain/` | A downloaded LDC, if the bootstrap ran |
| `quartz-test-application` | The Dub unittest binary |

All four are gitignored except that the test binary is removed by `make clean`.
`.toolchain` and `.runtime` are never committed.
