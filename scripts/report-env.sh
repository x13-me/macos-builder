#!/usr/bin/env nix
#! nix shell .#ci-tools .#openssl --quiet --command bash
set -euo pipefail
export OPENSSL_PREFIX="${OPENSSL_PREFIX:-$(dirname "$(dirname "$(readlink -f "$(command -v openssl)")")")}"
set -x
sw_vers || true
uname -m
xcodebuild -version || true
xcrun --show-sdk-path || true
nix --version
python3 --version
cmake --version | head -n 1 || true
ninja --version || true
clang --version | head -n 1 || true
qemu-system-aarch64 --version | head -n 1 || true
echo "OPENSSL_PREFIX=${OPENSSL_PREFIX:-}"
df -h "${GITHUB_WORKSPACE:-.}" || true
