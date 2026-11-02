---
name: komodo-ops
description: Operates the user's Komodo GitOps setup — a public `komodo-ops` repo (Komodo resource TOML + per-host docker compose stacks) paired with a private `komodo-secrets` repo (sops/age-encrypted dotenv per host). Use when creating, modifying, moving, or removing a stack; editing `komodo/resources/*.toml` (stack, server, repo, procedure, action, resource_sync); wiring a new secret or env var into a compose file; exposing a service through traefik; adding a host; or debugging a failed deploy, empty variable, sops decrypt error, or Renovate image update in these repos — even when the user just says "add a stack", "deploy X on <host>", or "why is X down".
---

# komodo-ops

Two sibling git repos, normally checked out side by side:

- `komodo-ops/` — **public** (mirrored to GitHub). Komodo resource definitions and compose files. Contains only `${VAR}` references, never values.
- `komodo-secrets/` — **private**. `envs/<Host>.env` encrypted with sops (age). Keys are plaintext, values are `ENC[...]`.

Everything written to `komodo-ops` ends up public. Treat that as the primary constraint on every edit.

## Mental model

```
komodo/resources/main.toml          self-syncing ResourceSync + one resource_sync per host file,
                                    procedures/actions, global variable SECRET_ENV_PATH
komodo/resources/src-<host>.toml    [[server]], [[stack]]s, and [[repo]] komodo-secrets-<Host> for that host
stacks/<host>/<stack>/compose.yaml  run_directory of the stack
build/<name>/                       Komodo [[build]] contexts (src-builder.toml)
```

Deploy path for a stack:

1. Komodo `PullSecrets` procedure clones `komodo-secrets` onto every host that has a `komodo-secrets-<Host>` repo resource.
2. The stack runs compose through `compose_cmd_wrapper = "sops exec-env [[SECRET_ENV_PATH]] '[[COMPOSE_COMMAND]]'"`. `SECRET_ENV_PATH` resolves to `envs/${HOSTNAME}.env` inside the cloned secrets repo, so the periphery's `HOSTNAME` must equal the env file name.
3. sops decrypts with the age key the periphery process has (`SOPS_AGE_KEY_FILE`, provisioned outside these repos — NixOS hosts via the nix-config repo, others via the custom periphery image in `build/`).
4. Host-level vars such as `DOCKER_DATA` come from the periphery process environment, not from either repo.

One host can appear under different casing in the `stacks/` directory, the Komodo server name, the resource tag, and the secrets env file. Always read the host's `[[server]]` block and an existing `[[stack]]` in its `src-*.toml` instead of guessing.

## Hard rules

1. **No literal private values in `komodo-ops`.** Domains, IPs, tokens, passwords, host paths, user/chat IDs, emails → put them in `komodo-secrets` and reference as `${VAR}`. If a value is needed and no variable exists, name the variable and tell the user which env file to add it to.
2. **Never put decrypted secrets into the conversation.** To learn which variables exist, read key names straight from the encrypted file (no decryption needed): `grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' ../komodo-secrets/envs/<Host>.env`. Do not run `sops -d`, `sops exec-env … env`, or `docker compose config` under sops without `--quiet` — they print plaintext.
3. **Secret values are user-operated.** The agent edits compose/TOML and states exactly which key goes in which `envs/*.env`. The user runs `sops` to add values, edits `.sops.yaml`, and runs the shared-env sync. Never generate or rotate age keys.
4. **Pin images.** New services use a real version tag (Renovate adds `@sha256` digests); never `latest` or another floating tag.
5. **Before committing in `komodo-ops`**, the pre-commit hook (`.githooks/`) must pass, and for exported or generated config (dashboards, large YAML) also run `./check-leaks.sh <dir>`. Never bypass with `--no-verify`.
6. **Acting on live hosts or Komodo** (ssh, `docker` on a host, triggering deploys/procedures) needs the user's go-ahead; default scope is editing files and validating locally.

## Where to look

| Need | Look at |
|---|---|
| Hosts and their exact names | `grep -A6 '^\[\[server' komodo/resources/src-*.toml`, `ls stacks/` |
| How a host's stacks are configured | that host's `src-*.toml`; copy the shape of a sibling stack |
| Which ingress a host uses | existing stacks on that host: their `networks:` and `traefik.*` / tunnel labels |
| Variables available on a host | key names in `../komodo-secrets/envs/<Host>.env` (rule 2) |
| Shared vs host-only variables | `../komodo-secrets/envs/shared.env` keys are synced into each host file between `# @sops-sync` markers |
| Tag semantics, auto-deploy behavior | `main.toml` procedures/actions (`updateOnPrMerge`, `batch-deploy-changed-and-exclude`) |
| Komodo field semantics | upstream `client/core/rs/src/entities/stack.rs` in moghtech/komodo |

## References

Read on demand; each is self-contained.

- `references/stacks.md` — create / modify / move / remove a stack, the TOML block, wrapper and env-file semantics, ingress patterns, tags. Read before any stack change.
- `references/secrets.md` — sops/age layout, `.sops.yaml` rules, shared-env sync, adding a variable or a host, what to hand to the user.
- `references/debugging.md` — where to look when a deploy fails or a service misbehaves, local validation commands, known failure modes.
