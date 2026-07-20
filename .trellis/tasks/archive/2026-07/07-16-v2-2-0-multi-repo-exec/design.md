# 多仓库 exec 技术设计

## 1. Parser 与命令边界

PowerShell 在 common-option parser 之前识别 `exec`，先按第一个 exact `--` 拆分：

```text
selector/options tokens | -- | executable argv
```

边界后 token 永不进入 `Split-CdpCommonOptions`。shell `cdp()` 直接路由到
`cdp-exec`，由同样的边界规则解析。新增 normalized invocation fields：

```text
ExecSelectorKind, ExecProjectNames, ExecTag, ExecWorkspace, ExecAll,
ExecCommand, ExecArguments, ThrottleLimit, TimeoutSeconds, FailFast,
Json, ConfigPath, DryRun, Yes
```

## 2. Selection plan

新增 PowerShell `ExecSelection.ps1` 与 shell `ExecSelection.sh`：

```text
config/workspace read -> selector resolution -> stable identity de-dup
-> path profile resolution -> ordered plan
```

Plan item carries `name`, raw/resolved path, project, status, and error. Explicit
names are exact and fatal when unknown/ambiguous. Workspace items reuse the workspace
resolver and may contribute non-runnable result rows while later safe rows continue.
Tag/all use enabled config order. Empty selector is fatal; `--all` is explicit.

## 3. Native execution

PowerShell uses a bounded runspace pool. Each fixed module-owned worker receives
the resolved executable path and a string-array argv, changes to one resolved
directory, invokes `& $Executable @Arguments`, redirects stdout/stderr to sibling
temporary files, records native exit code and elapsed time, and is stopped on timeout.
No untrusted scriptblock or command string is created.

Shell schedules fixed-size batches compatible with Bash 3.2. Each background wrapper
changes directory and executes `"$executable" "${argv[@]}"` with separate temp files.
A portable `kill -0` watchdog enforces timeout without GNU `timeout`; fail-fast stops
future batches after the first failed batch and marks unscheduled rows canceled.

Both runtimes complete the full selection/path/executable plan before approval or the
first process. Results are reordered by original plan index before rendering.

## 4. Safety

All actual execution is high impact because arbitrary executable risk cannot be inferred
reliably. PowerShell uses `SupportsShouldProcess(ConfirmImpact=High)` and shell requires
`--yes`; preview uses `-WhatIf` / `--dry-run`. JSON preview emits `planned` rows. Missing
paths or invalid workspace refs are result failures, not command invocations.

## 5. Output schema

JSON schema version 1:

```json
{
  "schemaVersion": 1,
  "generatedAt": "ISO-8601 UTC",
  "durationMs": 12,
  "selector": { "kind": "tag", "value": "work" },
  "command": { "executable": "git", "arguments": ["status", "--short"] },
  "options": { "jobs": 4, "timeoutSeconds": 300, "failFast": false, "dryRun": false },
  "summary": { "total": 2, "succeeded": 1, "failed": 1, "timedOut": 0, "canceled": 0 },
  "results": [
    { "name": "api", "rawPath": "C:/Work/api", "resolvedPath": "/work/api",
      "status": "succeeded", "exitCode": 0, "elapsedMs": 8, "stdout": "", "stderr": "", "error": null }
  ]
}
```

Fatal code-3 paths write stderr only. Human output renders the same ordered result model.

## 6. Compatibility and rollback

- No config schema mutation is introduced.
- PowerShell 5.1 avoids `ProcessStartInfo.ArgumentList`; shell avoids `wait -n`, associative arrays, and GNU-only timeout.
- Generated `src/cdp.sh` remains the distribution artifact.
- Rollback removes the exec domains/parser route without rewriting user state.
