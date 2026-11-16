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

bindings_old = "records = [json.loads(Path(p).with_name('bindings.json').read_text()) for p in sys.argv[1:]]"
bindings_new = (
    "def load_record(p):\n"
    "    bp = Path(p).with_name('bindings.json')\n"
    "    if not bp.is_file():\n"
    "        root = Path(p)\n"
    "        for parent in root.parents:\n"
    "            if parent.name == 'build':\n"
    "                cand = parent / 'ram-block' / 'bindings.json'\n"
    "                if cand.is_file():\n"
    "                    bp = cand\n"
    "                    break\n"
    "        if not bp.is_file():\n"
    "            for cand in Path(p).parent.parent.rglob('bindings.json'):\n"
    "                if cand.is_file():\n"
    "                    bp = cand\n"
    "                    break\n"
    "    return json.loads(bp.read_text())\n"
    "records = [load_record(p) for p in sys.argv[1:]]"
)

for arg in sys.argv[1:]:
    p = pathlib.Path(arg)
    if not p.is_file():
        continue
    s = p.read_text()
    changed = False
    if old in s and "build/storage-bindings/original-bindings.o" not in s:
        s = s.replace(old, new)
        changed = True
    if bindings_old in s and "def load_record(p):" not in s:
        s = s.replace(bindings_old, bindings_new)
        changed = True
    if changed:
        p.write_text(s)
        print(f"Patched {p}: storage bindings handling")
