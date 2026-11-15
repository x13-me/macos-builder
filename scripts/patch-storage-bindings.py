#!/usr/bin/env nix
#! nix shell nixpkgs#python3 -c python3
import pathlib
import sys

old = (
    "      RAM_BLOCK_OBJECT=$ROOT/build/ram-block/NativeRamBlock.o\n"
    "      test -f \"$RAM_BLOCK_OBJECT\"\n"
    "      KERNEL_EXTRA_ARCHIVES=\"$KERNEL_EXTRA_ARCHIVES $RAM_BLOCK_OBJECT\"\n"
)
new = (
    "      RAM_BLOCK_OBJECT=$ROOT/build/ram-block/NativeRamBlock.o\n"
    "      test -f \"$RAM_BLOCK_OBJECT\"\n"
    "      for RAM_BLOCK_BINDINGS in \\\n"
    "        \"$ROOT/build/storage-bindings/original-bindings.o\" \\\n"
    "        \"$ROOT/build/storage-bindings/ram-block-original-bindings.o\" \\\n"
    "        \"$ROOT/build/storage-bindings/virtio-original-bindings.o\" \\\n"
    "        \"$ROOT/build/ram-block/original-bindings.o\"; do\n"
    "        if [ -f \"$RAM_BLOCK_BINDINGS\" ]; then\n"
    "          KERNEL_EXTRA_ARCHIVES=\"$KERNEL_EXTRA_ARCHIVES $RAM_BLOCK_BINDINGS\"\n"
    "          break\n"
    "        fi\n"
    "      done\n"
    "      KERNEL_EXTRA_ARCHIVES=\"$KERNEL_EXTRA_ARCHIVES $RAM_BLOCK_OBJECT\"\n"
)

for arg in sys.argv[1:]:
    p = pathlib.Path(arg)
    if not p.is_file():
        continue
    s = p.read_text()
    if old in s and "build/storage-bindings/original-bindings.o" not in s:
        s = s.replace(old, new)
        p.write_text(s)
        print(f"Patched {p}: link shared storage original-bindings.o with raw ram-block object")
