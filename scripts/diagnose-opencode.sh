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

prompt="${OPENCODE_PROMPT:-Diagnose why this macOS UniXNU target-OS preparation workflow failed. Inspect UniXNU/out logs, build config, and macos-builder scripts; cite relevant log lines/files and suggest the minimal fix.}"
title="${OPENCODE_TITLE:-UniXNU prep failure}"
model="${OPENCODE_MODEL:-opencode/iceman-free}"
format="${OPENCODE_FORMAT:-json}"

exec opencode run \
  -m "$model" \
  --format "$format" \
  --title "$title" \
  --thinking \
  --auto \
  "$prompt"
