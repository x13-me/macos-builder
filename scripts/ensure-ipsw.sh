#!/usr/bin/env nix
#! nix shell .#ci-tools .#openssl --quiet --command bash
set -euo pipefail
# Usage: ensure-ipsw.sh <url> <dest-dir> [fallback-url]
# Prints the local IPSW path to stdout, or empty line if no URL.
url="${1:-}"
dest_dir="${2:?dest dir required}"
fallback="${3:-}"
if [ -z "$url" ] && [ -n "$fallback" ]; then
  url="$fallback"
fi
if [ -z "$url" ]; then
  echo ""
  exit 0
fi
mkdir -p "$dest_dir"
ipsw="$dest_dir/$(basename "$url")"
if [ ! -f "$ipsw" ]; then
  echo "Downloading restore image to $ipsw" >&2
  curl -fL --retry 3 -C - -o "$ipsw.part" "$url"
  mv "$ipsw.part" "$ipsw"
fi
printf '%s' "$ipsw"
