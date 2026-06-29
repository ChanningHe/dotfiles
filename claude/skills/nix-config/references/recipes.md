# Recipes — Adding Modules, Services, Packages, Hosts

The central reference for extending nix-config. Each recipe maps an intent ("add X") to the directory, file template, and wiring step. Excerpts come from the live repo; where simplified for clarity, that is called out.

## Contents

- [Decision tree: locating the right file](#decision-tree-locating-the-right-file)
- [Recipe 1: Add a drop-in optional service (no options)](#recipe-1-add-a-drop-in-optional-service-no-options)
- [Recipe 2: Add a reusable module with options](#recipe-2-add-a-reusable-module-with-options)
- [Recipe 3: Add a custom package](#recipe-3-add-a-custom-package)
- [Recipe 4: Override an existing nixpkgs package](#recipe-4-override-an-existing-nixpkgs-package)
- [Recipe 5: Add a home-manager program or dotfile](#recipe-5-add-a-home-manager-program-or-dotfile)
- [Recipe 6: Add a desktop (system + user halves)](#recipe-6-add-a-desktop-system--user-halves)
- [Recipe 7: Add a new host](#recipe-7-add-a-new-host)
- [Recipe 8: Wire a service that needs a secret](#recipe-8-wire-a-service-that-needs-a-secret)
- [Common pitfalls](#common-pitfalls)

## Decision tree: locating the right file

Match the intent to exactly one row before touching files:

| Intent | Location |
|---|---|
| System package every host should have | `environment.systemPackages` in `hosts/common/core/default.nix` (universal) or in a specific host's `default.nix` |
| Reusable system feature, hosts opt in by importing, no knobs | `hosts/common/optional/services/<name>.nix` (or `…/system/`, `…/desktop/`) |
| Reusable system feature with `enable` + options | `modules/hosts/{common,nixos,darwin}/<name>/default.nix` (auto-discovered) |
| Package not in nixpkgs | `pkgs/common/<name>/package.nix` (auto-discovered) |
| Tweak to an existing nixpkgs package | `overlays/default.nix` (`modifications` or `linuxModifications`) |
| User dotfile / shell program, cross-platform | `home/<user>/common/core/<feature>.nix`, then add to `home/<user>/common/core/default.nix` imports |
| User feature, platform-specific | append to `home/<user>/common/core/{nixos,darwin}.nix` |
| Opt-in user feature category | `home/<user>/common/optional/<category>/<feature>.nix`, imported by `home/<user>/<host>.nix` |
| Per-host home tweak (session var, or feature flags such as `sshClients.enabledHosts` defined by the SSH module at `home/<user>/common/core/ssh.nix`) | `home/<user>/<host>.nix` directly |
| Brand new NixOS / Darwin host | `hosts/{nixos,darwin}/<host>/default.nix` (see Recipe 7) |

The two tiers ("optional" file vs `modules/` module) exist because an optional file is just imports — fastest path when the feature is a single attrset every host either wants or doesn't. A module under `modules/` is the right shape once two or more hosts need the same feature with different inputs (different ZFS targets, different log levels). Options provide a typed interface and prevent copy-paste drift; per-host variance for the simple case is expressed through `serviceInfo` in `nix-secrets` rather than Nix options.

## Recipe 1: Add a drop-in optional service (no options)

Pattern source: `/Volumes/Codes/nix-src/nix-config/hosts/common/optional/services/docker.nix`.

Create one file under `hosts/common/optional/services/`. It is a plain NixOS module — no `options` block, just `config` (implicit). Pull host-specific data from `config.hostSpec.serviceInfo.<hostName>.<key>` with `or { }` fallback so unconfigured hosts do not break evaluation.

Simplified shape (the live file also wires `systemd.services.docker.{after,requires,wants}` to NFS / NVMe-oF `.mount` units derived from `inputs.nix-secrets`, gated by `networkStorage.client.nfs.enable` and `nvmeofStorage.enable`):

```nix
{ config, lib, inputs, utils, ... }:
let
  hostname = config.hostSpec.hostName;
  dockerConfig = config.hostSpec.serviceInfo.${hostname}.docker or { };
in
{
  virtualisation.docker = {
    enable = lib.mkDefault true;
    daemon.settings = {
      experimental = true;
      default-address-pools = dockerConfig.defaultAddressPools or [
        { base = "172.17.0.0/16"; size = 24; }
      ];
    };
  };
}
```

Enable on a host by adding the path to the `lib.flatten` imports in `hosts/nixos/<host>/default.nix`:

```nix
imports = lib.flatten [
  ./hardware-configuration.nix
  (map lib.custom.relativeToRoot [
    "hosts/common/core"
    "hosts/common/optional/services/docker.nix"
  ])
];
```

The file stays small because per-host variance lives in `serviceInfo` rather than module options.

## Recipe 2: Add a reusable module with options

Pattern source: `/Volumes/Codes/nix-src/nix-config/modules/hosts/nixos/znapzend/default.nix`.

Place the module under `modules/hosts/<platform>/<name>/default.nix` (use `common/` if the `config` body works on both NixOS and Darwin). It is picked up automatically — `modules/hosts/{common,nixos,darwin}/default.nix` calls `lib.custom.scanPaths` to import every subdirectory.

Skeleton (the real module exposes a richer `identity.{sopsKey,sopsFile,path}` triple — see the source for the full surface):

```nix
{ config, lib, ... }:
let cfg = config.znapzendSsh; in
{
  options.znapzendSsh = {
    enable = lib.mkEnableOption "znapzend SSH plumbing";
    identity = {
      sopsKey  = lib.mkOption { type = lib.types.str;  default = "znapzend/ssh_private_key"; };
      sopsFile = lib.mkOption { type = lib.types.path; };
      path     = lib.mkOption { type = lib.types.str;  default = "/run/secrets/znapzend_ssh_key"; };
    };
    targets = lib.mkOption {
      default = { };
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          hostName      = lib.mkOption { type = lib.types.str; };
          user          = lib.mkOption { type = lib.types.str; };
          port          = lib.mkOption { type = lib.types.port; default = 22; };
          hostPublicKey = lib.mkOption { type = lib.types.str; };
        };
      });
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets.${cfg.identity.sopsKey} = {
      sopsFile = cfg.identity.sopsFile;
      mode = "0400"; path = cfg.identity.path;
    };
    programs.ssh.extraConfig = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: t: ''
      Host ${name}
        HostName ${t.hostName}
        User ${t.user}
        Port ${toString t.port}
        IdentityFile ${cfg.identity.path}
        StrictHostKeyChecking yes
    '') cfg.targets);
  };
}
```

Enable on a host:

```nix
znapzendSsh = {
  enable = true;
  identity.sopsFile = "${inputs.nix-secrets}/secrets/Poecilia.yaml";
  targets.backup-nas = {
    hostName = "10.0.0.5"; user = "backup";
    hostPublicKey = "ssh-ed25519 AAAA...";
  };
};
```

As soon as two hosts need the feature with different inputs, an options-driven module keeps each host's `default.nix` declarative (data, not Nix logic). The `lib.mkIf cfg.enable` guard means every host can import the directory tree without paying for unused features.

## Recipe 3: Add a custom package

Pattern source: `/Volumes/Codes/nix-src/nix-config/pkgs/common/cd-gitroot/package.nix`.

Create one file at `pkgs/common/<name>/package.nix`. The flake calls `nixpkgs.lib.packagesFromDirectoryRecursive` on `pkgs/common`, and the overlay re-applies the same call to fold it into `pkgs.<name>` for every host.

Real shape:

```nix
{ lib, stdenv, fetchgit }:
stdenv.mkDerivation {
  pname = "cd-gitroot";
  version = "66f6ba7549b9973eb57bfbc188e29d2f73bf31bb";
  src = fetchgit {
    url = "https://github.com/mollifier/cd-gitroot";
    hash = "sha256-pLdF8wbkA9mPI5cg8VPYAW7i3cWNJX3+lfAZ5cZPUgE=";
  };
  dontBuild = true;
  installPhase = ''
    install -m755 -D cd-gitroot.plugin.zsh --target-directory $out/share/zsh/cd-gitroot/
  '';
  meta = { license = lib.licenses.mit; };
}
```

For Rust use `rustPlatform.buildRustPackage { … cargoHash = …; }`; for GitHub releases use `fetchFromGitHub { owner; repo; rev; hash; }`. The function arguments at the top are auto-supplied by `callPackage`.

Consume from any host: `environment.systemPackages = with pkgs; [ cd-gitroot ];`. Build standalone: `nix build .#packages.x86_64-linux.cd-gitroot`.

Dropping a file into `pkgs/common/` is the only step. No flake edit, no overlay edit, no host edit beyond the consumer line — the discovery is structural.

## Recipe 4: Override an existing nixpkgs package

Edit `/Volumes/Codes/nix-src/nix-config/overlays/default.nix`. Three slots exist:

- `modifications` — applied on every platform.
- `linuxModifications` — applied only when `prev.stdenv.isLinux`.
- `unstable-packages` — already wires `pkgs.unstable` to `nixpkgs-unstable`; reach for `pkgs.unstable.foo` rather than overriding when you just need a newer version.

Live structure:

```nix
linuxModifications = final: prev: prev.lib.optionalAttrs prev.stdenv.isLinux {
  # neovim = final.unstable.neovim;
};
modifications = final: prev: {
  # foo = prev.foo.overrideAttrs (old: { patches = old.patches ++ [ ./fix.patch ]; });
};
```

The Linux split exists because Darwin's nixpkgs channel is separate (`nixpkgs-darwin`), and many overrides are only meaningful on one platform. `lib.optionalAttrs` makes the attribute literally absent on the other side, which is stricter than `lib.mkIf` and prevents "unknown attribute" errors at evaluation.

## Recipe 5: Add a home-manager program or dotfile

Pattern source: `/Volumes/Codes/nix-src/nix-config/home/channinghe/common/core/` and the host files in `home/channinghe/`.

Variants below correspond to rows 6–9 of the decision tree; the snippets show the unique per-variant content rather than re-listing the routing rule.

### 5a. Cross-platform feature

`home/<user>/common/core/default.nix` selects `./${platform}.nix` automatically from `hostSpec.isDarwin`, so the new feature file should be platform-agnostic — anything platform-conditional belongs in `nixos.nix` / `darwin.nix` instead.

### 5b. Platform-specific feature

Append directly to `home/<user>/common/core/darwin.nix` (Mac only) or `nixos.nix` (Linux only). Real excerpt from `darwin.nix` (uncommented packages only):

```nix
home.sessionPath = [ "/opt/homebrew/bin" ];
home.packages = with pkgs; [
  coreutils
  waka
  kitty
];
```

### 5c. Opt-in feature category

The host home file uncomments the category import:

```nix
# home/channinghe/Annulatus.nix
imports = [
  common/core
  common/optional/desktops              # whole category
  common/optional/browsers/firefox.nix  # or a single file
];
```

### 5d. Per-host tweak (no new file)

Edit `home/<user>/<host>.nix`. Live example from `home/channinghe/Poecilia.nix`:

```nix
home.sessionVariables = {
  DOCKER_DATA = "/mnt/rpool/ConfigData/DockerConfig/DOCKER_DATA";
};
sshClients.enabledHosts = [ "Pseudomugil" "nixos-rl" ];
```

`common/core` is what the user expects everywhere; `common/optional/` is the feature menu; the `<host>.nix` file is the per-host order ticket. Each layer reads as a tighter scope, so drift is visible in diffs.

## Recipe 6: Add a desktop (system + user halves)

Desktops cross the system/home boundary — the compositor needs a NixOS module enabled at the system level, the keybinds belong to home-manager. Pattern: `niri`.

System half — `/Volumes/Codes/nix-src/nix-config/hosts/common/optional/desktop/niri.nix`:

```nix
{ pkgs, inputs, ... }:
{
  imports = [ inputs.niri.nixosModules.niri ];
  programs.niri.enable = true;
  xdg.portal.config.niri = {
    default = [ "gnome" "gtk" ];
    "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
  };
}
```

User half — `/Volumes/Codes/nix-src/nix-config/home/channinghe/common/optional/desktops/niri.nix`: declares `programs.niri.settings` (keybinds, layout, startup). This works because the NixOS module auto-imports a home-manager submodule.

Wire both: add the system file to the host's `imports`, and add `common/optional/desktops` (or the single `niri.nix`) to the home file. Forgetting either half is the most common bug — the daemon comes up with no config, or the config exists but nothing launches it.

## Recipe 7: Add a new host

For NixOS, prefer the scripted path — `just new-host <name>` scaffolds the host directory and the `home/<user>/<name>.nix` file, then `just spawn <name> -d <ip> --disk-layout <layout>` runs disk + install. Disk-layout values supported by the spawn flow are the keys under `disko/layouts/` (e.g. `ext4`, `zfs-impermanence-luks`); the `default-disk-config` host option pins the matching layout when no flag is passed. On the first rebuild after a fresh provision, set `hostSpec.useAtticCache = false;` so the host does not hang on the LAN-only binary cache before routing is healthy.

For Darwin, no provisioning script — create `hosts/darwin/<name>/default.nix` (no `hardware-configuration.nix` needed) and `home/<user>/<name>.nix`, then run `just rebuild` on the Mac itself. Set `system.stateVersion = 6;` (integer for nix-darwin, not a string).

Secrets pieces are user-operated. They consist of (1) a host age key registered in `.sops.yaml` under `keys:` and granted access to the relevant `creation_rules`, (2) a password hash in `secrets/shared.yaml` keyed under `users.<username>.hashedPassword`, and (3) per-host data in `secrets/<host>.yaml` matching the `serviceInfo` / `networkStorageInfo` / `nvmeofInfo` shapes consumed by modules. Do not script edits to encrypted files — the user runs `sops` directly.

## Recipe 8: Wire a service that needs a secret

The Nix side is mechanical; the secret value itself is written by the user with `sops`. Pattern source: `/Volumes/Codes/nix-src/nix-config/hosts/common/optional/services/attic.nix`.

`isDarwin` arrives via `specialArgs` rather than `config.hostSpec.isDarwin` to dodge infinite recursion on early-evaluated modules; the module header is explicit:

```nix
{ config, lib, pkgs, inputs, isDarwin, ... }:
let
  userGroup =
    if isDarwin then "staff"
    else config.users.users.${config.hostSpec.username}.group;
in
{
  sops.secrets."attic/token" = {
    sopsFile = "${inputs.nix-secrets}/secrets/shared.yaml";
    mode = "0400";
    owner = config.hostSpec.username;
    group = userGroup;
  };

  sops.templates."attic-netrc" = {
    content = ''
      machine ${endpointHost}
      password ${config.sops.placeholder."attic/token"}
    '';
    owner = config.hostSpec.username;
    mode = "0600";
  };
}
```

`sops.placeholder` is preferred over inlining because rendered templates land at `/run/secrets/…` with the substitution applied at activation. `sops.secrets."x".path` only gives the raw decrypted value; templates are how to wrap it in surrounding format (`netrc`, `toml`, env files).

## Common pitfalls

- `lib.mkDefault` vs `lib.mkForce`: `mkDefault` lets a more specific module override; `mkForce` wins against everything except another `mkForce`. Use `mkDefault` in shared layers (`hosts/common/core`, optional modules), `mkForce` in host files only when a default is actively wrong. Reaching for `mkForce` in a shared file is a smell.
- Darwin compatibility for user attrs: `users.users.<u>.group` does not exist on Darwin. Wrap Linux-only fields with `lib.optionalAttrs pkgs.stdenv.isLinux { group = "wheel"; extraGroups = [ "docker" ]; }` so the attrset shape stays valid across platforms.
- Guarding optional file lists: when an `imports` list contains files that only make sense on one platform, gate with `lib.optionals (!config.hostSpec.isDarwin) [ … ]` inside `lib.flatten`. `lib.optionals` returns `[]` when the predicate is false, so flatten swallows it.
- `lib.flatten` on the imports list: imports must be a flat list of paths, but `(map relativeToRoot [ … ])` returns a list — `lib.flatten` lets you mix raw paths (`./hardware-configuration.nix`) with mapped lists in the same `imports`. Forgetting it surfaces as "expected a path, got a list".
- `useAtticCache = false` for new hosts: the Attic binary cache is on the LAN; a fresh host with no network route yet will hang on substitutes. Set `hostSpec.useAtticCache = false;` in the first rebuild, switch it back on once routing is healthy.
- `isDarwin` from `specialArgs`, not `config.hostSpec.isDarwin`, inside `attic.nix` and similar early-evaluated modules — the latter creates infinite recursion because `hostSpec` is itself being assembled when the module evaluates.

