# Backend Error Handling

## Error Channels

- PowerShell public commands use terminating exceptions for invalid arguments,
  persistence failures, or unsafe preconditions. Dispatch boundaries catch only
  when they can add a user-level message or preserve a successful primary action.
- Shell commands print actionable failures to stderr and return nonzero. Native
  Git, jq, fzf, tmux, and launcher exit codes must not be reported as success.
- Structured mutation callers receive `Action`, `Target`, `Status`, `Changed`,
  and `Error`; shell mutations print the equivalent one-line action result.

## Validate Before Side Effects

Follow `parse -> validate -> plan -> approve/preview -> execute -> aggregate`.

- Parse all tokens before dependency checks or command dispatch.
- Resolve project matches, config paths, workspaces, and status targets before
  writing JSON, pushing Git, or launching external tools.
- `-WhatIf` / `--dry-run` performs no writes or native side effects.
- High-impact shell actions require `--yes`; never read approval from stdin.

## Partial Failure

Batch status push and workspace launch continue safe later targets after one
item fails. Report every target and return/emit an aggregate failure. Do not stop
at the first item unless continuing could corrupt shared state.

Workspace launch plans use stable statuses: `ok`, `legacy`, and `renamed` are
launchable; `invalid-workspace`, `invalid-layout`, `invalid-reference`,
`invalid-size`, `invalid-launcher`, `missing-project`, `ambiguous-project`,
`disabled-project`, `invalid-path-profile`, and `missing-path` are not. Complete
schema, reference, path, launcher, and native-argv planning before the first WT
or tmux process. A CLI launcher override must validate before any target starts.

Recent-project recording and optional update checks are secondary effects. A
failure there may be verbose/warning output but must not undo a successful
directory switch. Persistence or trust failures that protect security remain
hard failures.

Read-only status JSON aggregates failures after scanning safe later projects:
0 means clean success, 1 attention, 2 timeout/scan partial failure, and 3 fatal
parse/dependency/config/serialization failure. A code-3 path writes stderr only;
codes 0-2 always accompany one complete schema document on stdout.

## Redaction

Never include command-hook text, environment values, API keys, or full trust
payloads in errors. Hook diagnostics identify project and state only. Installer
and release scripts may test whether a secret variable exists but never print it.

## Native Process Rules

- Invoke native tools with argv, not concatenated command strings.
- Capture and test `$LASTEXITCODE` / shell status before printing success.
- Time-limited status probes surface `status timed out` and allow other repos to
  complete.
- A dependency missing from `PATH` names the dependency and stops before action.
- An invalid `CDP_PATH_PROFILE` stops the command before filesystem or Git work;
  JSON status writes the fatal diagnostic to stderr and returns 3.
- An invalid per-project `paths` mapping is isolated as
  `path_profile_invalid`; never fall back to another configured directory.

Trusted examples: `src/PowerShell/Commands.ps1`, `src/Shell/Commands.sh`,
`tests/cdp.SafeMutations.Tests.*`, and `tests/cdp.Shell.V2.Tests.sh`.
