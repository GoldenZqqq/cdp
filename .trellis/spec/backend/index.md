# Backend Development Guidelines

The backend layer is the cross-platform CLI implementation, installers, release
tooling, and repository-owned validation. PowerShell and bash/zsh are separate
runtimes that must expose equivalent user contracts while keeping native
implementation patterns.

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | PowerShell bootstrap/domains, shell fragments/generated artifact, tests, and tooling ownership | Active |
| [JSON Persistence](./database-guidelines.md) | Project config, recent state, workspaces, trust storage, atomic writes, locks, and backups | Active |
| [Error Handling](./error-handling.md) | Exceptions, native exit codes, safe mutation results, partial failure, and recovery | Active |
| [Quality Guidelines](./quality-guidelines.md) | CLI contracts, cross-runtime regression scenarios, CI, package, and release validation | Active |
| [Output and Diagnostics](./logging-guidelines.md) | User messages, progress, structured action output, stderr, and redaction | Active |

## Pre-Development Checklist

1. Read the current Trellis task artifacts and this index.
2. Read `directory-structure.md` before adding or moving runtime files.
3. Read `database-guidelines.md` for any JSON read/write or state change.
4. Read `error-handling.md` and `logging-guidelines.md` for new command paths.
5. Read the matching scenarios in `quality-guidelines.md` before editing parser,
   status, hooks, workspace, installer, generated shell, or release metadata.
6. Preserve PowerShell 5.1 and bash 3.2 syntax unless the support policy changes.

## Quality Check

- PowerShell implementation changes run `scripts/Invoke-PowerShellQualityGate.ps1`.
- Shell source changes run `scripts/Build-ShellScript.sh --check`, syntax,
  ShellCheck, bash/zsh regressions, and Bash 3.2 compatibility.
- Manifest or package changes run `scripts/Test-ReleaseMetadata.ps1` and
  `scripts/Test-ScoopPackage.sh`.
- All changes finish with Trellis validation and `git diff --check`.
