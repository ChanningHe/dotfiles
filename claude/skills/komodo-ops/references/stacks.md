# Stacks

## Create a stack

1. Pick the host. Read its `[[server]]` block and two or three sibling `[[stack]]` blocks in `komodo/resources/src-<host>.toml`; reuse their exact `server`, tag, and `run_directory` prefix.
2. Write `stacks/<host-dir>/<stack>/compose.yaml`. Start from the upstream project's compose, then adapt:
   - image pinned to a version tag (Renovate will add the digest);
   - every private value as `${VAR}` (see `secrets.md` for adding new ones);
   - persistent state under `${DOCKER_DATA}/<stack>/...`; bulk/media paths from the existing path variables on that host;
   - ingress per the patterns below.
3. Append a block to the host's TOML, separated by `##` like its neighbours:

```toml
##

[[stack]]
name = "<stack>"
tags = ["<HostTag>"]
[stack.config]
server = "<server-name>"
poll_for_updates = true
linked_repo = "komodo-ops"
run_directory = "stacks/<host-dir>/<stack>"
compose_cmd_wrapper = "sops exec-env [[SECRET_ENV_PATH]] '[[COMPOSE_COMMAND]]'"
compose_cmd_wrapper_include = ["pull", "config", "up"]
```

4. Tell the user which secret keys to add (if any), then commit. The host's `resource_sync` picks up the TOML change; whether it executes automatically or needs a manual "execute sync" in Komodo is a Komodo-side setting — say so rather than assume.

Stack name must be unique across all hosts (Komodo names are global). Existing practice when the same app runs on two hosts: suffix the name, keep the directory name.

## Wrapper and env semantics

- `compose_cmd_wrapper_include` defaults to `["up"]` only. Without `pull` and `config`, image pulls and Komodo's config view run with no secrets and see empty variables. Use `["pull", "config", "up"]`.
- A stack with no `${VAR}` from secrets may omit the wrapper; it still inherits the periphery env (`DOCKER_DATA`, `HOSTNAME`).
- Interpolation sources for `${VAR}` in `compose.yaml`: process env (sops exec-env + periphery env), then `.env` in the run directory, then `additional_env_files`.
- `.env` in the run directory: compose reads it for interpolation. Komodo **overwrites** it (`env_file_path`, default `.env`) whenever the stack's `environment` field in TOML is non-empty.
- `additional_env_files = [{ path = "compose.env", track = true }]` → passed as `--env-file`. Useful to map prefixed secret names to the names an image expects (`POSTGRES_PASSWORD=${APP_POSTGRES_PASSWORD}`).
- `env_file:` inside a service sets container env, not compose interpolation.
- Komodo `[[VAR]]` syntax is interpolated only in Komodo fields (`environment`, wrapper, pre/post deploy commands), never in files from the repo. A `[[...]]` inside a committed `.env` is a literal string.

## Other stack fields seen in this repo

- `ignore_services = ["<init-svc>"]` — one-shot/migration containers that exit, so the stack still reports healthy.
- `destroy_before_deploy = true` — `compose down` before `up`; for stacks that cannot be recreated in place.
- `template = true` — reusable definition, never batch-deployed.
- `auto_update = true` (+ `auto_update_all_services`) — redeploy on new image; implies polling. Most stacks rely on Renovate PRs instead.
- `pre_deploy` / `post_deploy` — shell hooks; avoid unless there is no compose-native way.

## Tags

- Host tag is mandatory: each host's `resource_sync` in `main.toml` uses it as `match_tags`.
- Extra tags carry behavior. Read `main.toml` for current meaning; at time of writing `critical-infra` and `template` are excluded from the post-Renovate-merge batch redeploy (they need a manual deploy), while others (`public-svc`, `admin_monitor`) are grouping labels.

## Ingress patterns

Copy from a working sibling stack on the same host rather than writing labels from scratch. Discover the networks in use with `grep -rhoE 'traefik[-_a-z]*_web' stacks | sort | uniq -c`.

- **Internal (LAN-only)** — join the host's external `*_local_web` network, set `traefik.enable`, a `Host()` rule built from the internal-domain variable, `loadbalancer.server.port`, and `traefik.docker.network`. Bind any published port to `127.0.0.1` if traefik is the only consumer.
- **Public** — join the external `*_public_web` network on the host that runs the public traefik, add the public marker label and the public entrypoint, plus the tunnel labels (`labelgate.tunnel.*`) that publish the hostname. Public hostnames use the public-domain variable, never the internal one. Consider an auth middleware already used by sibling public stacks.
- **Cross-host** — a host without its own traefik runs a `traefik-kop` stack that pushes container labels to a central traefik through redis; the service publishes its port on the host IP and keeps normal `traefik.*` labels. Check the host's kop stack for its namespace and bind IP.

External networks must already exist on the host (created by the traefik stack). If not, `compose up` fails with "network … declared as external, but could not be found" — usually the wrong host's network name, or the traefik stack is down. A container on the right network but missing `traefik.docker.network` can still get a 502 when it has several networks.

## Modify / move / remove

- **Modify**: edit compose and/or TOML. Renovate owns image versions after the initial pin; do not fight its PRs.
- **Move to another host**: move the directory, move the TOML block to the other host file, update `server`, `tags`, `run_directory`. Verify every `${VAR}` exists in the target host's env keys. Data under `DOCKER_DATA` does not move by itself — tell the user. Ask the user to destroy the stack on the old host first; deleting a resource from a sync does not guarantee containers stop.
- **Remove**: same caveat — destroy in Komodo, then delete the directory and TOML block, then mention any secret keys that are now unused.

## Builds

`src-builder.toml` defines `[[build]]` resources with contexts under `build/`. Builds push to a registry account and pin `version`; bump `version` deliberately rather than enabling `auto_increment_version`.
