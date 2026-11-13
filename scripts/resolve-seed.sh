#!/usr/bin/env nix
#! nix shell .#ci-tools .#openssl --quiet --command bash
set -euo pipefail
# Usage: resolve-seed.sh <device-dir> [secret-seed]
# Prints the platform seed to stdout and caches it in <device-dir>/.cache/platform-seed.
#
# The seed is the platform identity (unique-chip-id / ECID) encoded into the device tree as a u64.
# It must be a nonzero value that fits in 64 bits (1..2^64-1); wider seeds break ADT generation
# (struct.pack('<Q', ...)).
device_dir="${1:?device dir required}"
secret_seed="${2:-${SECRET_SEED:-}}"
mkdir -p "$device_dir/.cache"
cache="$device_dir/.cache/platform-seed"

if [ -n "$secret_seed" ]; then
  seed="$secret_seed"
  write_cache=0
elif [ -f "$cache" ]; then
  seed="$(cat "$cache")"
  write_cache=1
else
  seed="$(python3 -c 'import secrets; print(secrets.token_hex(8))')"
  write_cache=1
fi

seed="$(python3 - "$seed" <<'PY'
import re, secrets, sys
s = sys.argv[1].strip()
if not re.fullmatch(r'(0[xX])?[0-9a-fA-F]+', s):
    raise SystemExit(f'platform seed is not hexadecimal: {s!r}')
v = int(s, 16) & ((1 << 64) - 1)
if v == 0:
    v = int.from_bytes(secrets.token_bytes(8), 'little')
print(f'{v:016x}')
PY
)"

if [ "${write_cache:-0}" = 1 ]; then
  printf '%s' "$seed" > "$cache"
fi
printf '%s' "$seed"
