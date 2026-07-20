# Safe Multi-Repository Exec

## Scenario: Execute One Native Command Across Selected Projects

### 1. Scope / Trigger

Apply whenever `cdp exec` / `cdp run`, selector resolution, path planning,
native process execution, concurrency, timeout, fail-fast, output, completion,
or exec JSON changes. The contract prevents option leakage, shell injection,
wrong-repository execution, nondeterministic automation output, and partial
side effects before validation completes.

### 2. Signatures

```text
cdp exec [projects...|@tag|--workspace <name>|--all] [options] -- <command> [args...]

options:
  --config <projects.json>
  --jobs <1-16>
  --timeout <1-3600>
  --fail-fast | --continue
  --json
  --dry-run | --yes

environment defaults:
  CDP_EXEC_CONCURRENCY=1..16
  CDP_EXEC_TIMEOUT_SECONDS=1..3600
```

PowerShell routes through `ConvertFrom-CdpExecTokens`, `New-CdpExecPlan`, and
`Invoke-CdpExecPlan`. Shell routes through `cdp_exec_parse`,
`cdp_exec_build_plan`, and `cdp-exec`.

### 3. Contracts

- The first exact `--` is mandatory. Every later token is command argv and is
  never parsed as a cdp option.
- Exactly one selector kind is allowed: explicit projects, one tag, one
  workspace, or explicit `--all`. Empty selection never implies all projects.
- Explicit projects use exact case-sensitive names and input order. Tags are
  case-insensitive and use config order. Workspaces use reference order and
  stable raw-path identity. `--all` uses enabled config order.
- De-duplicate by exact configured `rootPath`, preserving the first occurrence.
- Complete config, selector, stable-reference, path-profile, path-existence,
  executable, jobs, and timeout planning before approval or process creation.
- Invoke only a resolved native executable plus an argv array. Do not use
  `eval`, implicit `sh -c`, untrusted scriptblocks, or concatenated commands.
- Each process has an isolated resolved cwd, closed stdin, stdout/stderr
  capture, elapsed time, native exit code, and per-project timeout.
- Default execution continues later safe targets. Fail-fast completes the
  current bounded batch and marks future planned targets `canceled`.
- PowerShell uses High-impact `ShouldProcess`; shell real execution requires
  `--yes`. `-WhatIf` / `--dry-run` creates no process.
- JSON schema version 1 owns stdout and preserves selection order. Results use
  `planned`, `succeeded`, `failed`, `timed_out`, `canceled`,
  `missing_project`, `ambiguous_project`, `disabled_project`,
  `path_profile_invalid`, or `path_missing`.
- Exit codes: `0` success/valid preview, `1` continue-mode target failure,
  `2` fail-fast cancellation, `3` fatal parse/dependency/config/selector/
  executable/serialization failure.

### 4. Validation & Error Matrix

- Missing `--` or command -> fatal `3`; no process.
- Empty/mixed selector or unknown explicit project -> fatal `3`; no process.
- Duplicate/ambiguous exact project name -> fatal `3`; no process.
- Missing native executable -> fatal `3`; no process.
- Invalid global `CDP_PATH_PROFILE` -> fatal `3`; no process.
- Workspace missing/ambiguous/empty -> fatal `3`; no process.
- Workspace missing/ambiguous/disabled reference or invalid/missing local path
  -> ordered unavailable result; continue later safe targets unless fail-fast.
- Missing shell `--yes` -> fatal `3`; stdout remains empty in JSON mode.
- Native nonzero -> `failed`; deadline -> `timed_out`; no later batch after a
  fail-fast failure.
- JSON fatal path -> stderr only; successful/partial path -> one stdout document.

### 5. Good / Base / Bad Cases

- Good: `cdp exec @work --json --yes -- git status --short` resolves every
  local path, runs bounded native argv, and emits one ordered document.
- Base: `cdp exec api web --dry-run -- git fetch` emits planned rows and creates
  no process.
- Bad: `cdp exec --all --yes -- "git status | grep M"` treats a command string
  as an executable. Use explicit `sh -c` only when shell syntax is intentional.

### 6. Tests Required

- PowerShell, bash, zsh, and Bash 3.2 cover explicit/tag/workspace/`--all`,
  empty/mixed selectors, exact raw identity deduplication, and config order.
- Parser tests preserve spaces, empty argv, `--json`, semicolons, and other
  metacharacters after the boundary.
- Execution tests assert cwd, stdout, stderr, exit code, elapsed time, timeout,
  continue, fail-fast cancellation, and no injected side effect.
- Safety tests assert dry-run and missing approval create no process.
- JSON tests assert one document, stable fields/statuses/order, stderr-only
  fatal behavior, and exit codes 0-3.
- Completion tests cover `exec`, projects, tags, workspaces, options, numeric
  values, and no cdp completion after `--`.

### 7. Wrong vs Correct

Wrong:

```bash
eval "cd '$project_path' && $command $arguments"
```

Correct:

```bash
cd -- "$resolved_path" || exit 1
"$executable" "${argv[@]}" </dev/null >"$stdout" 2>"$stderr"
```

PowerShell follows the same boundary with a fixed module-owned worker:

```powershell
$startInfo = [Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $Executable
$startInfo.WorkingDirectory = $ResolvedPath
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
# .NET Core uses ArgumentList; Windows PowerShell 5.1 uses a quoted Arguments line.
```

Do not use PowerShell stream redirection for native stderr in the shared worker:
Windows PowerShell 5.1 wraps it as `NativeCommandError` and corrupts raw capture.
