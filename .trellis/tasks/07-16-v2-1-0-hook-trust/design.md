# Hook Trust Design

## Boundary

`onEnter.env` remains a data-only operation and is applied after environment-key
validation unless the caller specifies `--no-hook`. Command hooks remain denied
by default and may run only through one-switch authorization (`-AllowHook` /
`--allow-hook`) or a matching persistent trust entry.

## Trust Identity

The trust store is `~/.cdp/hook-trust.json` by default and may be redirected by
`CDP_HOOK_TRUST_PATH` for tests and automation. It stores schema version 1 and
entries containing only:

- SHA-256 of the normalized absolute config path;
- SHA-256 of the project name plus raw root path;
- SHA-256 of the current config contents, normalized command hook kind, and
  exact command text;
- an ISO UTC trust timestamp.

It never stores command text, environment values, or config contents. A config
move, any config content change, project identity change, or command change
therefore invalidates trust.

## Commands

```text
cdp hook list [--config <projects.json>]
cdp hook trust <project> [--config <projects.json>]
cdp hook revoke <project> [--config <projects.json>]
cdp hook revoke --all [--config <projects.json>]
```

`list` renders project name, hook kind, and `trusted` / `untrusted`; it never
renders the command. `trust` requires exactly one enabled project match with a
non-empty command hook. `revoke` removes all fingerprints for the selected
project identity in that config, so stale entries can be removed after a
command change. `--all` removes only entries belonging to the selected config.

## Switch Precedence

1. `--no-hook` skips environment values and commands.
2. `-AllowHook` / `--allow-hook` authorizes the command once without persisting.
3. A current trust fingerprint authorizes the command persistently.
4. Otherwise the command is skipped with a redacted next-step hint.

`--allow-hook` and `--no-hook` together are a parser error.

## Storage Safety

The trust store uses the atomic JSON persistence boundary. Shell applies mode
`0600`; PowerShell removes inherited ACLs and grants the current user full
control on Windows, while applying Unix mode `0600` when the runtime exposes
`SetUnixFileMode`. Permission hardening failures reject trust mutations rather
than silently leaving a broadly readable trust store.

## Compatibility

- Windows PowerShell 5.1 and PowerShell 7 share the parser and trust contract.
- bash 3.2 and zsh share the same JSON schema and SHA-256 inputs.
- Existing `-AllowHook` / `--allow-hook` scripts retain one-switch behavior.
- The trust store is portable only when config paths normalize identically;
  moving between Windows and WSL intentionally requires separate trust.

## Failure Semantics

Invalid trust JSON is read-only and diagnosed; it is never silently reset.
Ambiguous projects, missing hooks, invalid environment keys, stale trust,
permission failures, and hook runtime errors expose no command contents.
Hook runtime failures remain isolated from a successful directory switch.
