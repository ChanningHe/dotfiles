---
name: nix-config
description: Extends and operates the user's NixOS + Darwin monorepo at /Volumes/Codes/nix-src/{nix-config,nix-secrets}. Use when adding or editing a host, user, home-manager module, system module, service, package, overlay, or sops secret; when wiring hostSpec, networkInfo, serviceInfo, or sshClientsInfo from nix-secrets; when touching files under hosts/, home/, modules/, pkgs/, overlays/, lib/, or flake.nix; when invoking just recipes (rebuild, spawn, deploy, check, update, attic-push) or running nixos-rebuild, darwin-rebuild, nh, deploy-rs, nixos-anywhere, disko, sops, or age; when debugging hostSpec assertions, mismatched system.stateVersion (string for NixOS, int for Darwin), broken scanPaths auto-imports, or sops decryption failures; whenever a .nix file in this repo is the target, even when the user just says "add module", "add service", or "rebuild".
---

# nix-config

Operating manual for `/Volumes/Codes/nix-src/nix-config` (public logic) and `/Volumes/Codes/nix-src/nix-secrets` (private data, separate flake input). The repo manages 8 NixOS hosts plus 1 Darwin host through a unified flake. This skill encodes the conventions so a new session can add or modify a module without re-reading the whole tree.

Primary use case: adding or extending home / host modules. The decision tree below routes you to the right pattern; everything else (hosts, packages, overlays, secrets) is built around the same data bus.

## Core mental model

The repo has three composition lanes, all wired through one data bus.

**Lane 1 — Hosts.** Each host lives at `hosts/{nixos,darwin}/<HostName>/default.nix` and is a thin file: it sets `hostSpec.hostName`, declares networking, then cherry-picks modules from `hosts/common/{core,optional,users}`. `hosts/common/core` is mandatory and provides hostSpec, sops, ssh, home-manager wiring. `hosts/common/optional/**` is opt-in — nothing under `optional/` is auto-imported; the host config explicitly lists each file via `lib.custom.relativeToRoot`. `hosts/common/users/<u>` adds a user to the host.

**Lane 2 — Home.** Each `(user, host)` pair lives at `home/<user>/<HostName>.nix` and imports `common/core` plus selected `common/optional/<cat>`. `home/<user>/common/core/default.nix` picks the platform variant via `./${platform}.nix` where `platform = if hostSpec.isDarwin then "darwin" else "nixos"` — a normal Nix import, not magic.

**Lane 3 — Modules.** Reusable options-providing modules live under `modules/hosts/{common,nixos,darwin}/<name>/` and `modules/home/`. These are auto-imported by `lib.custom.scanPaths` from the corresponding `default.nix` (e.g. `modules/hosts/nixos/default.nix` scans its directory). Dropping a `.nix` file (or directory containing `default.nix`) here wires it in. The module exposes options like `<name>.enable = true`; the host turns it on by setting that option, not by importing the file.

**The data bus.** `modules/common/host-spec.nix` defines the `hostSpec` option tree (see `references/hostspec.md`). `hosts/common/core/default.nix` populates it once with `inherit (inputs.nix-secrets) networkInfo serviceInfo networkStorageInfo networking domain email userFullName;`. After that, every host, module, and home-manager file reads `config.hostSpec.networkInfo.hosts.${hostSpec.hostName}`, `config.hostSpec.serviceInfo.<svc>`, etc. Module code should never reach `inputs.nix-secrets` directly — that indirection is why secrets and host data can be swapped, audited, or stubbed in one place.

**Platform separation — two distinct uses of `default.nix + nixos.nix + darwin.nix`.** The pattern shows up in two places and works differently in each:

- In `modules/hosts/{common,nixos,darwin}/`, the *directory itself* is platform-scoped — `modules/hosts/nixos/foo.nix` is only loaded on NixOS hosts because `modules/hosts/nixos/default.nix` is only imported by NixOS host configs.
- In `home/<u>/common/core/`, `hosts/common/core/`, and `hosts/common/users/<u>/`, all three files coexist and `default.nix` chooses which sibling to import based on `hostSpec.isDarwin`. The naming is convention; the wiring is the explicit `./${platform}.nix` line.

## Quick recipes

Recipe numbers below match `references/recipes.md` 1-to-1. Decision tree — pick the first match:

1. New system feature, only used by some hosts, no options needed → Recipe 1 (drop-in optional service).
2. New system feature with configurable options, opt-in via `<name>.enable` → Recipe 2 (reusable module).
3. New custom package (not in nixpkgs) → Recipe 3.
4. Override a nixpkgs package → Recipe 4.
5. New home-manager dotfile or program → Recipe 5.
6. New desktop / compositor (system + home halves) → `references/recipes.md` Recipe 6 "Add a desktop (system + user halves)".
7. New host → `references/recipes.md` Recipe 7 "Add a new host (brief)".
8. Service that consumes a sops secret → `references/recipes.md` Recipe 8 "Wire a service that needs a secret".
9. New user → no dedicated recipe; mirror an existing user. See "Adding a user" below.

### Recipe 1 — drop-in optional system service

Create `hosts/common/optional/services/<name>.nix` with a config-only module:

```nix
{ config, lib, pkgs, ... }:
{
  services.<name>.enable = true;
  # ... whatever else this service needs
}
```

Then in each host that wants it, add the path to the imports list in `hosts/<platform>/<HostName>/default.nix`:

```nix
imports = lib.flatten [
  ./hardware-configuration.nix
  (map lib.custom.relativeToRoot [
    "hosts/common/core"
    "hosts/common/optional/services/<name>.nix"
  ])
];
```

Why: `hosts/common/optional/` is deliberately *not* auto-scanned. The host config is the single audit point that tells you what a machine actually runs. Real examples: `hosts/common/optional/services/docker.nix`, `attic.nix`, `tailscale.nix`. Full template: `references/recipes.md` Recipe 1.

### Recipe 2 — reusable module with options (preferred for anything configurable)

Place at `modules/hosts/nixos/<name>/default.nix` (or `darwin/`, or `common/` for cross-platform). Use the `options` + `config = lib.mkIf cfg.enable {…}` shape:

```nix
{ config, lib, pkgs, ... }:
let cfg = config.<name>;
in {
  options.<name> = {
    enable = lib.mkEnableOption "<name>";
    # ... typed options
  };
  config = lib.mkIf cfg.enable { /* ... */ };
}
```

Auto-imported by `lib.custom.scanPaths` in `modules/hosts/nixos/default.nix`. Host enables it with `<name>.enable = true;` — no import line. See `modules/hosts/nixos/znapzend/default.nix` for a real example with submodule types and sops wiring. Full template: `references/recipes.md` Recipe 2.

Why: options + scanPaths means the module ships with the framework; turning it on or off lives in the host file where humans look first. Use this over Recipe 1 whenever the feature has parameters.

### Recipe 3 — add a custom package

Create `pkgs/common/<name>/package.nix` with a derivation:

```nix
{ lib, stdenv, fetchFromGitHub, ... }:
stdenv.mkDerivation { pname = "<name>"; version = "..."; src = ...; ... }
```

Auto-discovered by `nixpkgs.lib.packagesFromDirectoryRecursive` in `flake.nix` and by the `additions` layer in `overlays/default.nix`. Available immediately as `pkgs.<name>` everywhere and as `.#packages.<system>.<name>` for external builds. Real examples: `pkgs/common/cd-gitroot/`, `mlnx-tools/`, `rdma-exporter/`. Full template: `references/recipes.md` Recipe 3.

### Recipe 4 — override an existing nixpkgs package

Edit the `modifications` block in `/Volumes/Codes/nix-src/nix-config/overlays/default.nix`:

```nix
modifications = final: prev: {
  <pkg> = prev.<pkg>.overrideAttrs (old: { /* ... */ });
};
```

For Linux-only overrides use the `linuxModifications` block instead. To pin a package to nixpkgs-unstable, write `final.unstable.<pkg>` (the `unstable-packages` layer exposes that). Full template: `references/recipes.md` Recipe 4.

### Recipe 5 — add a home-manager program or dotfile (primary workflow)

Three placement choices, ordered by reach:

1. *Cross-platform, always on for this user* → `home/<user>/common/core/<name>.nix`, then add `./<name>.nix` to the imports list in `home/<user>/common/core/default.nix`. Example: `home/channinghe/common/core/git.nix`.
2. *Platform-specific, always on* → put in `home/<user>/common/core/nixos.nix` or `darwin.nix` — those files are already imported by `default.nix` via `./${platform}.nix`.
3. *Opt-in per host* → `home/<user>/common/optional/<category>/<name>.nix`. The per-host file `home/<user>/<HostName>.nix` then adds the import. Example: `home/channinghe/common/optional/desktops/niri.nix` enabled only by hosts that import `common/optional/desktops`.

Why this split: core is the always-on baseline; optional gives per-host granularity without forking the user's whole config. The host file is again the audit point. Full template: `references/recipes.md` Recipe 5.

### Adding a host

NixOS: scaffold + remote install via `just spawn <Name> -d <ip> --disk-layout <layout>`. Darwin: create `hosts/darwin/<Name>/default.nix` + `home/<user>/<Name>.nix`, then run `just rebuild` locally on that Mac. Full file templates and the spawn state machine: `references/recipes.md` Recipe 7 "Add a new host (brief)" and `references/commands.md`.

### Adding a user

There is no dedicated recipe — mirror an existing user. Steps:

1. Copy `hosts/common/users/channinghe/` to `hosts/common/users/<new>/`. Keep the three-file split (`default.nix`, `nixos.nix`, `darwin.nix`); Nix does *not* auto-pick by platform — the host has to explicitly import the right sibling.
2. Replace username, hashed password reference, SSH keys, and home directory. Gate Linux-only attrs with `lib.optionalAttrs pkgs.stdenv.isLinux { group = "wheel"; }` so Darwin still evaluates (see Critical conventions).
3. Copy `home/channinghe/` to `home/<new>/`. Keep `common/core/{default,nixos,darwin}.nix` and any `common/optional/<cat>/` subtrees the new user needs.
4. In each host that gets the new user, import `hosts/common/users/<new>/default.nix` *and* the matching platform file (e.g. `hosts/common/users/<new>/nixos.nix`), then add `home/<new>/<HostName>.nix` to the host's home-manager users.
5. Tell the user which secrets to add to `nix-secrets`: hashed password key, SSH public key list. The user runs `sops` and `.sops.yaml` updates — see `references/nix-secrets.md`.

### Concept: referencing a secret in Nix code

You write only the Nix reference below; YAML and `.sops.yaml` edits are user-operated (see `references/nix-secrets.md`). In the module, declare the secret and reference its decrypted path:

```nix
sops.secrets."<path/in/yaml>" = {
  sopsFile = "${inputs.nix-secrets}/secrets/<HostName>.yaml"; # or shared.yaml
  owner = "root";
  mode = "0400";
};
# use: config.sops.secrets."<path/in/yaml>".path
```

Tell the user which YAML key to add (e.g. `"komodo/core_public_keys"`) and which file (`shared.yaml` for cross-host, `<HostName>.yaml` for single-host). For templated rendering (`netrc`, env files, anything where the secret is one substring of a larger format), use `sops.templates` with `config.sops.placeholder."<path>"` — see `references/recipes.md` Recipe 8.

## Critical conventions

- **`system.stateVersion` types differ by platform.** NixOS expects a string: `system.stateVersion = "25.05";`. Darwin expects an integer: `system.stateVersion = 6;`. Mixing them throws a type error in evaluation. The values track the *initial* install version and must never be bumped without reading the NixOS / nix-darwin release notes — they pin migrations, not the running version.
- **`lib.custom.relativeToRoot` takes a string, not a Path literal.** Source: `lib.path.append ../.` applied to a string fragment. Writing `lib.custom.relativeToRoot ./hosts/common/core` fails; use `lib.custom.relativeToRoot "hosts/common/core"`. The repo always wraps it in `map … [ "a" "b" "c" ]` for that reason.
- **`scanPaths` auto-imports, `optional/` does not.** `modules/hosts/{common,nixos,darwin}/<x>` lights up the moment its file lands. `hosts/common/optional/<x>` is inert until a host config names it. The split is intentional: modules define capabilities, optionals describe one machine's choices.
- **`lib.mkDefault` in base layers, `lib.mkForce` when overriding a value already wrapped in mkDefault elsewhere.** Many hostSpec fields and home settings use mkDefault so hosts can replace them with a bare assignment; if a host needs to win against another optional that also uses mkDefault, escalate to mkForce. Real example: `hostSpec.scaling = lib.mkForce "1"` in `hosts/nixos/Annulatus/default.nix`.
- **Darwin users have no `group` attribute.** When writing a shared user config under `hosts/common/users/<u>/`, gate Linux-only attrs with `lib.optionalAttrs pkgs.stdenv.isLinux { group = "wheel"; }` (and `extraGroups`, `uid`, `gid` similarly). Otherwise the Darwin evaluation errors at `users.users.<u>.group` unknown option.
- **`useAtticCache = false` for bootstrap hosts.** Default is true. A fresh host with no LAN cache reachability hangs the first rebuild on the binary cache; set `hostSpec.useAtticCache = false` until it can resolve the cache. Existing hosts with cache access leave it true.
- **Cross-platform home wiring is an explicit import.** `home/<u>/common/core/default.nix` literally writes `./${platform}.nix`. Renaming `nixos.nix` or `darwin.nix` breaks evaluation silently because the path interpolates from `hostSpec.isDarwin`.
- **The three-file pattern in `hosts/common/users/<u>/` is convention only.** Nix does not infer that `nixos.nix` is for NixOS; the host config is expected to also import `hosts/common/users/<u>/nixos.nix` (or `darwin.nix`) explicitly. Search any host file for `users/channinghe/nixos.nix` to confirm the pattern before adding a new user.
- **Secrets are user-operated.** This skill writes Nix code that references `sops.secrets."<path>"` and tells the user what YAML key to populate. It does not run `sops`, edit `.sops.yaml`, generate age keys, or rekey. The user does those steps and reports back.

## Commands cheat sheet

The most common targets. Full catalog (27 just targets) and the `nix-config/scripts/spawn.sh` state machine: `references/commands.md`.

```
just rebuild               # rebuild current host (nh os/darwin switch via nix-config/scripts/rebuild.sh)
just check                 # nix flake check
just update                # nix flake update
just spawn <Name> -d <ip> --disk-layout <ext4|zfs|btrfs|zfs-mirror>
                           # full state-driven NixOS install via nixos-anywhere
just deploy <Name>         # remote update via deploy-rs (auto-rollback)
nix develop                # enter shell with sops, age, ssh-to-age, just, gum
```

## References

Read these on demand. Each is self-contained; do not chain reads. Section pointers quote exact headings so grep-by-title works.

- `references/recipes.md` — *The* main reference. Decision tree, full file templates for adding host / service / module / package / overlay / home program / desktop / secret-using service, plus edge cases. Read this for any "add X" task before touching files. Section pointers: "Recipe 1: Add a drop-in optional service (no options)", "Recipe 2: Add a reusable module with options", "Recipe 3: Add a custom package", "Recipe 4: Override an existing nixpkgs package", "Recipe 5: Add a home-manager program or dotfile", "Recipe 6: Add a desktop (system + user halves)", "Recipe 7: Add a new host (brief)", "Recipe 8: Wire a service that needs a secret", "Common pitfalls".
- `references/architecture.md` — `flake.nix` outputs, `lib.custom` semantics (`relativeToRoot`, `scanPaths`, `bootDiskLayout`), the cherry-pick vs auto-import mechanics, host evaluation order, the inheritance diagram. Read when something imports unexpectedly or a module fails to load.
- `references/hostspec.md` — complete `hostSpec` option enumeration with types, defaults, and which file populates which field. Read when wiring a new module that reads `config.hostSpec.<something>` or when an assertion in `modules/common/host-spec.nix` fires.
- `references/nix-secrets.md` — `nix-secrets` schemas (`networkInfo`, `serviceInfo`, `networkStorageInfo`, `sshClientsInfo`, `personal`), the `.sops.yaml` structure, known secret paths, and the consumption patterns. Reference-only — the user edits these files and runs `sops`. Read when you need to tell the user what YAML key to add or which file to put it in.
- `references/commands.md` — full `justfile` catalog, `nix-config/scripts/rebuild.sh` argument forms, `nix-config/scripts/spawn.sh` state machine (`UNREACHABLE`, `NON_NIXOS`, `INSTALLER`, `INSTALLED_THIS`, `INSTALLED_OTHER`) and resumable `--from`/`--only` flags, deploy-rs targets. Read when running or composing commands.

