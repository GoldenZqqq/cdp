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
- `recent reset` is high impact in shell and uses `--dry-run` / `--yes`;
  PowerShell uses `ShouldProcess`. Missing or empty history is a no-op before
  approval, while invalid state fails without changing bytes.

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

Multi-repository exec uses the same complete-plan boundary. Fatal parse,
dependency, config, selector, executable, or serialization failures return 3
and write no JSON stdout. Continue-mode target failures return 1; fail-fast
cancellation returns 2. Unavailable targets never start a process, and dry-run
never creates one.

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

## Scenario: Preserve Aggregate Failure and Dependency Ordering

### 1. Scope / Trigger

Apply when a nested status/workspace function can finish useful per-item work
but the public CLI still needs to report aggregate failure, or when a native
terminal dependency is needed only after at least one launchable item exists.

### 2. Signatures

```text
Invoke-Cdp status ... -Fetch
cdp-status ... --fetch
Invoke-CdpWorkspace <name> [-Open <launcher>] [-WhatIf]
cdp-workspace open <name> [--open <launcher>] [--dry-run|--yes]
```

PowerShell status may defer the aggregate fetch error through module-owned
state, but only the outer `Invoke-Cdp` boundary may call `$PSCmdlet` to emit it.
Workspace planning returns zero or more launchable items before resolving
`wt.exe` or checking tmux.

### 3. Contracts

- Per-repository fetch failure remains visible in the complete status result;
  later safe repositories still run.
- A public CLI invocation with one or more fetch failures leaves PowerShell
  `$?` false and returns nonzero in shell, after rendering the aggregate result.
- Internal helpers do not emit a non-terminating aggregate error against their
  own cmdlet scope and then let the outer command appear successful.
- Invalid direct, stored, or per-reference launchers make items non-launchable
  during planning. When no launchable item remains, no `wt`, tmux, or launcher
  lookup/process occurs.
- `-WhatIf` / `--dry-run` preserves the same validation order and starts no
  native process.

### 4. Validation & Error Matrix

- One fetch fails, later fetch succeeds -> complete output plus aggregate CLI
  failure; successful rows remain usable.
- Every fetch succeeds -> complete output and successful CLI status.
- Stored launcher is invalid -> `invalid-launcher`; no terminal dependency
  lookup and no process.
- Mixed invalid and valid workspace items -> invalid rows are reported; terminal
  lookup occurs only for the valid launch plan.
- Zero launchable items -> return the workspace validation result without
  approval, tmux checks, `wt.exe` lookup, or native launch.

### 5. Good / Base / Bad Cases

- Good: two repositories are scanned, one fetch fails, both rows render, and
  the outer command reports aggregate failure.
- Base: a workspace with one valid launcher reaches preview/approval without
  starting a process in dry-run mode.
- Bad: a nested helper calls `Write-Error`, catches/returns, and the outer CLI
  leaves `$?` true; or an invalid-only workspace queries `wt.exe` first.

### 6. Tests Required

- PowerShell invokes the exported `cdp status --fetch` route and asserts `$?`
  is false after an aggregate fetch failure, not only that a helper wrote text.
- Bash/zsh assert nonzero status while later safe repositories still finish.
- PowerShell and shell launcher tests install a failing terminal lookup shim and
  assert invalid-only workspaces reject before that shim is called.
- Direct, stored, mixed-item, and dry-run/WhatIf paths assert no unexpected
  native process marker is created.

### 7. Wrong vs Correct

Wrong:

```powershell
Show-CdpProjectStatus -Fetch
Write-Error 'One or more fetches failed' # nested scope can be masked by Invoke-Cdp
```

Correct:

```powershell
Show-CdpProjectStatus -Fetch
if ($script:CdpLastStatusFetchFailedCount -gt 0) {
    $PSCmdlet.WriteError($aggregateError) # outer Invoke-Cdp boundary
}
```

Wrong:

```text
resolve terminal dependency -> discover all items have invalid launchers
```

Correct:

```text
parse -> validate all launchers -> build launchable plan -> resolve terminal dependency
```
