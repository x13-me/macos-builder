#!/usr/bin/env nix
#! nix shell .#ci-tools .#openssl --quiet --command bash
set -euo pipefail
# Usage: resolve-seed.sh <device-dir> [secret-seed]
# Prints the platform seed to stdout and caches it in <device-dir>/.cache/platform-seed.
device_dir="${1:?device dir required}"
secret_seed="${2:-${SECRET_SEED:-}}"
mkdir -p "$device_dir/.cache"
if [ -n "$secret_seed" ]; then
  seed="$secret_seed"
elif [ -f "$device_dir/.cache/platform-seed" ]; then
  seed="$(cat "$device_dir/.cache/platform-seed")"
else
  seed="$(python3 -c 'import secrets; print(secrets.token_hex(16))')"
  printf '%s' "$seed" > "$device_dir/.cache/platform-seed"
fi
printf '%s' "$seed"
