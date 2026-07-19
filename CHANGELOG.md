# Changelog

## 2.1.0

### Added

- Added atomic JSON persistence with sibling locks, SHA-256 concurrency checks, bounded backups, and explicit recovery helpers.
- Added project-scoped command-hook trust with redacted `hook list/trust/revoke` management and `--no-hook` bypass.

### Changed

- Routed project, recent-state, workspace, repair, scan, metadata, and status-fix writes through the same PowerShell and shell persistence contract.
- Invalid state files are no longer silently replaced with empty data.
- Command hook trust automatically becomes stale when the config path, project identity, or command fingerprint changes.
- Added PowerShell `ShouldProcess`, `-WhatIf`, `-Confirm`, and opt-in structured action results across mutation boundaries.
- Added shell `--dry-run` and `--yes` safety contracts, including explicit approval for repair, remove, scan/import, init, status actions, config selection, and external workspace launch.
- Batch status/workspace actions now report each target, preserve later targets after a failure, and expose a non-success result when any target fails.
- Status push plans now include the resolved remote and upstream before execution.
- Config discovery is read-only; only explicit config-selection commands persist the active choice.

## 2.0.5

### Security

- Command `onEnter` hooks are skipped by default and require one-time `-AllowHook` / `--allow-hook` authorization.
- Structured hook environment variable names are validated before being applied.
- `status --fix` and `status --push` support dry-run and require explicit confirmation before changing config or remotes.
- Workspace launchers are passed as direct argv tokens and command-line input is rejected.
- Remote shell installs pin the release tag and verify the downloaded `cdp.sh` SHA-256 before replacement.
- Scoop release archives use a real SHA-256 instead of skipping verification.

## 2.0.4

### Added

- Added one repository-managed bash/zsh v2 regression entry covering dependencies, lifecycle, hooks, workspaces, completion, scans, and cross-platform paths.

### Fixed

- Reworked CLI argument parsing so `status` filters, tags, actions, and custom config paths are interpreted independently of order.
- Prevented `workspace --open` and its launcher value from leaking into the workspace project list.
- Preserved custom config paths for short project-management commands.
- Recognized linked Git worktrees and retained both dirty and untracked counts in status output.
- Resolved shared Windows project paths before bash/zsh status and workspace filesystem access.
- Limited `status --fix` to the enabled missing projects shown in its action preview, preserving disabled entries.
- Corrected behind-only shell summaries and native Git push failure reporting.
- Applied `-DirtyOnly` filtering consistently to structured `-PassThru` status results.
- Preserved empty launcher arguments in bash/zsh so Codex, Claude, Gemini, and custom commands no longer receive their display label as an argument.
- Isolated bash/zsh workspace project iteration from child-process stdin so every configured project is visited.
- Prevented zsh path variables from shadowing executable lookup during conversion, listing, recent, add, clean, doctor, and config selection flows.
- Isolated bash/zsh repository scan iteration from child-process stdin so every discovered repository is imported.
- Restored zsh completion indexing under the shared array compatibility mode and added the missing `workspace` completion candidate.
- Selected PowerShell 5.1/7 CurrentUser and AllUsers install roots from the active edition's discoverable `PSModulePath` entry.
- Verified source installations against the exact target module path and manifest version instead of accepting an older module elsewhere.
- Updated the Scoop manifest to 2.0.4 and made it reuse the root installer without nested fzf setup.
- Added a PowerShell 5.1/7 release-metadata validator for runtime headers, tests, Scoop, changelog, progress, and release notes.

## 1.8.0

### Added

- Added PowerShell workspace launching with `cdp api -Open codex` and `Switch-Project -Open`.
- Added WSL/Linux workspace launching with `cdp api --open codex`.
- Added launcher presets for `code`, `cursor`, `codex`, `claude`, and `gemini`, while still allowing custom commands on `PATH`.
- Added pinned projects with `cdp pin`, `cdp unpin`, `cdp-pin`, and `cdp-unpin`.
- Added safe config repair with `cdp clean`, `cdp-clean`, and `cdp doctor --fix`.
- Added first-run setup with `cdp init` and `cdp-init`.
- Added project aliases and tags with `cdp alias`, `cdp tag`, and tag queries such as `cdp '@work'`.

### Changed

- Reworked the bilingual 28-second HyperFrames demo to show AI CLI launching, project metadata, safe setup/repair, and PowerShell/WSL parity.

## 1.7.0

### Added

- Added `cdp recent` / `cdp-recent` for listing recently visited projects.
- Added recent project tracking in `~/.cdp/state.json` after successful PowerShell and WSL/bash switches.
- Added `CDP_STATE_PATH` override for isolated automation and tests.

## 1.6.3

### Fixed

- Fixed Windows PowerShell preview script launching by passing the `-File` path with double quotes instead of single quotes.

## 1.6.2

### Fixed

- Fixed PowerShell `fzf` preview lookup by passing the selected row index as a preview script argument instead of embedding `{1}` inside a quoted file path.

## 1.6.1

### Fixed

- Fixed PowerShell `fzf` picker color theme argument passing so `cdp` no longer reports `unknown option: fg:#...`.

## 1.6.0

### Added

- Added a neon-styled `fzf` picker with ANSI-colored project rows, rounded border, pointer/marker styling, and a right-side project preview.
- Added project preview details for path availability and Git repository detection.

### Changed

- `cdp-ls` / `Get-ProjectList` now renders a compact aligned table instead of the previous two-line-per-project list.
- PowerShell and WSL/bash picker styling now stay visually consistent without adding new required dependencies.

## 1.5.0

### Added

- Added `cdp about`, `cdp version`, and `Show-CdpAbout` for compact logo, version, config, project count, and upgrade guidance.
- Added a `cdp doctor` update check that compares the installed module version with the latest PowerShell Gallery release.
- Added upgrade guidance when a newer version is available.

### Changed

- `cdp doctor` now starts with a compact cdp brand header.
- The interactive `fzf` picker now shows a one-line header with the cdp version, project count, and active config path.
- Update checks are kept out of the normal `cdp` switching path to avoid slowing down project selection.

## 1.4.1

### Changed

- Cached parsed PowerShell project configuration within a session to reduce repeated `cdp` and `cdp-ls` overhead.
- Cached `fzf` command resolution and added `CDP_FZF_PATH` support for pinning the executable path.
- Added performance guidance for Windows Terminal cold starts in both README files.

### Fixed

- Invalidated the project config cache after `cdp-add`, `cdp-scan`, and `cdp-rm` write changes.

## 1.4.0

### Added

- Added `cdp <query>` and `Switch-Project -Query` fast matching for PowerShell.
- Added `cdp <query> [config]` fast matching for bash/zsh.
- Added `Import-GitProjects`, `cdp-scan`, and `cdp scan` for bulk Git repository imports.
- Added query smoke coverage in Pester and GitHub Actions bash checks.
- Added `PROGRESS.md` to track public release polish work.
- Added real-world README workflow examples for multi-repo, AI CLI, and Windows + WSL usage.

### Changed

- Query mode switches directly when one project matches and falls back to `fzf` when multiple projects match.
- Non-path positional arguments now act as project queries, while path-like and `.json` arguments remain custom config paths.
- Updated Chinese and English README files for query usage and clearer tool comparison.
- Expanded README comparisons with `zoxide`, `autojump`, plain `fzf cd` scripts, and VS Code/Cursor Project Manager.
- Improved first-time install guidance and dependency fallback messages for `fzf` setup.

## 1.3.0

### Added

- Added `cdp doctor` and `cdp-doctor` diagnostics for dependencies, active config, JSON shape, duplicate names, enabled projects, and missing paths.
- Added `Invoke-Cdp` as the short command entry point so `cdp` can support lightweight subcommands while keeping the original picker behavior.
- Added Pester tests for the module manifest, exported commands, aliases, config writing, and health checks.
- Added GitHub Actions CI for Windows PowerShell 5.1, PowerShell 7.x, and bash smoke checks.
- Added an intro video script and hyperframes production notes in `docs/video/cdp-intro-script.md`.

### Changed

- Reworked both Chinese and English README files around a faster open-source onboarding flow.
- Updated contribution guidance to use Pester 5+.
- Synchronized PowerShell and bash/zsh version numbers to 1.3.0.
- Updated the Scoop manifest metadata for the 1.3.0 release.

## 1.2.6

### Fixed

- Fixed IME candidate selection via number keys and mouse clicks in fzf.
- Added input encoding configuration for IME compatibility.
- Added `--no-mouse` to reduce IME mouse event conflicts.

## 1.2.0

### Added

- Added WSL/Linux bash/zsh support.
- Added `Switch-Project -WSL` for launching WSL directly from PowerShell.
- Added Windows path to WSL path conversion.
- Added shared configuration support between Windows and WSL.
