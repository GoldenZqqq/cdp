# Status Performance Design

## Unified Git Probe

Each repository uses at most two Git invocations:

```text
git -C <path> status --porcelain=v2 --branch
git -C <path> log -1 --format=%cr
```

The porcelain-v2 parser owns branch name/OID, upstream, ahead/behind, tracked
changes, and untracked counts. A nonzero status command identifies a non-Git or
failed repository without follow-up probes. The log command is skipped for an
unborn branch.

## PowerShell Batch Model

`Get-CdpGitProjectInfo` remains the single-repository collector.
`Get-CdpGitProjectInfoBatch` uses `RunspaceFactory.CreateRunspacePool`, available
in Windows PowerShell 5.1 and PowerShell 7. It serializes the collector script
block into each runspace, preserves input ordering, limits workers, and stops an
individual invocation after the configured timeout.

The batch helper accepts an internal collector script block so Pester can verify
parallel overlap, timeout, ordering, and cache behavior without real delays or
network access.

## Shell Batch Model

`cdp_status_collect_record` emits one delimiter-separated record per project.
`cdp-status` launches records in fixed-size batches because Bash 3.2 has no
portable `wait -n`. Results are read by original index, preserving display and
mutation target order. Git commands use `timeout`/`gtimeout` when available and
otherwise run directly; SIGINT/TERM terminates outstanding workers.

## Configuration

```text
CDP_STATUS_CONCURRENCY       default min(4, CPU count), range 1..16
CDP_STATUS_CACHE_TTL         default 0 (disabled), range 0..60 seconds
CDP_STATUS_TIMEOUT_SECONDS   default 10, range 1..60 seconds
cdp status --jobs <1..16> --refresh
Show-CdpProjectStatus -ThrottleLimit <1..16> -Refresh
```

Fix and push always bypass cache. Cache keys use normalized/resolved project
paths and expire only by explicit TTL; refresh clears/bypasses current entries.

## Failure Semantics

- Missing path: `path missing`, needs attention.
- Existing non-Git path: `not a git repo`, no attention.
- Parse/process failure: `status failed`, needs attention.
- Timeout: `status timed out`, needs attention; other projects still complete.
- Interrupt: stop outstanding workers, clean temporary results, return 130 in
  shell; PowerShell stops/disposes outstanding pipelines when unwinding.

## Benchmark

Repository-managed PowerShell and shell scripts create 50 isolated local repos
with one commit, run five warm measurements, report min/median/p95, Git process
count, OS/architecture, shell/PowerShell/Git versions, and require no remote.

## Rollback

Restore sequential collectors while retaining porcelain-v2 parsing if concurrency
causes a platform regression. Set concurrency to 1 and cache TTL to 0 for an
operational fallback without code rollback.
