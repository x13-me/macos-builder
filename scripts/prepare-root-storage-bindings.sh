#!/usr/bin/env bash
set -euo pipefail

# Prepare ram-block and storage bindings layout expected by UniXNU root rebuild.
# Usage: prepare-root-storage-bindings.sh <tree> [builder-dir]

TREE="${1:?tree required}"
BUILDER="${2:-${BUILDER:-}}"

for t in "$TREE" out/*/tree; do
  [ -d "$t" ] || continue
  mkdir -p "$t/build/ram-block" "$t/build/storage-bindings"

  # Prefer an existing native-ram-block source directory.
  src=""
  for cand in \
    "$t/build/native-ram-block" \
    "$(dirname "$t")/build/native-ram-block" \
    "$t/native-ram-block"; do
    if [ -d "$cand" ]; then src="$cand"; break; fi
  done

  publish_ram_block_dir() {
    local bd="$1"
    [ -d "$bd" ] || return 0
    local f b abs
    for f in "$bd"/*; do
      [ -e "$f" ] || continue
      b="$(basename "$f")"
      abs="$(cd "$(dirname "$f")" && pwd)/$b"
      case "$b" in
        libNativeRamBlock.a)
          cp -f "$abs" "$t/build/ram-block/libNativeRamBlock.a"
          cp -f "$abs" "$t/build/ram-block/libRamBlock.a"
          ;;
        *)
          cp -f "$abs" "$t/build/ram-block/$b"
          ;;
      esac
    done
  }

  if [ -n "$src" ]; then
    publish_ram_block_dir "$src"
  fi

  # Fallback: locate bindings.json anywhere under build and mirror its dir.
  if [ ! -f "$t/build/ram-block/bindings.json" ]; then
    bj="$(find "$t/build" -name bindings.json 2>/dev/null | head -n 1 || true)"
    if [ -n "$bj" ] && [ -f "$bj" ]; then
      publish_ram_block_dir "$(dirname "$bj")"
    fi
  fi

  # Normalize names if artifacts already landed in canonical dir.
  if [ -f "$t/build/ram-block/libNativeRamBlock.a" ] && [ ! -f "$t/build/ram-block/libRamBlock.a" ]; then
    cp -f "$t/build/ram-block/libNativeRamBlock.a" "$t/build/ram-block/libRamBlock.a"
  fi
  # build-xnu-4k-baseline.sh checks sha256 against <stem-without-lib>.o for
  # each archive (libRamBlock.a -> RamBlock.o) and later links NativeRamBlock.o.
  if [ -f "$t/build/ram-block/NativeRamBlock.o" ] && [ ! -f "$t/build/ram-block/RamBlock.o" ]; then
    cp -f "$t/build/ram-block/NativeRamBlock.o" "$t/build/ram-block/RamBlock.o"
  fi
  if [ -f "$t/build/ram-block/RamBlock.o" ] && [ ! -f "$t/build/ram-block/NativeRamBlock.o" ]; then
    cp -f "$t/build/ram-block/RamBlock.o" "$t/build/ram-block/NativeRamBlock.o"
  fi

  # Preserve original storage bindings for root kernel linking.
  if [ -f "$t/build/ram-block/libRamBlock.a" ]; then
    (cd "$t/build/ram-block" && ar x libRamBlock.a original-bindings.o >/dev/null 2>&1) || true
    (cd "$t/build/ram-block" && ar x libRamBlock.a original-bindings.S >/dev/null 2>&1) || true
  fi
  if [ -f "$t/build/ram-block/original-bindings.o" ]; then
    cp -f "$t/build/ram-block/original-bindings.o" "$t/build/storage-bindings/ram-block-original-bindings.o"
  fi
  if [ -f "$t/build/ram-block/original-bindings.S" ]; then
    cp -f "$t/build/ram-block/original-bindings.S" "$t/build/storage-bindings/ram-block-original-bindings.S"
  fi

  # Locate and extract virtio storage bindings if available.
  while IFS= read -r va; do
    [ -f "$va" ] || continue
    tmpd="$t/build/storage-bindings/.virtio-tmp"
    rm -rf "$tmpd"
    mkdir -p "$tmpd"
    if (cd "$tmpd" && ar x "$va" original-bindings.o >/dev/null 2>&1); then
      cp -f "$tmpd/original-bindings.o" "$t/build/storage-bindings/virtio-original-bindings.o"
      echo "[storage-bindings] extracted virtio bindings.o from $va"
    fi
    if (cd "$tmpd" && ar x "$va" original-bindings.S >/dev/null 2>&1); then
      cp -f "$tmpd/original-bindings.S" "$t/build/storage-bindings/virtio-original-bindings.S"
      echo "[storage-bindings] extracted virtio bindings.S from $va"
    fi
    rm -rf "$tmpd"
    if [ -f "$t/build/storage-bindings/virtio-original-bindings.o" ] || [ -f "$t/build/storage-bindings/virtio-original-bindings.S" ]; then
      break
    fi
  done < <(
    {
      printf '%s\n' \
        "$t/build/native-virtio-block-verified-bundle/libNativeVirtioBlock.a" \
        "$t/build/virtio-mmio-block/libVirtioMmioBlock.a" \
        "$t/build/native-virtio-block/libNativeVirtioBlock.a"
      find "$t/build" "$(dirname "$t")/build" -type f \( -name 'lib*Virtio*Block*.a' -o -name 'lib*virtio*block*.a' \) 2>/dev/null || true
    } | awk 'NF && !seen[$0]++'
  )

  # Build merged canonical bindings from any available .S sources (union of symbols).
  if [ -n "$BUILDER" ] && [ -f "$BUILDER/scripts/merge-storage-bindings.py" ]; then
    python3 "$BUILDER/scripts/merge-storage-bindings.py" "$t/build/storage-bindings" "$t/build/ram-block" || true
  fi

  # Fallback canonical selection if merge did not produce object.
  if [ ! -f "$t/build/storage-bindings/original-bindings.o" ]; then
    for c in \
      "$t/build/storage-bindings/virtio-original-bindings.o" \
      "$t/build/storage-bindings/ram-block-original-bindings.o" \
      "$t/build/ram-block/original-bindings.o"; do
      if [ -f "$c" ]; then
        cp -f "$c" "$t/build/storage-bindings/original-bindings.o"
        echo "[storage-bindings] canonical=$(basename "$c")"
        break
      fi
    done
  else
    echo "[storage-bindings] canonical=merged-original-bindings"
  fi

  # Ensure bindings.json is available next to any storage archive/object the
  # kernel link/validation script may use.
  bj_src=""
  for bj_cand in \
    "$t/build/ram-block/bindings.json" \
    "$t/build/native-ram-block/bindings.json" \
    "$(dirname "$t")/build/native-ram-block/bindings.json"; do
    if [ -f "$bj_cand" ]; then bj_src="$bj_cand"; break; fi
  done
  if [ -z "$bj_src" ]; then
    bj_src="$(find "$t/build" "$(dirname "$t")/build" -name bindings.json 2>/dev/null | head -n 1 || true)"
  fi
  if [ -n "$bj_src" ] && [ -f "$bj_src" ]; then
    mkdir -p "$t/build/ram-block" "$t/build/native-ram-block" 2>/dev/null || true
    cp -f "$bj_src" "$t/build/ram-block/bindings.json" 2>/dev/null || true
    cp -f "$bj_src" "$t/build/native-ram-block/bindings.json" 2>/dev/null || true
    while IFS= read -r rb; do
      [ -f "$rb" ] || continue
      rbd="$(dirname "$rb")"
      [ -f "$rbd/bindings.json" ] || cp -f "$bj_src" "$rbd/bindings.json" 2>/dev/null || true
    done < <(find "$t/build" "$(dirname "$t")/build" -type f \( -name 'libRamBlock.a' -o -name 'libNativeRamBlock.a' -o -name 'NativeRamBlock.o' -o -name 'RamBlock.o' -o -name 'libNativeVirtioBlock.a' -o -name 'libVirtioMmioBlock.a' -o -name 'VirtioMmioBlock.o' -o -name 'NativeVirtioBlock.o' -o -name '*Virtio*Block*.a' -o -name '*virtio*block*.a' \) 2>/dev/null || true)
  fi

  echo "[ram-block] tree=$t src=${src:-none} bj=${bj_src:-none}"
  ls -la "$t/build/ram-block" 2>/dev/null || true
  ls -la "$t/build/native-ram-block" 2>/dev/null || true
  echo "[storage-bindings] tree=$t"
  ls -la "$t/build/storage-bindings" 2>/dev/null || true
  find "$t/build" -maxdepth 4 -type f \( -name '*Virtio*Block*.a' -o -name '*virtio*block*.a' -o -name 'libNativeRamBlock.a' -o -name 'libRamBlock.a' -o -name 'NativeRamBlock.o' -o -name 'RamBlock.o' -o -name 'bindings.json' -o -name 'original-bindings.*' \) 2>/dev/null | head -160 || true
done
