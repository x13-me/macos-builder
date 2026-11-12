# macOS builder (UniXNU)

Workflow-only repository for preparing UniXNU target-OS build artifacts on GitHub-hosted macOS runners.

This workflow is **`workflow_dispatch` only** (manual trigger). Do **not** enable automatic triggers on push/PR/schedule: macOS runners consume expensive build minutes and the build can download/process Apple restore images and produce Apple-derived/proprietary material.

## Design (Nix flake first)

Everything is nested under a flake (`flake.nix`), and scripts call the flake rather than using `nix profile install`.

- `flake.nix` defines the CI tool environment (`packages.<system>.ci-tools`, `devShells.<system>.ci/default`) and `openssl` (used to provide `OPENSSL_PREFIX`). Host tools are provided by Nix: `python3`, `cmake`, `ninja`, `llvm`/`lld`, `mtools`, `dtc`, `qemu`, `openssl`, `coreutils`, `unifdef`, `git`, `curl`, `tar`, `xz`, etc. Homebrew is not used.
- `scripts/*.sh` and `scripts/ci` are `#!/usr/bin/env nix` nix-shebang scripts that enter the flake's CI environment (`nix shell .#ci-tools .#openssl -c bash`) and run their task. Run them from the repository root so `.` resolves to this flake.
- `.github/workflows/prep-target-os.yml` checks out this builder repo, installs Nix, warms the flake env (`nix build ./builder#ci-tools`), resolves `OPENSSL_PREFIX` from the flake, and runs tool-dependent steps via `nix develop ./builder#ci -c ...` and the repo's nix-shebang scripts.

macOS-native prerequisites that remain required (not provided by Nix): **Xcode** (`xcodebuild`, SDKs, `xcrun`) and disk-image/APFS tools **`hdiutil`/`diskutil`**, which are needed for UniXNU macOS-host root/data preparation (e.g. UniXNU-qemu `scripts/build-os-root.py`).

## Targets

- **iPadOS** (default): UniXNU-qemu (`xVanTuring/UniXNU-qemu`, `qemu_root_defconfig`). Builds package/kernel/payload and runs `build-os-root.py` to prepare OS/SystemOS images, owner keys/policies, verified block drivers, and the data seed, then rebuilds kernel/payload for the root OS.
- **macOS**: configurable UniXNU device repo/ref/defconfig/IPSW and optional root-prep command for macOS-target device ports (device-specific scripts may differ).
- **both**: runs iPadOS and macOS preparation jobs in parallel via a matrix.

## Keeping proprietary output private (recommended)

GitHub Actions artifacts are convenient but are broadly accessible to repo collaborators and easy to redistribute. For Apple-derived/proprietary outputs, prefer **not** uploading artifacts publicly (`upload_artifacts: false`, the default) and instead push the prepared `UniXNU/out` tree to a **private** Nix binary cache.

The workflow can:

1. Add `UniXNU/out` to the Nix store as a store path (`nix store add-path --name unixnu-out-<target> UniXNU/out`).
2. Push that store path to a private cache:
   - **Cachix**: set `cachix_name` and provide secret `CACHIX_AUTH_TOKEN` (use a private Cachix cache).
   - **Generic Nix store URI**: set `nix_copy_to` (e.g. `s3://...`, `ssh-ng://...`) and configure credentials via repo/environment secrets as appropriate for that store.

The `scripts/push-out.sh` nix-shebang script performs the add/push when called by the workflow.

**Caveats:** these outputs are imperative build products (not normal reproducible derivation outputs) and may be large. The added store path contains the full `out/` tree, including Apple-derived or proprietary material. Pushing to a private cache avoids public artifact exposure but does **not** remove licensing or redistribution obligations. Restrict cache access accordingly.

## Usage

1. Push this repository to GitHub (private recommended).
2. Open Actions → **Prepare target OS (macOS runner)** → **Run workflow**.
3. Choose `target`: `ipados`, `macos`, or `both`.
4. For `macos`/`both`, provide `macos_device_repository`, `macos_device_ref`, `macos_defconfig`, and `macos_ipsw_url` (and `macos_root_build_command` if the device needs a custom root-prep step). Empty macOS fields are skipped with a warning when `target=both`.
5. To keep outputs off public artifacts, leave `upload_artifacts=false` and configure `cachix_name` (+ `CACHIX_AUTH_TOKEN`) or `nix_copy_to` to a private cache. Enable `upload_artifacts` only if you understand the sensitivity/redistribution implications.

## Inputs (high level)

| Input | Purpose |
| --- | --- |
| `target` | `ipados`, `macos`, or `both` |
| `unixnu_repository` / `unixnu_ref` | UniXNU source checkout |
| `xcode` | `/Applications/Xcode_<version>.app` on `macos-26` |
| `ipados_device_repository` / `ipados_device_ref` / `ipados_defconfig` / `ipados_ipsw_url` | iPadOS (UniXNU-qemu) config |
| `macos_device_repository` / `macos_device_ref` / `macos_defconfig` / `macos_ipsw_url` | macOS target config |
| `macos_root_build_command` | Optional shell command run in the device tree for macOS root prep (has `$IPSW`, `$SEED`, `$OPENSSL_PREFIX`, `$UNIXNU_DIR`, `$DEVICE_DIR`, `$OUT_DIR`, `$DEFCONFIG`) |
| `qemu_accel` | `tcg` (portable/slow) or `hvf` (may be unavailable on runners) |
| `upload_artifacts` | Upload `out` to GitHub Actions artifacts (default: **false**; warning: may include proprietary material) |
| `cachix_name` | Private Cachix cache name to push to (needs secret `CACHIX_AUTH_TOKEN`) |
| `nix_copy_to` | Nix store URI for `nix copy --to` (configure auth via secrets/env) |
| `run_smoke` / `smoke_seconds` | Optional headless QEMU smoke boot |

## Notes

- `OPENSSL_PREFIX` is resolved from the flake (`nix eval --raw ./builder#openssl.out` in CI) and passed to root-prep steps (e.g. `build-os-root.py --openssl-prefix`).
- The nixpkgs input is pinned in `flake.lock`; update with `nix flake update` in this repo if you want newer tool versions.
- Building/booting a full target OS requires device-appropriate inputs (restore image, platform seed, keys/caches/policies as required by the selected device/defconfig). The workflow masks known secrets but logs/store paths/artifacts may still contain sensitive or proprietary data.
- This repo only prepares build artifacts; it does not run workflows and should not be configured with automatic triggers.
