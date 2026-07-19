# Output and Diagnostics

cdp is an interactive CLI, not a daemon. Output is a user contract rather than
an application log stream.

## PowerShell Output

- Use `Write-Host` for formatted interactive tables, headers, progress summaries,
  and color. Use Red for errors, Yellow for warnings, Green for success, Cyan for
  headers, and Gray/DarkGray for secondary detail.
- Return objects only for explicit structured modes such as `-PassThru`; do not
  mix accidental pipeline objects into display commands.
- Use `Write-Verbose` for optional best-effort diagnostics, such as recent-state
  recording failures.
- Tests that assert host text capture the information stream with `6>&1`.

## Shell Output

- stdout carries normal command results and action records.
- stderr carries errors, warnings that automation must notice, and live status
  progress. Clear carriage-return progress before final rows.
- Keep human output comparable to PowerShell, but do not copy ANSI/platform code
  when native shell patterns are clearer.

## Structured Action Results

Mutation results use stable fields/labels:

```text
action=<verb> target=<identity> status=<preview|succeeded|failed|cancelled>
changed=<true|false> [error=<redacted message>]
```

PowerShell objects use the same semantics with property casing. A preview is not
success, and `Changed` is false for preview/cancel/failure.

Workspace `show`, launch preview, and shell dry-run render the same plan fields:
workspace, normalized layout, current project name, reference status, raw
`rootPath`, resolved local path, and effective launcher. Diagnostics use the
stable workspace status codes rather than localized prose. `validate --fix`
returns/prints `skipped` with `Changed=false` when no migration is needed.

## Machine-Readable Status

- `status --json` / `-Json` owns stdout and emits one schema-versioned document.
- Live progress, headers, tips, colors, and action lines are forbidden in JSON
  stdout. Fatal diagnostics go to stderr and return code 3.
- Recoverable timeout/scan failures belong in redacted per-project `error`
  objects and produce aggregate code 2 after all safe projects complete.
- `--no-color` / `-NoColor` keeps a human table but must contain no ESC byte.
- Field names, status/reason/error codes, booleans, numbers, nulls, and arrays are
  contracts; localized or styled labels are not machine fields.
- `rawPath` is always configured `rootPath`; `resolvedPath` is the selected
  current profile path. `path_profile_invalid` is a stable status and attention
  reason, while an invalid global profile override is fatal rather than a
  per-project record.

## Secret and Hook Redaction

- Never print hook command text or environment values.
- Trust lists show project, platform kind, and trusted/stale/untrusted only.
- Never print Gallery API keys, authorization headers, or secret-bearing paths.
- Tests use recognizable secret markers and assert they are absent from output.

## CI Diagnostics

Repository scripts print named stages (`Pester`, coverage, analyzer, metadata,
package, assets) so workflow failures identify the layer. CI uploads reports
instead of increasing console verbosity with copied assertions.

Avoid debug `echo`, unconditional object dumps, swallowed native errors, and
success messages emitted before the side effect has been verified.
