# Security

- Never hardcode or commit secrets; use env vars or sops. If a secret may have leaked, stop and tell the user to rotate it.
- Validate and bound untrusted input at boundaries; parameterize queries; escape output for its context.
- Least privilege for credentials, tokens, file and network access.
- Errors and logs must not leak secrets or personal data.
- Changes on the escalation list (see workflow) get a `reviewer` pass with model `opus` before merge.
