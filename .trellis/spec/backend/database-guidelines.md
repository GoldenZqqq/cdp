# JSON Persistence and State Ownership

cdp has no database. Its durable boundary is a small set of JSON documents plus
one active-config pointer. Treat these files with database-level consistency.

## Owned Documents

| Document | Default location | Owner |
|----------|------------------|-------|
| Project config | discovered `projects.json` | projects, metadata, repair, scan, status fix |
| Active choice | `~/.cdp/config` | explicit config selection |
| Recent state | `~/.cdp/state.json` or `CDP_STATE_PATH` | successful project switches |
| Workspaces | `workspaces.json` beside active project config | workspace add/list/open |
| Hook trust | `~/.cdp/hook-trust.json` or `CDP_HOOK_TRUST_PATH` | hook list/trust/revoke |

Project Manager-compatible `projects.json` remains an array. cdp-only state must
not be mixed into that array.

## Atomic Write Contract

PowerShell uses `Read-CdpJsonDocument` and `Write-CdpJsonFile`; shell uses
`cdp_json_fingerprint`, `cdp_write_json_text`, and `cdp_commit_json_file`.

Every mutation must:

1. Parse the active document and retain its SHA-256 fingerprint.
2. Acquire the sibling `.cdp.lock` without deleting a foreign lock.
3. Recheck the fingerprint while locked.
4. Validate a sibling temporary JSON file, flush it, and replace in place.
5. Retain the three newest `.cdp-backup.*` files.
6. Remove only temporary/lock artifacts owned by the current writer.

Missing targets initialize only with expected fingerprint `missing`. Invalid
active state is read-only until explicitly restored; never silently reset it.

## Schema Boundaries

- Project entries require string `name`, string `rootPath`, and boolean
  `enabled`; `paths`, `pinned`, `aliases`, `tags`, and `onEnter` are optional.
  `paths` is an object whose known `windows`, `wsl`, `linux`, and `macos`
  values, when declared, are non-empty strings. `rootPath` remains the raw
  identity and old-client fallback. Preserve unknown project fields and unknown
  future profile keys through every mutation.
- Recent state is an object with `recentProjects`; it is not a project array.
- Workspace entries contain a name, project-name list, and optional launcher.
- Hook trust version 1 stores only fingerprints and `trustedAt`, never commands,
  config contents, paths, or environment values.

Normalize data at the read boundary. Do not let every command invent defaults
or write raw parsed objects independently.

## Failure and Recovery

- Stale fingerprint or existing lock -> fail without modifying original bytes.
- Invalid candidate -> fail before replace.
- Invalid active JSON -> report available valid backups and refuse mutation.
- Permission, flush, backup, or rename failure -> nonzero/exception and preserve
  the active document.

Regression coverage: `tests/cdp.Persistence.Tests.ps1`,
`tests/cdp.Persistence.Tests.sh`, and safe mutation suites.
