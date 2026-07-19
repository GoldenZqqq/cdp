# Safe Mutation Implementation

1. Add shared PowerShell action-result helpers and `ShouldProcess` to project,
   metadata, repair, scan/remove, config-choice, workspace, hook-trust, and
   status action boundaries.
2. Extend the PowerShell parser/dispatcher for safe mutation routing and make
   status push/fix expose per-target structured results without aborting later
   targets.
3. Add shell safety-option parsing helpers, low/high risk approval rules, and
   apply them to config, workspace, hook, project, metadata, repair, scan, and
   status mutations.
4. Make workspace external launch previewable/confirmable and verify no process
   starts in dry-run/WhatIf mode.
5. Add PowerShell and bash/zsh/Bash 3.2 regressions for no-write/no-push/no-launch,
   non-interactive refusal, low-risk compatibility, and partial batch failure.
6. Synchronize English/Chinese docs, release notes, specs, completion, CI, and
   final release digests; run all project quality gates.

## Completion Evidence

- [x] PowerShell mutation boundaries use `SupportsShouldProcess`; high-impact
  routes use `ConfirmImpact='High'`, and `-PassThru` returns action results.
- [x] Shell mutation routes parse `--dry-run`/`--yes`; high-impact commands do
  not read stdin for confirmation and automatic config discovery is read-only.
- [x] Status push plans include remote/upstream and continue after failures;
  workspace launches report per-project outcomes.
- [x] Pester 7.5.2 arm64: `80/80`; PSScriptAnalyzer Error severity: no errors.
- [x] Bash, zsh, and Bash 3.2: safe-mutation, status, shell v2, persistence,
  CLI, and installer tests passed.
- [x] Release metadata, YAML/JSON, Trellis validation, `git diff --check`,
  installer and Scoop digests passed.

## Rollback

Revert option routing and mutation boundaries together. Atomic JSON backups may
remain; rollback does not undo user mutations already explicitly approved.
