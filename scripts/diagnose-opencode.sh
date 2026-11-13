#!/usr/bin/env nix
#! nix shell .#ci-tools --quiet --command bash
set -euo pipefail

# Diagnose a failed macOS UniXNU target-OS preparation run with opencode.
# Intended to be called from CI on failure (see .github/workflows/prep-target-os.yml).
#
# Environment:
#   OPENCODE_PROMPT  - diagnosis prompt/instructions (required)
#   OPENCODE_TITLE   - session title (default: "UniXNU prep failure")
#   OPENCODE_MODEL   - model in provider/model[#variant] form (default: opencode/iceman-free)
#   OPENCODE_FORMAT  - output format (default: json)
# Provider credentials are read from the environment by opencode as configured.

prompt="${OPENCODE_PROMPT:-Diagnose why this macOS UniXNU target-OS preparation workflow failed, then ATTEMPT TO EXECUTE the minimal fix on this runner and verify it. Inspect UniXNU/out logs, build config, UniXNU/device sources, and macos-builder flake/scripts; cite relevant log lines/files; make concrete changes and rerun failing commands/checks when feasible. If you cannot fully execute a fix, apply the smallest safe local fix you can and explain blockers precisely. Relevant docs: https://unixnu.com/building https://unixnu.com/guide/requirements https://unixnu.com/guide/build-kernel https://unixnu.com/reference/qemu (UniXNU-qemu: qemu_defconfig mockfs/test, qemu_root_defconfig requires macOS build-os-root.py/hdiutil/diskutil for OS/SystemOS/data seed/trust cache; rebuild kernel with XNU_OWNER_DATA_VOLUME_UUID and payload with trust cache+data ramdisk). macOS builder: use Xcode tools (do not shadow with Nix GNU/llvm tools), hdiutil/diskutil required for root prep, OPENSSL_PREFIX from builder flake.}"
title="${OPENCODE_TITLE:-UniXNU prep failure}"
model="${OPENCODE_MODEL:-opencode/iceman-free}"
format="${OPENCODE_FORMAT:-json}"

exec opencode run \
  -m "$model" \
  --format "$format" \
  --title "$title" \
  --thinking \
  --auto \
  "$prompt" || opencode models

