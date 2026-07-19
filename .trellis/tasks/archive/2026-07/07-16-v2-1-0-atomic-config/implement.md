# Atomic JSON Persistence Implementation

1. Add cross-version PowerShell fingerprint, lock, temp, backup, replace, and
   restore helpers with focused Pester tests.
2. Migrate PowerShell project, state, workspace, scan, repair, status-fix, and
   metadata mutations to the persistence boundary.
3. Add shell fingerprint, lock, temp, validation, backup, and replace helpers
   with bash/zsh regression fixtures.
4. Migrate shell project, state, workspace, scan, repair, status-fix, and
   metadata mutations to the persistence boundary.
5. Add conflict, invalid JSON, permission/replacement failure, backup cap,
   recovery, and cache invalidation tests.
6. Run Pester, PSScriptAnalyzer, Bash 3.2, bash/zsh suites, syntax, metadata,
   ShellCheck on changed scripts, and `git diff --check`.

## Rollback

Revert callers and helpers together. Backups use an additive sibling naming
scheme and may remain; no rollback deletes user data.
