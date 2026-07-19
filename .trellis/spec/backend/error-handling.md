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

Recent-project recording and optional update checks are secondary effects. A
failure there may be verbose/warning output but must not undo a successful
directory switch. Persistence or trust failures that protect security remain
hard failures.

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

Trusted examples: `src/PowerShell/Commands.ps1`, `src/Shell/Commands.sh`,
`tests/cdp.SafeMutations.Tests.*`, and `tests/cdp.Shell.V2.Tests.sh`.
