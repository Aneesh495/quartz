#!/usr/bin/env bash
# Print the D compiler Dub should invoke. Prefer an explicit override, then
# PATH, which includes .toolchain/bin via the Makefile.
set -euo pipefail
if [[ -n "${COMPILER:-}" ]]; then
  printf '%s\n' "$COMPILER"
  exit 0
fi
if command -v ldc2 >/dev/null 2>&1; then
  printf '%s\n' ldc2
  exit 0
fi
if command -v dmd >/dev/null 2>&1; then
  printf '%s\n' dmd
  exit 0
fi
echo "no D compiler found" >&2
exit 1
