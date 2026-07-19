# Status Performance Implementation

1. Add pure porcelain-v2 parser fixtures and process-count regressions for clean,
   dirty/untracked, ahead/behind, detached, unborn, worktree, and non-Git cases.
2. Replace PowerShell per-repo probes with the unified collector; add ordered,
   bounded runspace batching, TTL cache, refresh, and timeout behavior.
3. Replace shell per-repo probes with the unified record collector; add bounded
   batch workers, optional TTL cache, refresh, timeout, and interrupt cleanup.
4. Extend parsers/dispatch for `--jobs` and `--refresh`; force refresh for fix/push.
5. Add fixed 50-repository benchmark scripts and record before/after statistics.
6. Synchronize generated shell artifact, bilingual docs, release notes, progress,
   spec, installer/Scoop hashes, and CI quality gates.
7. Run PowerShell 5.1/7-targeted Pester, bash/zsh/Bash 3.2 regressions,
   ShellCheck, metadata/package, YAML/JSON, Trellis, and whitespace gates.

## Completion Record

- [x] PowerShell and shell collectors use porcelain-v2 plus optional log only.
- [x] PowerShell runspace and shell batch workers preserve order and enforce bounded concurrency/timeouts, including one-worker operation.
- [x] TTL cache remains opt-in; refresh and fix/push bypass are wired through both parsers.
- [x] Fixed zsh compatibility for indirect environment lookup, `path` shadowing, and status output declarations; added Bash/zsh/Bash 3.2 regressions.
- [x] Added 50-repository benchmark scripts and recorded min/median/p95 results.
- [x] Synchronized README, changelog, progress, release notes, spec, CI, generated shell artifact, and package integrity metadata.
- [x] Official PowerShell 7.5.2 arm64 runtime passed Pester `95/95` and PSScriptAnalyzer; Windows PowerShell 5.1 remains covered by the hosted CI matrix because it cannot run on this Linux host.

## Rollback Points

- Validate unified parser correctness before enabling batch collection.
- Concurrency 1 plus TTL 0 must remain a tested compatibility mode.
- Do not combine status JSON output with this task.
