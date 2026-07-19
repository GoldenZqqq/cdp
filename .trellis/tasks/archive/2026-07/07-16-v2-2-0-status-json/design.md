# Status JSON Design

## Command Surface

The classic table remains the default. Read-only status accepts two new flags:

```text
cdp status [--dirty] [@tag] [--jobs N] [--refresh] [--json|--no-color]
Get-ProjectStatus [-DirtyOnly] [-Tag tag] [-ThrottleLimit N] [-Refresh]
                  [-Json|-NoColor]
```

`--json` and `--no-color` are mutually exclusive because JSON never contains
ANSI styling. Both are incompatible with `--fix` and `--push`; mutation commands
retain the established action-result contract rather than mixing it with a
read-only status schema.

## Schema Version 1

JSON output is one document on stdout:

```json
{
  "schemaVersion": 1,
  "generatedAt": "2026-07-19T00:00:00Z",
  "durationMs": 120,
  "filters": {
    "dirtyOnly": false,
    "tag": null,
    "refresh": false
  },
  "summary": {
    "total": 2,
    "shown": 2,
    "attention": 1,
    "partialFailures": 0,
    "exitCode": 1
  },
  "projects": []
}
```

Each project contains:

```json
{
  "name": "api",
  "rawPath": "C:\\Work\\api",
  "resolvedPath": "/mnt/c/Work/api",
  "pathExists": true,
  "status": "changed",
  "needsAttention": true,
  "attentionReasons": ["dirty", "behind"],
  "error": null,
  "git": {
    "isRepository": true,
    "branch": "main",
    "dirtyCount": 1,
    "untrackedCount": 0,
    "aheadCount": 0,
    "behindCount": 1,
    "lastCommitRelative": "2 hours ago"
  }
}
```

Stable `status` values are `clean`, `changed`, `path_missing`, `not_git`,
`scan_timeout`, and `scan_failed`. Stable attention reasons are `dirty`,
`untracked`, `behind`, `path_missing`, `scan_timeout`, and `scan_failed`.
Errors are either `null` or an object with stable `code` and redacted `message`;
only scan timeout/failure are partial failures.

The raw configured path remains identity. `resolvedPath` is the local path used
for filesystem and Git access. Counts are JSON numbers, booleans are JSON
booleans, collections are always arrays, and absent text values are `null`.

## Exit Codes

- `0`: JSON scan completed, no rendered project needs attention.
- `1`: JSON scan completed and at least one rendered project needs attention.
- `2`: JSON scan completed but at least one project timed out or failed to scan.
- `3`: JSON mode hit a fatal dependency, configuration, parsing, or
  serialization failure.

Partial failure takes precedence over attention. `--dirty` filters the project
array and `shown`, while `total` records all scanned enabled projects. Exit code
is derived from the rendered set so an excluded project does not unexpectedly
fail a filtered automation command. The existing human table and `--no-color`
retain their legacy success code after a completed scan.

## Output Boundaries

- JSON stdout contains exactly one document and no progress, color, header, tip,
  or action text.
- Recoverable scan failures are represented in the document. Fatal diagnostics
  go to stderr and return 3 without a partial JSON document.
- `--no-color` uses the existing table information with plain text only and no
  ANSI escape sequences under PowerShell, bash, or zsh.
- `Get-ProjectStatus -PassThru` remains backward compatible. `-Json` is a
  separate serialization mode and cannot be combined with `-PassThru`.

## Compatibility

Schema version 1 is additive to the existing CLI and object surface. Consumers
must reject unsupported major schema versions but may ignore unknown fields.
Human labels may evolve; automation relies on status/reason/error codes.

PowerShell 5.1 and Bash 3.2 syntax remain required. Shell JSON is assembled with
`jq`; status already requires `jq` for configuration parsing.

## Validation

- One shared fixture covers clean, changed, behind, missing, non-Git, timeout,
  and failed projects.
- PowerShell and shell documents are normalized by removing timestamps/durations
  before equality comparison.
- Tests assert JSON parsing, field types, reason ordering, stdout/stderr split,
  exit codes, dirty filtering, parser conflicts, and zero ANSI for no-color.
- Existing status tables, `-PassThru`, fix/push, concurrency, timeout, cache, and
  Bash/zsh/Bash 3.2 regressions remain green.
