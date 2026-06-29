# commands.md — justfile and rebuild flow

## Contents

- [Daily commands](#daily-commands)
- [New-host provisioning](#new-host-provisioning)
- [Remote operations](#remote-operations)
- [ISO and installer](#iso-and-installer)
- [Secrets operations](#secrets-operations)
- [Maintenance](#maintenance)
- [Automatic pre and post hooks](#automatic-pre-and-post-hooks)
- [Dev shell](#dev-shell)
- [rebuild.sh argument forms](#rebuildsh-argument-forms)
- [spawn.sh internals](#spawnsh-internals)

All commands run from `/Volumes/Codes/nix-src/nix-config`. The repository ships its own `just` recipes; this file mirrors what `just --list` shows, grouped by use case.

Commands listed here are for the user to run; the agent should suggest, not execute. The user also runs all `git` operations.

## Daily commands

| Command | What it does |
| --- | --- |
| `just rebuild` | Switch the current host. Calls `scripts/rebuild.sh`; prefers `nh os switch` / `nh darwin switch` when `nh` is on `PATH`, otherwise falls back to `sudo nixos-rebuild switch` / `darwin-rebuild switch`. On Darwin with no `nh` and no `darwin-rebuild` yet, the script first builds `.#darwinConfigurations.<host>.system` and invokes the freshly-built `result/sw/bin/darwin-rebuild` — this is what makes the first-ever switch on a clean Mac work. On success and a clean tree, tags HEAD as `buildable-<YYYYMMDDHHMMSS>` so you can locate the last known-good commit. |
| `just build` | Dry-run via `scripts/rebuild.sh build`. Builds the system closure but does not activate. |
| `just rebuild-trace` | Switch with the trace flag forwarded explicitly to `nixos-rebuild`/`darwin-rebuild`, then runs `just check` (same tail as `rebuild-full`). |
| `just rebuild-full` | Switch, then `just check`. Slow; use before pushing. |
| `just check [ARGS]` | `nix flake check --impure --keep-going --show-trace` against the main flake, then the same against the nested `nixos-anywhere/` flake (separate flake for the installer pipeline). |
| `just diff` | `git diff` filtered with `:!flake.lock` so churn from input updates does not drown signal. |
| `just update` | `nix flake update` — bumps every input in `flake.lock`. |
| `just rebuild-update` | `update` then `rebuild`. |
| `just update-nix-secrets` | `cd ../nix-secrets`, then `git fetch && (git rebase > /dev/null 2>&1 \|\| true)`, then `nix flake update nix-secrets --timeout 5`. Rebase failures are silently ignored, so a dirty or diverged `nix-secrets` checkout will still let the rebuild proceed. Runs automatically before every rebuild (see hooks below). |
| `just check-sops` | Verify SOPS-nix actually decrypted at activation. Runs automatically after every rebuild. |
| `just reset-repo` | `git fetch origin && git reset --hard origin/master`. Destructive — discards every local change in the working tree, no confirmation. |

`scripts/rebuild.sh` on Darwin also bootstraps `~/.config/nix/nix.conf` (enables `nix-command flakes`), installs xcode-select tools, and runs the Homebrew install if `/opt/homebrew/bin/brew` is missing. That bootstrap path is why a fresh Mac can run `just rebuild` from a clean checkout.

## New-host provisioning

| Command | What it does |
| --- | --- |
| `just new-host <name>` | Phase 0 only: `scripts/provision-nixos.sh -n <name> --phases 0`. Interactive prompts for disk layout, IPv4 / gateway / DNS / hostId. Scaffolds `hosts/nixos/<name>/default.nix` from `hosts/host-template.nix.placeholder` and `home/channinghe/<name>.nix` from `home/channinghe/home-template.nix.placeholder`, and inserts a stanza into `../nix-secrets/nix/network.nix`. No target machine touched. |
| `just spawn <name> [args]` | `scripts/spawn.sh` — full end-to-end provisioning driver. Idempotent and resumable; safe to re-run after a failure. See internals below. |

Common `spawn` arguments:

- `-d <ip>` / `--destination <ip>` — required for `disk` and `install`.
- `--port <p>` — SSH port; defaults to `${BOOTSTRAP_SSH_PORT:-22}` (env-overridable, set to `22` in `shell.nix`).
- `-u <user>` — target user (default `channinghe`, overridable via `BOOTSTRAP_USER`).
- `--disk-layout {ext4|btrfs|zfs|zfs-mirror}` — passed to the scaffold template; matches `lib.custom.bootDiskLayout` layouts in `lib/boot-disk.nix`.
- `--ip4`, `--gateway4`, `--dns`, `--host-id` — non-interactive scaffold values.
- `--build-strategy {no-external|no-remote|on-target}` — controls where `nixos-anywhere` builds (default `no-external`, which sets `external-builders = []` for nixos-anywhere; that disables every external builder, `nix-vz-builder` being the common one in this repo).
- `--only <step>` / `--from <step>` / `--skip <step>` — step filter. Steps: `scaffold`, `secrets`, `disk`, `install`.
- `-y`, `--dry-run`, `--debug`.

## Remote operations

| Command | What it does |
| --- | --- |
| `just deploy <name> [extra]` | `nix run .#deploy -- .#<name> [extra]`. Uses deploy-rs from `flake.nix` outputs; provides auto-rollback if activation fails. This is the standard way to **update** an already-installed host. |
| `just sync <USER> <HOST> <PATH>` | `rsync -av --filter=':- .gitignore' -e "ssh -l <USER> -oport=22" . <USER>@<HOST>:<PATH>/nix-config`. Mirrors the working tree (not just committed files) to a remote, respecting `.gitignore`. |
| `just build-host <host>` | `nixos-rebuild --target-host <host> --use-remote-sudo --show-trace --impure --flake .#<host> switch`. Direct remote rebuild without deploy-rs; no rollback safety net. |

## ISO and installer

- `just iso` — `nix build --impure .#nixosConfigurations.iso.config.system.build.isoImage`, then symlinks `latest.iso → result/iso/*.iso`. Removes `result/` first because libvirtd refuses to use a replaced symlink target.
- `just iso-install <DRIVE>` — depends on `iso`, then `sudo dd ... of=<DRIVE> bs=4M status=progress oflag=sync`. The source is picked via `eza --sort changed result/iso/*.iso | tail -n1`, so `eza` must be on `PATH`. `<DRIVE>` is a block device like `/dev/sdX`.

## Secrets operations

These edit `../nix-secrets/.sops.yaml` and `secrets/*.yaml`.

| Command | What it does |
| --- | --- |
| `just age-key` | `nix-shell -p age --run "age-keygen"`. Prints a fresh age key on stdout. |
| `just rekey` | Calls `sops-rekey`: iterates every `secrets/*.yaml` in `../nix-secrets` and runs `sops updatekeys -y` so the file is re-encrypted to the current creation-rules recipient list. Run after editing `.sops.yaml`. |
| `just sops-update-user-age-key <USER> <HOST> <KEY>` | Add or update the `&<USER>_<HOST>` age anchor. |
| `just sops-update-host-age-key <HOST> <KEY>` | Add or update the `&<HOST>` host anchor. |
| `just sops-add-creation-rules <USER> <HOST>` | Composes `sops-add-host-creation-rules` and `sops-add-shared-creation-rules` (both runnable independently). Generates `<host>.yaml` and `shared.yaml` creation-rule entries that reference both anchors. |
| `just check-sops` | Already listed above. On Linux, greps the last 10 minutes of journalctl for `Starting sops-nix activation` / `Finished sops-nix activation`; fails if activation started but did not finish. On Darwin it only checks whether `/run/secrets` or `$HOME/.config/sops` exists and always exits 0. |

## Maintenance

`just disko <DRIVE> <PASSWORD>` writes `<PASSWORD>` to `/tmp/disko-password`, then runs disko in `--mode disko` against `disks/btrfs-luks-impermanence-disko.nix` with `--arg disk` and `--arg password`, then removes the file. **Currently broken**: no `disks/` directory exists in the repo. The real disko layouts live in `hosts/common/disks/{ext4,btrfs,zfs,zfs-mirror}-disk.nix` (per `lib/boot-disk.nix` lines 22-25); the spawn pipeline uses those. Treat `just disko` as dead until the recipe is updated.

`just attic-push` pushes every non-`.drv` store path to the `homielab` attic remote. `just attic-push-path <PATHS>` pushes only the listed paths. The cache configuration lives in `hosts/common/optional/services/attic.nix`; the client side is added by the relevant host module.

## Automatic pre and post hooks

The `rebuild` family declares dependencies in the justfile so they always run:

- `rebuild-pre: update-nix-secrets` — pulls and rebases `../nix-secrets`, then `nix flake update nix-secrets --timeout 5`. This is why `rebuild` always sees the latest secrets even if you forgot to bump the input. Also runs `git add --intent-to-add .` so flakes see newly-created (but unstaged) files.
- `rebuild-post: check-sops` — runs after `rebuild`. Fails loudly if any sops-managed file did not decrypt, which is the most common silent breakage after a key rotation.

`build` only depends on `rebuild-pre` (no point checking sops on a dry run). `rebuild-full` and `rebuild-trace` both run `rebuild-post` as well, so they exercise the full pre/rebuild/check-sops loop.

## Dev shell

`nix develop` enters `shell.nix` (referenced from `flake.nix devShells`). The `nativeBuildInputs` are: `nix`, `home-manager`, `nh`, `git`, `just`, `pre-commit`, `deadnix`, `sops`, `jq`, `yq-go`, `age`, `ssh-to-age`. The `pre-commit-check` shellHook additionally puts `nixfmt`, `deadnix`, `shfmt`, `shellcheck` on `PATH`.

`spawn.sh` independently checks for `git nix ssh ssh-keygen ssh-to-age sops yq jq rsync nix-instantiate` (`REQUIRED_TOOLS`); `rsync`, `ssh`, `ssh-keygen`, `nix-instantiate` come from the host PATH, not the dev shell. It also detects `gum` (`HAS_GUM`) and falls back to a plain `read` prompt if absent.

## rebuild.sh argument forms

The script is positional. `HOST` defaults to `$(hostname)` and `ACTION` to `switch`.

| Invocation | Effect |
| --- | --- |
| `scripts/rebuild.sh` | `ACTION=switch`, `HOST=$(hostname)` — the default daily path. |
| `scripts/rebuild.sh build` | `ACTION=build` — dry-run. Builds the closure, does not activate, does not tag. |
| `scripts/rebuild.sh trace` | `switch` with `--show-trace` forwarded to the underlying rebuild tool. |
| `scripts/rebuild.sh <hostname>` | Switch using `.#<hostname>` instead of `$(hostname)`. **Caveat**: this only takes effect on the non-`nh` fallback path (`sudo nixos-rebuild` / `darwin-rebuild`). When `nh` is on `PATH` (the preferred path), the script invokes `nh os/darwin $ACTION . -- --impure --show-trace` and the host argument is ignored — uninstall `nh` or invoke `nixos-rebuild` directly to switch under a non-default host name. |

The `buildable-*` tag is only written when both `git diff --exit-code` and `git diff --staged --exit-code` are clean — uncommitted changes mean the working tree is not what was actually built, so tagging would lie.

## spawn.sh internals

`spawn.sh` is a small state machine. On every run it:

1. Detects **repo state**: is `hosts/nixos/<host>/default.nix` present (scaffold)? Does `../nix-secrets/secrets/<host>.yaml` decrypt to a `keys.ssh_host_ed25519_key` (secrets)? Does the host module pin `disk = "/dev/..."` (disk)? Is `facter.json` present?
2. Detects **target state** over SSH, with five labels:
   - `UNREACHABLE` — SSH refused / timed out. `disk` and `install` cannot proceed.
   - `NON_NIXOS` — no `nixos-version` on the box. `nixos-anywhere` will kexec into the installer.
   - `INSTALLER` — root is `tmpfs`, `overlay`, or `squashfs`. Skip kexec; pass `--phases disko,install,reboot`.
   - `INSTALLED_THIS` — `hostname` on the target equals `<name>`. `install` is skipped (system already in place); use `just deploy` to update.
   - `INSTALLED_OTHER` — already-installed NixOS with a different hostname. Confirmation required before wiping.
3. Builds a **plan** from `(repo state, target state)`, then applies `--only` / `--from` / `--skip` filters. Each of the four steps (`scaffold`, `secrets`, `disk`, `install`) becomes either `[run]` or `[skip]`.
4. Prints the plan via `gum` if installed, plain text otherwise, and asks for confirmation (unless `-y`).
5. Runs the enabled steps. `install` is gated by `nix_secrets_gate`, which blocks until `../nix-secrets` has no uncommitted changes — the flake consumes `nix-secrets` as a locked remote input, so local edits in `scaffold` / `secrets` are invisible to `.#<host>` evaluation until pushed and re-locked.

Because every step is guarded by the detection result, re-running `just spawn <name>` after a network hiccup is safe: completed steps short-circuit, and `--from install` is the standard way to retry the long phase.

