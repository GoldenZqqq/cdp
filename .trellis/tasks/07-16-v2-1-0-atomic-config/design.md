# Atomic JSON Persistence Design

## Boundary

PowerShell and shell each expose one persistence boundary for `projects.json`,
`state.json`, and `workspaces.json`. Callers read a document with a content
fingerprint, transform the parsed value, and write with the original
fingerprint as an optimistic concurrency precondition.

## Write Protocol

1. Acquire a sibling lock (`<file>.cdp.lock`) without waiting.
2. Recompute the current SHA-256 fingerprint and reject a mismatch.
3. Serialize and validate JSON in a sibling temporary file.
4. Flush the temporary file before replacement.
5. Preserve the old file as a timestamped sibling backup.
6. Atomically replace or rename the temporary file.
7. Keep the three newest backups and invalidate the PowerShell config cache.
8. Release the lock and remove temporary artifacts on every failure path.

Missing files use the sentinel fingerprint `missing`. A caller that did not
read the file may omit the precondition only for initialization and explicit
recovery.

## Recovery

Recovery enumerates newest backups, validates JSON, and restores only an
explicitly selected valid backup through the same persistence boundary. Doctor
output reports when an invalid active document has a usable backup.

## Compatibility

- PowerShell uses .NET APIs available in Windows PowerShell 5.1.
- shell uses `mkdir` as the cross-platform lock primitive and `mv` within one
  directory as the atomic replacement primitive.
- bash 3.2 and zsh syntax remain supported.
- Existing JSON schemas and public commands do not change.

## Failure Semantics

Invalid output, lock contention, fingerprint conflict, permission failure, or
replacement failure returns an error and leaves the original file unchanged.
No caller may silently retry a conflict with a fresh fingerprint.
