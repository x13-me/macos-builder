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

import re

bindings_pat = re.compile(
    r"(?m)^([ \t]*)records\s*=\s*\[json\.loads\(Path\(p\)\.with_name\('bindings\.json'\)\.read_text\(\)\)\s+for p in sys\.argv\[1:\]\]\s*$"
)

def bindings_repl(m: "re.Match[str]") -> str:
    ind = m.group(1)
    lines = [
        "def load_record(p):",
        "    bp = Path(p).with_name('bindings.json')",
        "    if not bp.is_file():",
        "        root = Path(p)",
        "        for parent in root.parents:",
        "            if parent.name == 'build':",
        "                cand = parent / 'ram-block' / 'bindings.json'",
        "                if cand.is_file():",
        "                    bp = cand",
        "                    break",
        "        if not bp.is_file():",
        "            try:",
        "                search_root = Path(p).parent.parent",
        "                for cand in search_root.rglob('bindings.json'):",
        "                    if cand.is_file():",
        "                        bp = cand",
        "                        break",
        "            except Exception:",
        "                pass",
        "    return json.loads(bp.read_text())",
        "records = [load_record(p) for p in sys.argv[1:]]",
    ]
    return "\n".join(ind + line for line in lines)

for arg in sys.argv[1:]:
    p = pathlib.Path(arg)
    if not p.is_file():
        continue
    s = p.read_text()
    changed = False
    if old in s and "build/storage-bindings/original-bindings.o" not in s:
        s = s.replace(old, new)
        changed = True
    if "def load_record(p):" not in s and bindings_pat.search(s):
        s, n = bindings_pat.subn(bindings_repl, s, count=1)
        if n:
            changed = True
    if changed:
        p.write_text(s)
        print(f"Patched {p}: storage bindings handling")
    else:
        print(f"Unchanged {p}: extra={('build/storage-bindings/original-bindings.o' in s)} bindings={( 'def load_record(p):' in s )}")
