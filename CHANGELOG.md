# Changelog

## Unreleased

### Added

- Added `cdp <query>` and `Switch-Project -Query` fast matching for PowerShell.
- Added `cdp <query> [config]` fast matching for bash/zsh.
- Added query smoke coverage in Pester and GitHub Actions bash checks.
- Added `PROGRESS.md` to track Ruan Yifeng Weekly submission polish work.

### Changed

- Query mode switches directly when one project matches and falls back to `fzf` when multiple projects match.
- Non-path positional arguments now act as project queries, while path-like and `.json` arguments remain custom config paths.
- Updated Chinese and English README files for query usage and clearer tool comparison.

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
