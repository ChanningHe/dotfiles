# nix-secrets Reference

A read-only orientation to the sibling flake at `/Volumes/Codes/nix-src/nix-secrets/`. Agents query this data when wiring modules; they do not mutate it. The user owns the age key, edits `.sops.yaml`, and runs `sops` themselves.

## Contents

- [Overview](#overview)
- [nix/ schemas](#nix-schemas)
- [.sops.yaml](#sopsyaml)
- [secrets/ inventory](#secrets-inventory)
- [Consuming secrets in modules](#consuming-secrets-in-modules)
- [What agents must not do](#what-agents-must-not-do)

## Overview

Standalone flake split into two halves: `nix/` holds plaintext attrsets ("soft" data — network layout, service tuning, SSH client config, personal identity) auto-merged by `flake.nix` via `foldl lib.recursiveUpdate { }` over every `.nix` file in the directory; `secrets/` holds sops-encrypted YAML ("hard" data — passwords, tokens, private keys, SMB credentials).

`nix-config` pulls it in as the `nix-secrets` flake input. The seam lives in `hosts/common/core/default.nix` (lines 49-62):

```nix
hostSpec = {
  username = "channinghe";
  handle   = "channinghe";
  inherit (inputs.nix-secrets)
    domain email userFullName
    networking networkInfo serviceInfo;
};
```

Modules read soft data exposed through this seam (`domain`, `email`, `userFullName`, `networking`, `networkInfo`, `serviceInfo`) via `config.hostSpec.<x>`. Schemas not re-exported through `hostSpec` — `networkStorageInfo`, `nvmeofInfo`, `sshClientsInfo` — are read directly from `inputs.nix-secrets.<x>` with an `or { }` fallback. The `hostSpec` indirection exists so host modules can shadow upstream values; the direct-read schemas are simply not yet threaded through that mechanism. (`nvmeofInfo` in particular is read directly — see the nvmeof.nix schema below.)

## nix/ schemas

### nix/network.nix

```nix
{
  networkInfo.hosts.<HostName> = {
    ip4       = "10.1.10.X";
    gateway4  = "10.1.10.1";
    ip6       = "...";          # optional
    gateway6  = "...";          # optional
    dns       = [ "10.1.10.2" ];
    easytier  = { ... };        # optional mesh config
    mac       = "...";          # optional
    interface = "eth0";         # optional
  };
  networking.ports = { tcp = { ssh = 22; }; udp = { }; };
}
```

Read pattern: `config.hostSpec.networkInfo.hosts.${config.hostSpec.hostName}`. `easytier` is consumed by `hosts/common/optional/services/easytier.nix` with an `or { }` fallback. `deploy.nix` also resolves `ip4` here (via `inputs.nix-secrets.networkInfo.hosts.${host}.ip4`) to dispatch `nixos-rebuild --target-host`.

### nix/network-storage.nix

```nix
{
  networkStorageInfo.<HostName> = {
    server = {
      nfs   = { enable = true; exports = "..."; };
      samba = { enable = true; global = "..."; <share> = { ... }; };
    };
    client = {
      nfs   = { enable = true; mounts = [ ... ]; };
      samba = { enable = true; servers = { <name> = { ... }; }; };
    };
  };
}
```

Read pattern is `inputs.nix-secrets.networkStorageInfo.${hostname}` (not via `hostSpec`) — verified at `hosts/common/optional/network-storage.nix:26`, `hosts/common/optional/autofs-darwin.nix:21`, `hosts/common/optional/darwin/darwin-smb.nix:23`, `hosts/common/optional/services/docker.nix:22`, and `modules/hosts/nixos/network-storage.nix:15`.

Samba secret wiring is asymmetric across platforms — copy the pattern from the consumer you are modeling, do not invent your own:

- NixOS (`network-storage.nix:113-117`): secret NAME is `samba-<server_name>` (dash); YAML key is `samba/<server_name>`.
- Darwin (`autofs-darwin.nix:57`, `darwin/darwin-smb.nix:49`): YAML key is `samba/<server_name>/password`.

`autofs-darwin.nix` and `darwin/darwin-smb.nix` are sibling Darwin modules, not redundant variants: the former handles NFS automounts on macOS, the latter handles SMB.

### nix/nvmeof.nix

```nix
{
  nvmeofInfo.<HostName> = {
    enable    = true;
    hostNqn   = "...";
    hostId    = "...";
    transport = "rdma";        # or "tcp"
    targets   = [{ nqn; traddr; trsvcid; label; mountPoint; fsType; options; ctrlLossTmo; reconnectDelay; }];
  };
}
```

`label` is one of several mutually-exclusive device identifiers — the schema header in `nix-secrets/nix/nvmeof.nix:6` allows any of `label | fsUuid | namespaceUuid | serial | device`. Consumed only by `hosts/common/optional/nvmeof-client.nix:10`, which reads `inputs.nix-secrets.nvmeofInfo` directly: not yet threaded through `hostSpec`, safe to read directly until/unless a host override is needed.

### nix/services.nix

Mixes two key shapes under one attrset — the most error-prone part of the schema:

```nix
{
  serviceInfo = {
    # Global keys — any host can opt in
    attic        = { servername = "..."; endpoint = "..."; };
    mail         = { enable; host; port; user; from; recipients; tls; auth; tls_starttls; zfs = { ... }; ... };
    nixCacheInfo = { ncps = { host; pubkey; }; };
    nvidiaVgpu   = { version; driverUrl; driverSha256; };

    # Per-host keys — same hostname as networkInfo.hosts
    <HostName> = {
      proxmox-ve = { ... };
      komodo     = { ... };
      docker     = { ... };
      ups        = { ... };
      znapzend   = { ... };
      incus      = { ... };
    };
  };
}
```

`mail.enable` is a real gate — `hosts/common/optional/ups.nix:30` reads `notifyEnabled = mail.enable && mail.recipients != [ ]`. Canonical fallback when reading — per-host wins, then global, then empty:

```nix
let
  hostName = config.hostSpec.hostName;
  svcCfg   = config.hostSpec.serviceInfo.${hostName}.attic
          or config.hostSpec.serviceInfo.attic
          or { };
in ...
```

`hosts/common/optional/ups.nix` and `services/attic.nix` are good live examples.

### nix/ssh-clients.nix

```nix
{
  sshClientsInfo.<HostAlias> = ''
    HostName 10.1.10.8
    User <login>
    ForwardAgent yes
  '';
}
```

Each value is a raw SSH config block (multi-line string), not structured attrs. `modules/home/ssh-clients.nix:17` reads `inputs.nix-secrets.sshClientsInfo` directly, renders entries into `~/.ssh/config.d/hosts`, and exposes `sshClients.enableAll` plus `sshClients.enabledHosts = [ ... ]` for opt-in subsets. `hosts/common/optional/darwin/root-ssh-mapping.nix:15` reuses the same data for nix-daemon's root SSH config when reaching Mac builders.

### nix/personal.nix

Identity strings consumed by mail / git / web modules. Shape (values redacted — real ones live in the private nix-secrets repo):

```nix
{
  domain       = "example.com";
  userFullName = "<Full Name>";
  email = {
    user     = "<user>@example.com";
    notifier = "<bot>@example.com";
    gitHub   = "<gh-handle>@github.com";
  };
}
```

Read as `config.hostSpec.domain`, `config.hostSpec.email.notifier`, etc.

## .sops.yaml

Two anchor pools plus a per-file `creation_rules` list. `keys.users` holds the primary age key and two YubiKey-backed keys (`yk-976`, `yk-806`); `keys.hosts` holds one age key per host, derived from that host's SSH ed25519 host key via `ssh-keyscan | ssh-to-age`.

Encryption matrix:

- `secrets/shared.yaml` — encrypted to every user anchor AND every host anchor. Anything global (Attic token, k3s join token, msmtp password, YubiKey U2F keys) lives here.
- `secrets/<HostName>.yaml` — encrypted to every user anchor plus that one host's anchor. Host-bound material (system user passwords, host-specific SSH keys, samba creds) lives here.

Adding a host's anchor requires the host to be reachable for `ssh-keyscan`, which is why this file is user-maintained.

`.sops.yaml` also reserves a `creation_rule` for `secrets/nixos-config-tester.yaml`, but the file has not been materialized on disk yet — treat it as a placeholder slot, not an active encryption target.

## secrets/ inventory

Files in `/Volumes/Codes/nix-src/nix-secrets/secrets/`: `shared.yaml`, `Annulatus.yaml`, `ChanningdeMacBook-Pro.yaml`, `Macrouridae.yaml`, `Mola.yaml`, `nixos-rl.yaml`, `Platypus.yaml`, `Poecilia.yaml`, `Pseudomugil.yaml`, `Toxotidae.yaml`.

Known secret paths (the strings passed to `sops.secrets."..."`):

- `passwords/<username>` — `mkpasswd` output for system user accounts
- `keys/age/<name>` — age decryption keys
- `keys/ssh/<name>` — SSH private keys (e.g., `backup`)
- `msmtp/password` — SMTP auth for the notifier mailbox
- `attic/token` — Attic binary cache push token
- `k3s/token` — k3s cluster join token
- `yubico/u2f_keys` — YubiKey challenge-response payload
- `ups/upsmon-password` — NUT power monitoring
- `komodo/core_public_keys` — Komodo (Docker UI) trust keys
- `samba/<server_name>` (NixOS) or `samba/<server_name>/password` (Darwin) — SMB credentials
- `znapzend/ssh_private_key` — ZFS replication SSH key

Scope decides the file: single-host secrets go in `<HostName>.yaml`; multi-host secrets go in `shared.yaml`.

## Consuming secrets in modules

The only operational part of this file — everything above is read-only orientation.

```nix
{ config, inputs, ... }:
let
  sopsFolder = "${inputs.nix-secrets}/secrets";  # each module redefines locally
  hostname   = config.hostSpec.hostName;
  user       = "channinghe";                     # placeholder — real modules thread this through hostSpec.username
in {
  sops.secrets."attic/token" = {
    sopsFile = "${sopsFolder}/shared.yaml";
    owner    = "root";
    mode     = "0400";
  };

  sops.secrets."passwords/${user}" = {
    sopsFile       = "${sopsFolder}/${hostname}.yaml";
    neededForUsers = true;   # required for users.users.<u>.hashedPasswordFile
  };

  # Reference the decrypted path at activation time:
  services.something.tokenFile = config.sops.secrets."attic/token".path;
}
```

`sopsFolder` is a local `let` binding inside `hosts/common/core/sops.nix:13` (`sopsFolder = builtins.toString inputs.nix-secrets + "/secrets";`); it is not exported. Other modules (e.g. `services/attic.nix:28`) redefine their own identical binding. Prefer that local binding over hand-writing `"${inputs.nix-secrets}/secrets"` inline in every consumer.

For rendered files that splice multiple secrets (netrc, env files, Caddyfiles), use `sops.templates` with the placeholder syntax:

```nix
sops.templates."app.env".content = ''
  TOKEN=${config.sops.placeholder."attic/token"}
'';
```

After adding a `sops.secrets` block, the user runs `just rekey` in nix-secrets, then their normal rebuild flow in nix-config (see commands.md for the spawn.sh state machine and justfile pre/post hooks).

## What agents must not do

- Do not run `sops` in any form. The age key lives only on the user's machine and YubiKeys; the agent cannot decrypt or re-encrypt.
- Do not edit `.sops.yaml`. Adding/rotating anchors requires `ssh-keyscan` against a live host plus a user-side trust decision.
- Do not write or modify any file under `secrets/`. Committing plaintext YAML there silently breaks decryption for everyone.
- Do not invent age keys or attempt to extend the encryption matrix — anchors are derived from real SSH host keys and YubiKey identities, so fabricated keys cannot decrypt anything and only pollute `.sops.yaml`.
- Do not run `just rekey` or `just sync` in the nix-secrets flake. `rekey` re-encrypts every YAML to the current anchor matrix and must be invoked by the user after they touch `.sops.yaml`; `sync` rsyncs the working tree to a host the agent has no business reaching.

When a recipe needs a new secret, do the nix-side work and hand off the rest:

1. Add the `sops.secrets."<path>"` block to the module with the correct `sopsFile`.
2. Reference `config.sops.secrets."<path>".path` (or a `sops.templates` entry) where consumed.
3. Tell the user the exact YAML key path and which file to add it to (`shared.yaml` vs `<HostName>.yaml`), then wait for confirmation before rebuilding.

