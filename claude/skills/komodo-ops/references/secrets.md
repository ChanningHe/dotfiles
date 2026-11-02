# Secrets (komodo-secrets)

The agent reads structure and key names here; the user handles values and keys.

## Layout

```
.sops.yaml                  age recipients (anchors) + one creation_rule per env file
envs/<Host>.env             sops dotenv for one host; file name == periphery HOSTNAME
envs/shared.env             cross-host variables, copied into each host file
envs/test.env               scratch, owner keys only
tools/sync-shared-env.sh    shared.env → host files (`just sync`)
```

Each host file is encrypted to: the owner's keys, the host's own age key (derived from its ssh host key), and the host's periphery age key. Read `.sops.yaml` for the current recipients; never copy recipients into `komodo-ops`.

Shared variables live in each host file between `# @sops-sync begin=shared.env` / `# @sops-sync end=shared.env`. The sync script rewrites that region wholesale — anything added inside it by hand is lost on the next sync. The script's `DEFAULT_TARGETS` lists which host files receive it.

## Reading without decrypting

dotenv keys are plaintext in the encrypted file:

```bash
grep -oE '^[A-Za-z_][A-Za-z0-9_]*=' ../komodo-secrets/envs/<Host>.env | tr -d '='
```

To check that a variable is set and non-empty without exposing it (needs a local age key that can decrypt that file):

```bash
sops exec-env ../komodo-secrets/envs/<Host>.env 'test -n "$KEY" && echo set || echo EMPTY'
```

Never `sops -d` to stdout, never write a decrypted copy to disk, never echo a value.

## Naming

- App-specific secrets: prefix with the app/stack, e.g. `<APP>_DB_PASSWORD`, `<APP>_SECRET_KEY`. Map to the image's expected names in compose or in a tracked `compose.env`.
- Addresses, domains, local subnets: use the existing prefix families (`IP_*`, `DOMAIN_*`, `LOCAL_V*`). `check-leaks.sh` decrypts exactly those prefixes and greps the public repo for their values, so a domain stored under another name escapes the leak check.
- Host paths: the existing `PATH_*` family.
- Look at the existing keys on the host before inventing a new one; a suitable one often exists.

## Adding a variable (hand-off to the user)

State, precisely:

1. Which file: `envs/<Host>.env` if only one host needs it; `envs/shared.env` if several do.
2. The key name(s) and what the value is (e.g. "random 32-byte base64", "API token from <service>"). Suggest a generator command if it is a random secret, but do not run it.
3. The commands for the user:
   - host-only: `sops envs/<Host>.env`, add `KEY=value` **outside** any sync markers;
   - shared: `sops envs/shared.env`, then `just sync` to propagate.
4. Commit and push `komodo-secrets`, then run the Komodo `PullSecrets` procedure so hosts get the new file **before** deploying the stack that needs it. A stack deployed first sees an empty variable.

## Adding a host

Split across three repos; give the user the checklist and do only the `komodo-ops` part:

- **Secrets (user)** — get the host's ssh-derived age key and the periphery age key; add both as anchors and a `creation_rule` for `envs/<Host>.env`; add both to the `shared.env` rule and run `sops updatekeys envs/shared.env`; create `envs/<Host>.env`, add the shared marker (`tools/sync-shared-env.sh --add-marker -s envs/shared.env -t envs/<Host>.env`), add it to `DEFAULT_TARGETS`, then `just sync`.
- **Periphery (user / nix-config)** — periphery runs with `HOSTNAME=<Host>` (matching the env file), `SOPS_AGE_KEY_FILE`, and `DOCKER_DATA`. On NixOS this is the nix-config repo's komodo-periphery service; elsewhere the custom periphery image under `build/`.
- **komodo-ops (agent)** — new `komodo/resources/src-<host>.toml` with `[[server]]` and `[[repo]] komodo-secrets-<Host>` (copy an existing host's repo block, change `name`, `server`, tag); a matching `[[resource_sync]]` in `main.toml` with `match_tags = ["<HostTag>"]`; `stacks/<host-dir>/`. Ask the user for the server `address`; never invent or guess addresses.
