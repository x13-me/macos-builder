#!/usr/bin/env nix
#! nix shell nixpkgs#python3 -c python3
import pathlib
import re
import sys

# Both-transports path (virtio archive force-loaded + ram block object linked separately):
# ensure original storage bindings (IOBlockStorageDevice aliases) are linked once.
old_ram = (
    "      RAM_BLOCK_OBJECT=$ROOT/build/ram-block/NativeRamBlock.o\n"
    "      test -f \"$RAM_BLOCK_OBJECT\"\n"
    "      KERNEL_EXTRA_ARCHIVES=\"$KERNEL_EXTRA_ARCHIVES $RAM_BLOCK_OBJECT\"\n"
)
new_ram = (
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

# Virtio-only/primary path: when force-loading the virtio block archive, also add bindings
# if present (some bundles ship bindings as a separate object, not inside the archive).
old_virtio = (
    "    VIRTIO_ARCHIVE=${XNU_NATIVE_VIRTIO_BLOCK_ARCHIVE:-$ROOT/build/virtio-mmio-block/libVirtioMmioBlock.a}\n"
    "    test -f \"$VIRTIO_ARCHIVE\"\n"
    "    KERNEL_EXTRA_ARCHIVES=\"$KERNEL_EXTRA_ARCHIVES -Wl,-force_load,$VIRTIO_ARCHIVE\"\n"
    "    KERNEL_ARCHIVE_DEPENDENCIES=\"$KERNEL_ARCHIVE_DEPENDENCIES $VIRTIO_ARCHIVE\"\n"
)
new_virtio = (
    "    VIRTIO_ARCHIVE=${XNU_NATIVE_VIRTIO_BLOCK_ARCHIVE:-$ROOT/build/virtio-mmio-block/libVirtioMmioBlock.a}\n"
    "    test -f \"$VIRTIO_ARCHIVE\"\n"
    "    KERNEL_EXTRA_ARCHIVES=\"$KERNEL_EXTRA_ARCHIVES -Wl,-force_load,$VIRTIO_ARCHIVE\"\n"
    "    KERNEL_ARCHIVE_DEPENDENCIES=\"$KERNEL_ARCHIVE_DEPENDENCIES $VIRTIO_ARCHIVE\"\n"
    "    for VIRTIO_BLOCK_BINDINGS in \\\n"
    "      \"$ROOT/build/storage-bindings/original-bindings.o\" \\\n"
    "      \"$ROOT/build/storage-bindings/virtio-original-bindings.o\" \\\n"
    "      \"$(dirname \"$VIRTIO_ARCHIVE\")/original-bindings.o\" \\\n"
    "      \"$ROOT/build/ram-block/original-bindings.o\"; do\n"
    "      if [ -f \"$VIRTIO_BLOCK_BINDINGS\" ]; then\n"
    "        case \" $KERNEL_EXTRA_ARCHIVES \" in\n"
    "          *\" $VIRTIO_BLOCK_BINDINGS \"*) ;;\n"
    "          *) KERNEL_EXTRA_ARCHIVES=\"$KERNEL_EXTRA_ARCHIVES $VIRTIO_BLOCK_BINDINGS\" ;;\n"
    "        esac\n"
    "        break\n"
    "      fi\n"
    "    done\n"
)

# Root rebuild kernel link may require IOBlockStorageDevice/IOStorage class impl objects
# when linking NativeVirtioBlock/NativeRamBlock (staged by prepare-root-storage-bindings.sh).
storage_impl_inject = (
    "    for STORAGE_IMPL in \\\n"
    "      \"$ROOT/build/storage-bindings/IOBlockStorageDevice.o\" \\\n"
    "      \"$ROOT/build/storage-bindings/IOStorage.o\"; do\n"
    "      if [ -f \"$STORAGE_IMPL\" ]; then\n"
    "        case \" $KERNEL_EXTRA_ARCHIVES \" in\n"
    "          *\" $STORAGE_IMPL \"*) ;;\n"
    "          *) KERNEL_EXTRA_ARCHIVES=\"$KERNEL_EXTRA_ARCHIVES $STORAGE_IMPL\" ;;\n"
    "        esac\n"
    "      fi\n"
    "    done\n"
)

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
    orig = s
    if old_ram in s and "for RAM_BLOCK_BINDINGS in" not in s:
        s = s.replace(old_ram, new_ram)
    if old_virtio in s and "for VIRTIO_BLOCK_BINDINGS in" not in s:
        s = s.replace(old_virtio, new_virtio)
    # Inject IOBlockStorageDevice/IOStorage implementation linking (idempotent).
    if "IOBlockStorageDevice.o" not in s or "for STORAGE_IMPL in" not in s:
        marker = 'KERNEL_ARCHIVE_DEPENDENCIES="$KERNEL_ARCHIVE_DEPENDENCIES $VIRTIO_ARCHIVE"\n'
        if marker in s and "for STORAGE_IMPL in" not in s:
            s = s.replace(marker, marker + storage_impl_inject)
    if "def load_record(p):" not in s and bindings_pat.search(s):
        s, _n = bindings_pat.subn(bindings_repl, s, count=1)
    if s != orig:
        p.write_text(s)
        print(f"Patched {p}: storage bindings handling")
    else:
        print(f"Unchanged {p}: ram={('for RAM_BLOCK_BINDINGS in' in s)} virtio={('for VIRTIO_BLOCK_BINDINGS in' in s)} bindings={( 'def load_record(p):' in s )}")
