# v2.0.5 CI 发布阻断修复

## Goal

Make the v2.0.5 release gate reproducible on hosted Linux/macOS runners.

## Requirements

- Scoop package bytes must be independent of checkout line endings and file mtimes.
- The shell status regression must report the failing action state instead of exiting silently on macOS Bash.
- Existing v2.0.5 behavior and local PowerShell/bash/zsh tests must remain unchanged.

## Acceptance Criteria

- [ ] The Scoop package generated twice from the same tree has one SHA-256, and the CI manifest hash matches it.
- [ ] The status test passes on Bash 3.2-compatible behavior and prints actionable diagnostics on failure.
- [ ] GitHub Actions PowerShell 5.1, PowerShell 7, Linux Bash, and macOS Bash/zsh jobs are green.

## Notes

- Keep `prd.md` focused on requirements, constraints, and acceptance criteria.
- Lightweight tasks can remain PRD-only.
- For complex tasks, add `design.md` for technical design and `implement.md` for execution planning before `task.py start`.
