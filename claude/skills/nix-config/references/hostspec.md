# hostSpec Reference

## Contents

- [What hostSpec is](#what-hostspec-is)
- [Options: identity](#options-identity)
- [Options: custom metadata](#options-custom-metadata)
- [Options: boolean flags](#options-boolean-flags)
- [Options: display](#options-display)
- [Assertions](#assertions)
- [Usage patterns](#usage-patterns)
- [When to add a new option](#when-to-add-a-new-option)

## What hostSpec is

`hostSpec` is a single `submodule` option declared in `nix-config/modules/common/host-spec.nix` and imported by both NixOS and nix-darwin via `hosts/common/core/default.nix`. The submodule sets `freeformType = attrsOf str`, which only catches *undeclared* string keys — every option listed below keeps its stricter declared type. Values land in two places: identity-shaped fields are `inherit`-ed from `inputs.nix-secrets` inside `hosts/common/core/default.nix` (`domain`, `email`, `userFullName`, `networking`, `networkInfo`, `serviceInfo`), and host-specific knobs are set in each `hosts/<platform>/<host>/default.nix`. Home-manager receives the same value via `extraSpecialArgs.hostSpec = config.hostSpec` (see `hosts/common/users/channinghe/default.nix`), so home modules destructure `{ hostSpec, ... }` at the function head instead of reaching into NixOS `config`.

## Options: identity

The "source" column distinguishes the *module declaration* from where a value actually comes from at evaluation. `hosts/common/core/default.nix:48-62` sets `username`/`handle` literally and uses `inherit (inputs.nix-secrets) ...` for the rest; the FIXME at the same file (line 53) notes that the inherit block is optional for starters who do not use nix-secrets.

| option | type | module default | source at eval | semantics |
|---|---|---|---|---|
| `username` | `str` | none (required) | set in core | Drives `users.users.<u>`, `home-manager.users.<u>`, the default `home`. |
| `hostName` | `str` | none (required) | set per host | `networking.hostName` and the key for `networkInfo.hosts.${hostName}`. |
| `handle` | `str` | none (required) | set in core | Online handle (e.g. GitHub user); ssh comments, dotfile templating. |
| `userFullName` | `str` | none (required) | `inherit` from `nix-secrets` | Real name for git, GPG uids, mailer From. |
| `domain` | `str` | none (required) | `inherit` from `nix-secrets` | Apex domain for FQDNs and Caddy vhosts. |
| `email` | `attrsOf str` | none (required) | `inherit` from `nix-secrets` | Project-defined keys. Current `nix-secrets/nix/personal.nix` exposes `user`, `notifier`, `gitHub`. |
| `home` | `str` | `/home/<u>` on Linux, `/Users/<u>` on Darwin | module default | Default is evaluated lazily inside the submodule (not at import time), so the `pkgs.stdenv.isLinux` branch here is safe — the recursion footgun called out under `isDarwin` only bites in module-level imports. |

## Options: custom metadata

Free-shape attrsets sourced from `nix-secrets` so the public repo never embeds private topology. Treat them as opaque trees and read concrete leaves with `.${hostName}` indexing. `networking`, `networkInfo`, `serviceInfo` declare `default = { }` in the module but are immediately overwritten by the `inherit` in core — the empty default is what you get if you delete that inherit (starter without secrets).

| option | type | module default | semantics |
|---|---|---|---|
| `work` | `attrsOf anything` | `{ }` | Employer-specific bundle (proxies, CAs, repos). Required when `isWork = true` (asserted). |
| `networking` | `attrsOf anything` | `{ }`, overwritten by `inherit` | Generic network knobs from secrets (DNS, search domains). |
| `networkInfo` | `attrsOf anything` | `{ }`, overwritten by `inherit` | Per-host facts, typically `networkInfo.hosts.${hostName} = { ip = ...; mac = ...; }`. |
| `serviceInfo` | `attrsOf anything` | `{ }`, overwritten by `inherit` | Per-service endpoint data; e.g. `serviceInfo.nixCacheInfo.ncps.{host,pubkey}` consumed by `nix.settings.substituters`. |
| `persistFolder` | `str` | `""` | Root path the impermanence module bind-mounts (e.g. `/persist`). Empty string only valid when impermanence is off (asserted). |
| `wifi` | `bool` | `false` | Declared marker for "host has wifi". No consumer in the current `nix-config/` tree — declared for future modules; do not rely on it gating anything today. |

## Options: boolean flags

Flags shape which optional modules and home programs activate. Defaults are tuned for a "production desktop Linux" host so a new host needs the fewest overrides. Where a flag has no current consumer it is noted explicitly — the field exists as a contract, but no module reads it yet.

| option | type | default | semantics |
|---|---|---|---|
| `isMinimal` | `bool` | `false` | Intended to skip the home-manager import for installers/recovery. |
| `isMobile` | `bool` | `false` | Laptop-shaped host; intended for power management, suspend, backlight. |
| `isProduction` | `bool` | `true` | Daily-driver vs experimental sandbox; intended to gate noisy debug services. |
| `isServer` | `bool` | `false` | Headless host; intended to disable desktop, login manager, audio. |
| `isWork` | `bool` | `false` | Pulls in work overlays; requires `work` to be non-null (asserted in `modules/common/host-spec.nix:168-172`). |
| `isDarwin` | `bool` | `false` | Manually set to `true` in Darwin hosts' `hostSpec = { ... }` block (e.g. `hosts/darwin/ChanningdeMacBook-Pro/default.nix:56`). Read where `pkgs.stdenv.isDarwin` would cause infinite recursion — see `hosts/common/core/sops.nix:29,33,71,87` and `home/channinghe/common/core/default.nix:9`. Note: there is a *separate* top-level `isDarwin` specialArg in `flake.nix:45,58` that is plumbed to `hosts/common/core/default.nix` as a module argument (line 11). That one is set automatically by the flake based on which builder is invoked; it is not `hostSpec.isDarwin`, and the two are populated independently. |
| `useYubikey` | `bool` | `false` | Declared marker; no current consumer in `nix-config/`. Intended for pam-u2f / GPG-agent ssh / udev rules when a module starts reading it. |
| `voiceCoding` | `bool` | `false` | Intended to enable the talon/cursorless stack. |
| `isAutoStyled` | `bool` | `false` | Opts the host into stylix-driven theming. |
| `useNeovimTerminal` | `bool` | `false` | Replaces the terminal-launcher binding with an embedded nvim terminal. |
| `useWindowManager` | `bool` | `true` | Set `false` on servers or pure-tty hosts to skip Hyprland/AeroSpace imports. |
| `useAtticCache` | `bool` | `true` | Adds the LAN attic substituter; turn off for hosts outside the trusted network. |
| `hdr` | `bool` | `false` | HDR-capable compositor settings. |
| `loadUserAgeKey` | `bool` | `false` | Tells the sops module to load a user-scoped age key in addition to the host key. Read at `hosts/common/core/sops.nix:87`. |

## Options: display

| option | type | default | semantics |
|---|---|---|---|
| `scaling` | `str` | `"1"` | Floating-point scale factor stored as a string (e.g. `"1.25"`) so it can be embedded into config files verbatim without re-quoting. Use `lib.mkForce` to override per host. |

## Assertions

Both assertions live in the `config` block of `modules/common/host-spec.nix:160-177`.

- `isWork && work == null` — `assertion = !isWork || (isWork && !builtins.isNull work)`.
- `impermanence enabled && persistFolder == ""` — `assertion = !isImpermanent || (isImpermanent && !("${persistFolder}" == ""))` (the `isImpermanent` local is guarded by a `config ? "system"` check so the file evaluates inside home-manager, which has no `system` namespace, without tripping).

## Usage patterns

### In a host config

`hosts/nixos/<hostName>/default.nix` only sets the deltas from defaults. The real Annulatus (`hosts/nixos/Annulatus/default.nix:65-69`) is just:

```nix
{
  hostSpec = {
    hostName = "Annulatus";
    scaling = lib.mkForce "1";
    # loadUserAgeKey = true;
  };
}
```

A mobile host with impermanence would additionally set `isMobile = true; persistFolder = "/persist";`.

### In a NixOS or Darwin module

Read fields off `config.hostSpec` and index secret trees by `hostName`:

```nix
{ config, lib, ... }:
let
  hostname = config.hostSpec.hostName;
  netInfo = config.hostSpec.networkInfo.hosts.${hostname} or { };
in
{
  networking.interfaces.eth0.ipv4.addresses = lib.optional (netInfo ? ip) {
    address = netInfo.ip;
    prefixLength = 24;
  };
}
```

### In a home-manager module

`hostSpec` is forwarded via `extraSpecialArgs`, so destructure it directly — do not pull from `config`. The `email` keys below match what `nix-secrets/nix/personal.nix` currently exposes; if your secrets define different keys, swap accordingly:

```nix
{ hostSpec, lib, ... }:
{
  programs.git = {
    enable = true;
    userName = hostSpec.userFullName;
    userEmail = hostSpec.email.gitHub or hostSpec.email.user;
  };
}
```

## When to add a new option

Add a field to `hostSpec` only when (a) at least two modules need to read it and (b) it is genuine cross-host metadata — identity, topology, or a coarse capability tier — rather than a per-feature toggle that conceptually belongs to one module. A switch that exactly one module reads should be declared as that module's own `options.<module>.enable` so the option lives next to its consumer; promoting it to `hostSpec` only obscures ownership. When the new field is a free-shape tree sourced from secrets, keep the type as `attrsOf anything` and document the expected leaf shape in the option `description` so consumers can `.<key> or { }` defensively.

