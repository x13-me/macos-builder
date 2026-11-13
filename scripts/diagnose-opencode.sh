#!/usr/bin/env nix
#! nix shell .#ci-tools --quiet --command bash
set -euo pipefail

# Diagnose a failed macOS UniXNU target-OS preparation run with opencode.
# Intended to be called from CI on failure (see .github/workflows/prep-target-os.yml).
# Runs multiple models so each can contribute an independent diagnosis/fix attempt.
#
# Environment:
#   OPENCODE_PROMPT  - diagnosis prompt/instructions
#   OPENCODE_TITLE   - session title base (default: "UniXNU prep failure")
#   OPENCODE_MODELS  - space-separated models to try, in order
#                      (default: opencode/iceman-free opencode/minimax-m3.1-flash-free opencode/glm-5.3-flash-free)
#   OPENCODE_MODEL   - legacy single-model override (used if OPENCODE_MODELS is unset and you set this explicitly)
#   OPENCODE_FORMAT  - output format (default: json)
# Provider credentials are read from the environment by opencode as configured.

prompt="${OPENCODE_PROMPT:-Diagnose why this macOS UniXNU target-OS preparation workflow failed, then ATTEMPT TO EXECUTE the minimal fix on this runner and verify it. Inspect UniXNU/out logs, build config, UniXNU/device sources, and macos-builder flake/scripts; cite relevant log lines/files; make concrete changes and rerun failing commands/checks when feasible. If you cannot fully execute a fix, apply the smallest safe local fix you can and explain blockers precisely. Relevant docs: https://unixnu.com/building https://unixnu.com/guide/requirements https://unixnu.com/guide/build-kernel https://unixnu.com/reference/qemu (UniXNU-qemu: qemu_defconfig mockfs/test, qemu_root_defconfig requires macOS build-os-root.py/hdiutil/diskutil for OS/SystemOS/data seed/trust cache; rebuild kernel with XNU_OWNER_DATA_VOLUME_UUID and payload with trust cache+data ramdisk). macOS builder: use Xcode tools (do not shadow with Nix GNU/llvm tools), hdiutil/diskutil required for root prep, OPENSSL_PREFIX from builder flake.}"
title_base="${OPENCODE_TITLE:-UniXNU prep failure}"
format="${OPENCODE_FORMAT:-json}"

if [ -n "${OPENCODE_MODELS:-}" ]; then
  read -r -a models <<<"$OPENCODE_MODELS"
elif [ -n "${OPENCODE_MODEL:-}" ]; then
  models=("$OPENCODE_MODEL")
else
  models=(opencode/iceman-free opencode/minimax-m3.1-flash-free opencode/glm-5.3-flash-free)
fi

ok=0
for model in "${models[@]}"; do
  echo "::group::opencode diagnose (${model})"
  echo "== opencode diagnose: ${model}"
  if opencode run \
    -m "$model" \
    --format "$format" \
    --title "${title_base} [${model}]" \
    --thinking \
    --auto \
    "$prompt"; then
    ok=$((ok + 1))
  else
    rc=$?
    echo "::warning::opencode diagnose failed for ${model} (exit ${rc})"
  fi
  echo "::endgroup::"
done

if [ "$ok" -eq 0 ]; then
  echo "::warning::opencode diagnosis produced no successful model run; listing available models"
  opencode models || true
fi

echo "== opencode diagnose summary: ${ok}/${#models[@]} model run(s) succeeded"

