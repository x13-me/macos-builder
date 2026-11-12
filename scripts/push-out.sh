#!/usr/bin/env nix
#! nix shell .#ci-tools .#openssl --quiet --command bash
set -euo pipefail
# Usage: push-out.sh <out-dir> <target-name> [cachix-name] [nix-copy-to]
# Adds out-dir to the Nix store and optionally pushes it to a private cache.
# WARNING: outputs may include Apple-derived/proprietary material.
out_dir="${1:?out dir required}"
target_name="${2:?target name required}"
cachix_name="${3:-${CACHIX_NAME:-}}"
nix_copy_to="${4:-${NIX_COPY_TO:-}}"

if [ ! -d "$out_dir" ]; then
  echo "::warning::No output directory to push: $out_dir" >&2
  exit 0
fi

out_path="$(nix store add-path --name "unixnu-out-${target_name}" "$out_dir")"
echo "Added to store: $out_path" >&2
printf '%s\n' "$out_path"

if [ -n "$cachix_name" ]; then
  cachix push "$cachix_name" "$out_path"
fi
if [ -n "$nix_copy_to" ]; then
  nix copy --to "$nix_copy_to" "$out_path"
fi
