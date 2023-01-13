#!/usr/bin/env bash
# Install a user-local LDC into .toolchain when the machine has no D compiler.
# The download is the upstream release tarball. System ldc2 and dmd win when
# they are already on PATH, so a packaged compiler is never overwritten.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/.toolchain"
VER="1.41.0"

if command -v ldc2 >/dev/null 2>&1 && command -v dub >/dev/null 2>&1; then
  exit 0
fi
if command -v dmd >/dev/null 2>&1 && command -v dub >/dev/null 2>&1; then
  exit 0
fi
if [[ -x "$DEST/bin/ldc2" && -x "$DEST/bin/dub" ]]; then
  exit 0
fi

os="$(uname -s)"
arch="$(uname -m)"
asset=""
case "${os}-${arch}" in
  Darwin-arm64) asset="ldc2-${VER}-osx-arm64.tar.xz" ;;
  Darwin-x86_64) asset="ldc2-${VER}-osx-x86_64.tar.xz" ;;
  Linux-x86_64) asset="ldc2-${VER}-linux-x86_64.tar.xz" ;;
  Linux-aarch64|Linux-arm64) asset="ldc2-${VER}-linux-aarch64.tar.xz" ;;
  *)
    echo "Quartz does not know an LDC build for ${os} ${arch}." >&2
    echo "Install ldc2 or dmd, put dub on PATH, and rerun make." >&2
    exit 1
    ;;
esac

url="https://github.com/ldc-developers/ldc/releases/download/v${VER}/${asset}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

echo "Fetching ${asset}"
curl -fL --retry 3 --retry-delay 2 "$url" -o "$tmp/ldc.tar.xz"
tar -xJf "$tmp/ldc.tar.xz" -C "$tmp"

prefix=""
for candidate in "$tmp"/ldc2-*; do
  if [[ -x "$candidate/bin/ldc2" ]]; then
    prefix="$candidate"
    break
  fi
done
if [[ -z "$prefix" ]]; then
  echo "The LDC archive did not contain bin/ldc2." >&2
  exit 1
fi

rm -rf "$DEST"
mkdir -p "$DEST"
cp -a "$prefix"/. "$DEST"/
echo "LDC ${VER} is installed in .toolchain"
