# Debugging

Combine sources; the first symptom is often far from the cause. Start cheap and local, move to the host only with the user's go-ahead.

## Where to look

1. **Komodo UI** (ask the user to paste, or to grant access): the stack's latest deploy/update log shows the exact wrapped compose command and its stderr; the resource sync's pending diff shows what Git would change; the procedure log shows whether `PullSecrets` ran.
2. **The repo, statically** — compose + TOML block + key names in the host env. Most failures are visible here.
3. **The host** (go-ahead required) — periphery keeps repos under its root directory (default `/var/lib/komodo-periphery/repos/`); the compose project name is the stack name, so `docker compose -p <stack> ps` / `logs` work from anywhere on the host. On NixOS hosts the periphery is a systemd service (`journalctl -u komodo-periphery`).

## Local checks (safe, no plaintext)

Variables referenced vs. variables available:

```bash
d=stacks/<host-dir>/<stack>
# refs without a ${VAR:-default} or $$ escape, minus keys from the host env and the stack's
# own env files; what is left is missing or comes from the periphery env (DOCKER_DATA, HOSTNAME)
comm -23 \
  <(cat "$d"/compose.yaml "$d"/*.env "$d"/.env 2>/dev/null | sed 's/\$\$//g' \
    | grep -oE '\$\{[A-Za-z_][A-Za-z0-9_]*\}|\$[A-Za-z_][A-Za-z0-9_]*' | tr -d '${}' | sort -u) \
  <(grep -ohE '^ *[A-Za-z_][A-Za-z0-9_]* *=' ../komodo-secrets/envs/<Host>.env "$d"/*.env "$d"/.env 2>/dev/null | tr -d '= ' | sort -u)
```

Compose validity with real interpolation, printing nothing but errors (the repo `justfile` wraps `sops exec-env` + `docker compose config --quiet`, adding the stack's `.env`/`compose.env`):

```bash
SECRET_ENV_PATH=../komodo-secrets/envs/<Host>.env DOCKER_DATA=/nonexistent \
  just check stacks/<host-dir>/<stack>
```

On the host itself the env file defaults to `$HOSTNAME`; `just up|down|pull|logs|ps <stack-dir>` run the stack outside Komodo (go-ahead required). They refuse to run when the stack uses `DOCKER_DATA` and the shell lacks it. Compose project name is the directory name — matches Komodo only when the stack name equals its directory.

Syntax only: `docker compose -f … config --quiet --no-interpolate`. TOML: any TOML parser (`python3 -c 'import tomllib,sys; tomllib.load(open(sys.argv[1],"rb"))' <file>`).

## Known failure modes

- **Variable empty / "variable is not set"** — key missing from that host's env; secrets pushed but `PullSecrets` not run; stack has no wrapper, or `compose_cmd_wrapper_include` lacks `pull`/`config`; key was added inside the `@sops-sync` region and wiped by the next sync; `[[VAR]]` used in a repo file (never interpolated).
- **sops cannot decrypt** ("no identity matched", "failed to get the data key") — the host's age key is not a recipient of that file (rule added but `sops updatekeys` not run), or the periphery process lacks `SOPS_AGE_KEY_FILE`.
- **Env file not found** — periphery `HOSTNAME` differs from the env file name (casing counts), or the host has no `komodo-secrets-<Host>` repo resource so the secrets repo was never cloned there.
- **External network not found / 502 from traefik** — see "Ingress patterns" in `stacks.md`.
- **Stack reports unhealthy while the app works** — a one-shot init/migration container exited; add it to `ignore_services`.
- **Renovate PR merged, nothing redeployed** — the post-merge procedure runs a batch action that skips some tags/states and only redeploys stacks whose files changed; read the action source in `main.toml` (it has had filter bugs) and the procedure log.
- **Resource sync wants to delete a stack** — the block lost its host tag, moved to another host file without updating `match_tags`, or was renamed (rename = delete + create; destroy first).
- **Works via CLI on the host, fails in Komodo** — the CLI run had the operator's shell env (age key, `DOCKER_DATA`) that the periphery process does not; compare against the periphery's environment, not the login shell.

## Reporting back

Say what was checked, what is confirmed vs. suspected, and which step needs the user (secret value, `sops` edit, Komodo action, host access). Never include a decrypted value or a private address in the report.
