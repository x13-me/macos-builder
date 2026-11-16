#!/usr/bin/env python3
import pathlib
import subprocess
import sys

def main() -> int:
    if len(sys.argv) < 2:
        print("usage: merge-storage-bindings.py <storage-bindings-dir> [ram-block-dir]", file=sys.stderr)
        return 2
    d = pathlib.Path(sys.argv[1])
    ram = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else None
    sources = [
        d / "virtio-original-bindings.S",
        d / "ram-block-original-bindings.S",
    ]
    if ram:
        sources.append(ram / "original-bindings.S")
    merged = {}
    for src in sources:
        if not src.is_file():
            continue
        for line in src.read_text().splitlines():
            line = line.strip()
            if line.startswith(".set "):
                try:
                    _, rest = line.split(None, 1)
                    name, value = rest.split(",", 1)
                    merged.setdefault(name.strip(), value.strip())
                except Exception:
                    pass
    if merged:
        sfile = d / "merged-original-bindings.S"
        ofile = d / "original-bindings.o"
        sfile.write_text("".join(f".globl {n}\n.set {n}, {v}\n" for n, v in sorted(merged.items())))
        for cmd in (
            ["xcrun", "clang", "-target", "arm64-apple-ios17.0", "-Werror", "-Wno-incompatible-sysroot", "-c", str(sfile), "-o", str(ofile)],
            ["clang", "-target", "arm64-apple-ios17.0", "-Werror", "-Wno-incompatible-sysroot", "-c", str(sfile), "-o", str(ofile)],
        ):
            try:
                subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                print(f"[storage-bindings] merged {len(merged)} symbols -> {ofile}")
                return 0
            except Exception:
                continue
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
