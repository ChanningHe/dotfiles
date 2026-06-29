# nix-config Architecture & Mental Model

Why each value lands where it does — flake outputs, the `lib.custom` helpers, the three-file pattern, the `hostSpec` data bus, and the inheritance chain. Use this when you need the why; for the how, the recipes are a separate document.

## Contents

- [Where do new modules go?](#where-do-new-modules-go)
- [flake.nix outputs](#flakenix-outputs)
- [lib/default.nix — two helpers + a re-export](#libdefaultnix--two-helpers--a-re-export)
- [The three-file pattern — two distinct uses](#the-three-file-pattern--two-distinct-uses)
- [Auto-discovery vs cherry-pick](#auto-discovery-vs-cherry-pick)
- [hostSpec — the data bus](#hostspec--the-data-bus)
- [Inheritance chain](#inheritance-chain)
- [Commands: justfile hooks and spawn.sh state machine](#commands-justfile-hooks-and-spawnsh-state-machine)
- [nix-secrets integration](#nix-secrets-integration)

## Where do new modules go?

The user-stated primary use case. Map intent to directory:

- Home-Manager-only option/program → `modules/home/<name>.nix`. Picked up by `home/<u>/common/core/default.nix` via `scanPaths`.
- Cross-platform system option (works on both NixOS and Darwin) → `modules/hosts/common/<name>.nix`.
- NixOS-only system option → `modules/hosts/nixos/<name>.nix`. Darwin-only → `modules/hosts/darwin/<name>.nix`.
- A reusable module shared by HM and system scopes (e.g. `host-spec.nix`) → `modules/common/`.

In every case: drop the file, `lib.custom.scanPaths` picks it up from the local `default.nix`. No registration. These directories define options (`options.foo = …`); turning a feature on is still done per-host or per-user.

## flake.nix outputs

`/Volumes/Codes/nix-src/nix-config/flake.nix` exposes nine top-level outputs: `overlays`, `nixosConfigurations`, `darwinConfigurations`, `deploy`, `packages`, `apps`, `formatter`, `checks`, `devShells`. The two host outputs are the only ones with non-trivial control flow.

A let-bound `lib = nixpkgs.lib.extend (self: super: { custom = import ./lib { inherit (nixpkgs) lib; }; })` is passed into both host families through `specialArgs`. `extend` runs before home-manager captures `lib`, which is the only mechanism that gets `lib.custom.scanPaths` and `lib.custom.relativeToRoot` into HM submodules.

**nixosConfigurations / darwinConfigurations.** Map `builtins.readDir ./hosts/{nixos,darwin}` into `nixpkgs.lib.nixosSystem` / `nix-darwin.lib.darwinSystem`. The host's directory is the sole module entry. `specialArgs = { inherit inputs outputs lib; isDarwin = false | true; }`. `specialArgs.isDarwin` is the bootstrap signal used by `hosts/common/core/default.nix` before `hostSpec` is fully evaluated; downstream module code branches on `config.hostSpec.isDarwin` once the option is set. They should agree but are not the same binding.

**overlays.default.** `import ./overlays { inherit inputs; }` layers, in order: every package under `pkgs/common/` via `packagesFromDirectoryRecursive`, hand-written `modifications`, Linux-only modifications, and an `unstable` attribute pointing at `nixpkgs-unstable`. The same directory scan happens in the `packages` output too — overlay is for internal refs like `pkgs.cd-gitroot`; `packages` is for `nix build .#packages.<system>.cd-gitroot`.

**packages.** `forAllSystems` over `x86_64-linux` and `aarch64-darwin` only — add a system tuple here before adding a host that needs it.

**deploy.** `import ./deploy.nix { inherit inputs lib; nixosConfigurations = self.nixosConfigurations; }`. Every NixOS host except the live installer (`iso`) becomes a deploy-rs node. The exclusion is a literal name check (`h != "iso"`), not opt-in via hostSpec. Hostname resolves to `inputs.nix-secrets.networkInfo.hosts.<host>.ip4` (falling back to the host attr name). `sshUser` is `nixosConfigurations.<host>.config.hostSpec.username`. One `profiles.system` activated as root with SSH agent forwarding (`-A`) so the remote sudo authenticates via `pam_ssh_agent_auth`. There is no `hostSpec.deploy` field.

**apps.deploy.** `nix run .#deploy` pinned to `inputs.deploy-rs.packages.${system}.default`. The pin guarantees CLI version matches the activation built by `deploy.nix`.

**formatter / checks / devShells.** `nixfmt` is the formatter; `checks.nix` wires pre-commit-hooks; `shell.nix` builds the dev shell whose `shellHook` runs the same checks. Adding a check in `checks.nix` automatically gates `nix flake check` and the dev shell entry.

## lib/default.nix — two helpers + a re-export

`/Volumes/Codes/nix-src/nix-config/lib/default.nix` defines `relativeToRoot`, `scanPaths`, and re-exports `bootDiskLayout` from `lib/boot-disk.nix`. Read it before guessing what `lib.custom.foo` does.

**relativeToRoot = lib.path.append ../.** Takes a **string** like `"hosts/common/core"` and returns a path resolved against the flake root. (`../.` and `..` both denote the parent of `lib/`, i.e. the flake root.) Common typo: passing a path literal — `lib.path.append` then errors expecting a relative string. Strings also keep the path as a stable identifier in store paths.

**scanPaths = path: …** Reads a directory and returns immediate children that are either subdirectories or `.nix` files **other than `default.nix`**. The `default.nix` exclusion is load-bearing: `scanPaths` is meant to be called *from* a `default.nix`; including itself would infinite-recurse. Effect: any sibling file or subdirectory next to a `default.nix` that calls `lib.custom.scanPaths ./.` is auto-imported. This is how `modules/home`, `modules/common`, and `modules/hosts/{common,nixos,darwin}` absorb new files with zero registration.

**bootDiskLayout.** Imported from `lib/boot-disk.nix` (so `grep bootDiskLayout` inside `lib/default.nix` only finds the import line). Signature: `inputs: { layout, disk ? "/dev/vda", disk2 ? "/dev/vdb" }`. `layout` is one of `ext4 | btrfs | zfs | zfs-mirror`; `disk2` is only used for `zfs-mirror`. Returns a **list of modules** to splice into a host's `imports`: the disko nixos module (`inputs.disko.nixosModules.disko`), a `_module.args` block exposing `disk` / `primaryDisk` / `secondaryDisk` to the layout file, the matching disko layout under `hosts/common/disks/`, and the matching bootloader under `hosts/common/optional/system/`. Errors are `attribute … missing` if `layout` is not one of the four supported strings. `spawn.sh` sets `layout` interactively and back-fills `disk` once it detects the target's drive.

## The three-file pattern — two distinct uses

The repo uses sibling `default.nix` / `nixos.nix` / `darwin.nix` files two ways. Confusing them is the most common modeling error.

**(a) Platform-scoped directory.** Under `modules/hosts/{common,nixos,darwin}/` the *directory itself* is the platform filter. `modules/hosts/nixos/<x>.nix` is only seen by NixOS hosts because `hosts/common/core/default.nix` only imports `modules/hosts/${platform}`. The `default.nix` in each of these dirs is identical (`imports = lib.custom.scanPaths ./.;`) — that is the entire scoping mechanism.

**(b) Coexisting siblings, internal pick.** Under `home/<u>/common/core/`, all three of `default.nix`, `nixos.nix`, `darwin.nix` sit side by side. The `default.nix` contains a `./${platform}.nix` line where `platform = if hostSpec.isDarwin then "darwin" else "nixos"` (see `/Volumes/Codes/nix-src/nix-config/home/channinghe/common/core/default.nix:9,18`). Renaming the sibling breaks evaluation only on the affected platform.

**(b′) External platform selection.** Under `hosts/common/users/<u>/`, the user's own `default.nix` is platform-agnostic. The platform sibling is imported alongside it by `hosts/common/core/default.nix:33-34`, which lists `hosts/common/users/channinghe` AND `hosts/common/users/channinghe/${platform}.nix` as separate `relativeToRoot` entries. The user file does not interpolate `${platform}` itself.

Rule: if the directory name is `nixos/` or `darwin/`, it's (a). If a `default.nix` next to the file contains `./${platform}.nix`, it's (b). If the platform sibling is selected by an outer file, it's (b′).

## Auto-discovery vs cherry-pick

**Auto-discovered.** Hosts (`builtins.readDir ./hosts/{nixos,darwin}`). Packages (`packagesFromDirectoryRecursive ./pkgs/common`). Reusable modules under `modules/common`, `modules/home`, `modules/hosts/{common,nixos,darwin}` (via `scanPaths`).

**Cherry-picked.** `hosts/common/optional/**` is not auto-imported — each host's `default.nix` enumerates the optionals it wants via `map lib.custom.relativeToRoot [ … ]`. The host file is the audit point: one open file tells you everything that machine runs. User home programs in `home/<u>/common/core/default.nix` are listed by hand for the same reason — the user can see their dotfile surface at a glance.

Rule of thumb: auto-load when a `default.nix` calls `scanPaths`; cherry-pick when it lists imports by hand. Directory names like `common` or `core` are hints, not guarantees — `home/<u>/common/core` is cherry-picked.

## hostSpec — the data bus

Declared in `/Volumes/Codes/nix-src/nix-config/modules/common/host-spec.nix` as a single submodule option with `freeformType = attrsOf str` (escape hatch for one-off string fields) plus typed fields below. Populated in `hosts/common/core/default.nix` (primary username/handle plus `inherit (inputs.nix-secrets) domain email userFullName networking networkInfo serviceInfo`) and per-host in each `hosts/{nixos,darwin}/<host>/default.nix` with `hostName` and host-specific overrides (e.g. `scaling`, `loadUserAgeKey`, `isServer`). Networking IPs come from `hostSpec.networkInfo.hosts.<hostName>`, not a per-host override.

Modules read `config.hostSpec.<field>` — never `inputs.nix-secrets` directly. Because the same option is declared into both NixOS, Darwin, and HM scopes, hostSpec is the only platform-agnostic data bus in the repo.

**Identity / data:** `username`, `hostName`, `userFullName`, `handle`, `email` (attrs), `domain`, `home` (auto-derived: `/home/<u>` on Linux, `/Users/<u>` on Darwin), `persistFolder` (default `""`).

**Network data:** `networking`, `networkInfo`, `serviceInfo`, `wifi` (bool, default false).

**Role / capability flags (all bool):** `isMinimal`, `isMobile`, `isProduction` (default **true**), `isServer`, `isWork`, `isDarwin`, `useYubikey`, `voiceCoding`, `isAutoStyled`, `useNeovimTerminal`, `useWindowManager` (default **true**), `useAtticCache` (default **true**), `hdr`, `loadUserAgeKey`.

**Display:** `scaling` (str, default `"1"` — a floating-point number as a string for downstream interpolation).

**Nested attrs:** `work` (required when `isWork = true`).

**Assertions enforced in the module:** `isWork → work` is non-empty; `system.impermanence.enable → persistFolder` is non-empty (guarded with `config ? "system"` so HM evaluation does not fail).

Note: `hostSpec.isDarwin` is a separately declared option set per host/platform; the `isDarwin` specialArg comes from flake.nix. They should agree but are not the same binding.

## Inheritance chain

Tracing a NixOS host from flake entry to a home-manager program. Three tiers: **system** (flake → host dir), **host-common** (`hosts/common/core` plus optionals), **user-home** (HM submodule entered via the user file):

```
[ tier: system ]
flake.nix
  └─ lib.nixosSystem { specialArgs = { inputs outputs lib; isDarwin = false; }; }
        modules = [ ./hosts/nixos/<host> ]
            │
            ▼
       hosts/nixos/<host>/default.nix
            ├─ ./hardware-configuration.nix         (or facter.json, or disko)
            ├─ "hosts/common/core"
            │
[ tier: host-common ]
            │     └─ hosts/common/core/default.nix
            │           ├─ modules/common           (scanPaths → host-spec option)
            │           ├─ modules/hosts/common     (scanPaths, both platforms)
            │           ├─ modules/hosts/nixos      (scanPaths, NixOS only — platform-scoped dir)
            │           ├─ hosts/common/core/nixos.nix         (sibling pick by outer file)
            │           ├─ hosts/common/core/services
            │           ├─ hosts/common/core/sops.nix, ssh.nix
            │           ├─ hosts/common/core/openssh-server.nix (NixOS-only branch)
            │           ├─ hosts/common/users/channinghe
            │           ├─ hosts/common/users/channinghe/${platform}.nix  (external select)
            │           │     └─ home-manager.users.<u>.imports
            │           │           └─ home/<u>/<host>.nix
            │           │
[ tier: user-home ]
            │           │                 └─ home/<u>/common/core/default.nix
            │           │                       ├─ modules/common/host-spec.nix
            │           │                       ├─ modules/home          (scanPaths)
            │           │                       ├─ ./nixos.nix           (sibling pick, internal)
            │           │                       └─ ./bash.nix ./zsh.nix … (cherry-pick)
            └─ "hosts/common/optional/<x>.nix" …    (host-picked)
```

`specialArgs` is how flake-level bindings (`inputs`, `outputs`, `lib`, `isDarwin`) reach top-level modules; **`extraSpecialArgs`** is the parallel mechanism for home-manager submodules. The user file (`hosts/common/users/channinghe/default.nix:44-47`) sets `home-manager.extraSpecialArgs = { inherit pkgs inputs; hostSpec = config.hostSpec; }`. Without `extraSpecialArgs`, the HM scope would not see `hostSpec` as a function argument (the option is also re-declared via `modules/common/host-spec.nix` import, so both paths work but mean different things — argument vs option).

## Commands: justfile hooks and spawn.sh state machine

**justfile pre/post hooks.** `rebuild`, `build`, `rebuild-full`, and `rebuild-trace` all wrap with `rebuild-pre && rebuild-post`:

- `rebuild-pre: update-nix-secrets` then `git add --intent-to-add .` — the `--intent-to-add` is what makes untracked files visible to `nix flake eval` (flake source tracking ignores untracked files entirely; intent-to-add lifts them into the index without staging contents).
- `rebuild-post: check-sops` — runs `scripts/check-sops.sh` to verify `sops-nix` activation succeeded, so a silent decryption failure does not pretend to be a successful switch.

`update-nix-secrets` does `git fetch && git rebase` inside `../nix-secrets` (best-effort, ignored on failure) and then `nix flake update nix-secrets --timeout 5`.

**spawn.sh state machine.** Four steps in order: `scaffold | secrets | disk | install`. Each is gated by a detection flag, so re-running after a failure resumes from the right point:

- `REPO_SCAFFOLDED` — `hosts/nixos/<host>/default.nix` exists.
- `REPO_SECRETS` — `sops` can decrypt `ssh_host_ed25519_key` from `../nix-secrets/secrets/<host>.yaml`.
- `REPO_FACTER` — `hosts/nixos/<host>/facter.json` exists.
- `REPO_DISK_SET` — regex-anchored `^[[:space:]]*disk[[:space:]]*=[[:space:]]*"/dev/` match in the host's `default.nix` (anchored so it ignores comments).

`TARGET_STATE` is detected over SSH: `UNREACHABLE | NON_NIXOS | INSTALLER | INSTALLED_THIS | INSTALLED_OTHER`. The PLAN takes `want[step] = (not detected)`, then applies `--only <step>` (overrides all), `--from <step>` (enables that step to the end), and `--skip <step>` (forces 0). `install` uses the **full flake config** (no separate deploy step); the rebooted system is final. To update an already-spawned host, use `just deploy <host>` — that goes through deploy-rs with auto-rollback.

## nix-secrets integration

`nix-secrets` is a separate flake pinned in `inputs`:

```
nix-secrets.url = "git+ssh://git@github.com/<owner>/nix-secrets.git?ref=master&shallow=1";
```

Top-level attributes (`domain`, `email`, `userFullName`, `networking`, `networkInfo`, `serviceInfo`) flow into `hostSpec` via the `inherit (inputs.nix-secrets) …` line in `hosts/common/core/default.nix:54-61`. Modules then read `config.hostSpec.<field>`. Tracing one value: `domain` is defined in `../nix-secrets/default.nix` → inherited into `hostSpec.domain` in `hosts/common/core/default.nix` → consumed as `config.hostSpec.domain` inside service modules. Encrypted material (SOPS yaml files, age keys) lives in the secrets repo and is decrypted at activation time by `sops-nix`.

Failure modes worth knowing: if the `nix-secrets` input is unavailable (network down, SSH auth broken), the flake evaluates only as far as the `inherit` line and then errors with `attribute 'domain' missing` (or whichever field is named first). The fix is always to make the input resolve — never to comment out the `inherit` line, which would silently zero out every consumer.

### What NOT to do (agent rules)

The secrets repo is strictly user-operated (see also the user memory rule `feedback_no_git_commands`). Agents must:

- Do NOT `cd ../nix-secrets` or edit any file there.
- Do NOT run `sops -e | -d | -r` or `sops updatekeys`.
- Do NOT run the just recipes `sops-rekey`, `rekey`, `sops-update-age-key`, `sops-update-user-age-key`, `sops-update-host-age-key`, `sops-add-host-creation-rules`, `sops-add-shared-creation-rules`, or `sops-add-creation-rules` — these mutate secret material.
- Do NOT commit or push in `../nix-secrets`.
- Do NOT read decrypted values from `/run/secrets/*`.
- Do NOT introduce direct `inputs.nix-secrets.<x>` references in modules — always go through `config.hostSpec`.

What agents may do: describe the shape of a yaml file, name the file path the user should open, point at the exact `inherit (inputs.nix-secrets) …` line, and tell the user which `just` recipe to run themselves. Treat the secrets repo as read-only documentation.

