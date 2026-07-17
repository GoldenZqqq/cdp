# Progress

## Goal

Prepare `cdp` for a stronger public release by improving first-run clarity, terminal AI workflow fit, and visible product completeness.

## Release Polish Checklist

- [x] Create a public progress tracker for the release polish work.
- [x] Add `cdp <query>` fast matching.
  - Directly switch when a query has exactly one match.
  - Fall back to `fzf` when a query has multiple matches.
  - Keep positional custom config path compatibility for `.json` and path-like arguments.
- [x] Add batch Git repository scanning to generate/import project config.
- [x] Strengthen README comparison against `zoxide`, `autojump`, and plain `fzf cd` scripts.
- [x] Smooth the install path, especially first-time `fzf` setup.
- [x] Add real-world usage scenarios for multi-repo, AI CLI, and Windows + WSL workflows.

## Current Focus

Latest verified public release: v2.0.3 on GitHub Releases and PowerShell Gallery (verified 2026-07-17).

Current release target: v2.0.4.

Release status: the local v2.0.4 release candidate has passed the complete PowerShell, shell, metadata, syntax, and repository validation matrix. Push, remote CI, tag, GitHub Release, PowerShell Gallery publication, and post-release channel verification remain pending.

## 2.0.4 Stability Checklist

- [x] Fix CLI argument parsing and cross-platform status correctness.
- [x] Add PowerShell and bash/zsh v2 regression suites.
- [x] Select source-install module paths by PowerShell edition and discoverable `PSModulePath` roots.
- [x] Verify source installs against the exact target path and manifest version.
- [x] Update Scoop metadata to 2.0.4 and reuse the root installer.
- [x] Add canonical release-metadata validation to PowerShell 5.1 and 7 CI jobs.
- [x] Pass 58/58 Pester tests under PowerShell 7 and Windows PowerShell 5.1.
- [x] Pass PSScriptAnalyzer Error, Git Bash CLI/status/shared regressions, WSL bash/zsh shared regressions, and shell syntax checks.
- [ ] Push the completed v2.0.4 commits, pass remote CI, create the tag and GitHub Release, publish PowerShell Gallery, and verify all public channels.

## 1.7.0 Recent Projects Checklist

- [x] Mark 1.6.3 release work as complete.
- [x] Record recently visited projects after successful PowerShell switches.
- [x] Record recently visited projects after successful WSL/bash switches.
- [x] Add `cdp recent` / `cdp-recent` listing commands.
- [x] Keep recent state separate from project configuration in `~/.cdp/state.json`.
- [x] Run full release validation.
- [ ] Publish v1.7.0 to GitHub Releases and PowerShell Gallery. Superseded by 1.8.0 release preparation.
- [ ] Upgrade local cdp installation to v1.7.0. Superseded by 1.8.0 release preparation.

## 1.8.0 AI CLI Workspace Launcher Checklist

- [x] Decide the next public submission angle: cdp as an AI CLI workspace launcher, not only a directory switcher.
- [x] Add PowerShell `-Open` support so `cdp api -Open codex` switches into a project and starts Codex, Claude, Gemini, VS Code, Cursor, or another PATH command.
- [x] Add WSL/Linux `--open` support so `cdp api --open codex` mirrors the PowerShell workflow.
- [x] Document the workspace-launching workflow in both README files.
- [x] Add tests for launcher parsing and dry-run execution.
- [x] Add project pinning/favorites so frequent projects can stay at the top of the picker.
- [x] Add `cdp doctor --fix` / `cdp clean` for stale paths, duplicates, and safe config cleanup.
- [x] Add `cdp init` first-run setup for dependency checks, project scanning, and config selection.
- [x] Add tags or aliases such as `@work`, `@ai`, and short project nicknames.
- [x] Run PowerShell, ScriptAnalyzer, bash syntax, and whitespace validation.

## Post-1.8 Public Submission Backlog

- [ ] Improve the public demo around the AI CLI workflow and the difference from zoxide/autojump.

## Verification Log

- Release 2.0.4 candidate: PowerShell 7 and Windows PowerShell 5.1 Pester each passed 58/58 tests.
- Release 2.0.4 candidate: the canonical metadata validator passed under PowerShell 7 and Windows PowerShell 5.1.
- Release 2.0.4 candidate: PSScriptAnalyzer reported no Error-severity findings.
- Release 2.0.4 candidate: Git Bash CLI parser, status, and shared shell v2 regressions passed.
- Release 2.0.4 candidate: WSL bash/zsh shared regressions and bash/zsh syntax checks passed.
- Release 2.0.4 candidate: Scoop JSON, workflow YAML, Trellis task validation, and `git diff --check` passed.

- PowerShell 7 Pester: `Invoke-Pester -Path ./tests -CI` passed 7 tests.
- PSScriptAnalyzer: `Invoke-ScriptAnalyzer -Path ./src/cdp.psm1 -Severity Error` reported no errors.
- Windows PowerShell 5.1: `Test-ModuleManifest -Path ./cdp.psd1` loaded version 1.3.0.
- Windows PowerShell 5.1: `Invoke-Cdp` exposes the new `Query` parameter.
- WSL Arch: `bash -n ./src/cdp.sh` passed.
- Local WSL query smoke was not run end-to-end because this Arch distro does not have `jq`; the CI workflow installs `jq` and now includes the query smoke.
- Windows `jq`: the exact-match and contains-match filters used by bash query mode returned the expected enabled project.
- PowerShell 7 Pester after Git scan import: `Invoke-Pester -Path ./tests -CI` passed 9 tests.
- PSScriptAnalyzer after Git scan import: `Invoke-ScriptAnalyzer -Path ./src/cdp.psm1 -Severity Error` reported no errors.
- CI bash smoke now creates two fake Git repositories and checks `cdp-scan` writes both to JSON.
- Install path polish: `Install.ps1` parsed successfully on Windows PowerShell 5.1.
- Install path polish: `Invoke-Pester -Path ./tests -CI` passed 9 tests.
- Install path polish: `bash -n ./install-wsl.sh` and `bash -n ./src/cdp.sh` passed in WSL.
- Release 1.4.0: Windows PowerShell 5.1 `Invoke-Pester -Path ./tests -CI` passed 9 tests.
- Release 1.4.0: PowerShell 7 `Invoke-Pester -Path ./tests -CI` passed 9 tests.
- Release 1.4.0: `Invoke-ScriptAnalyzer -Path ./src/cdp.psm1 -Severity Error` reported no errors.
- Release 1.4.0: WSL Arch `bash -n ./src/cdp.sh` and `bash -n ./install-wsl.sh` passed.
- Release 1.4.0: `git diff --check` reported no whitespace errors.
- Release 1.4.1: Added PowerShell session caches for project config parsing and `fzf` command resolution.
- Release 1.4.1: PowerShell 7 direct switch timing improved from about 154.6 ms to 16.6 ms on the second same-session call.
- Release 1.4.1: PowerShell 7 `Invoke-Pester -Path ./tests -CI` passed 10 tests.
- Release 1.4.1: Windows PowerShell 5.1 `Invoke-Pester -Path ./tests -CI` passed 10 tests.
- Release 1.4.1: `Invoke-ScriptAnalyzer -Path ./src/cdp.psm1 -Severity Error` reported no errors.
- Release 1.4.1: WSL Arch `bash -n ./src/cdp.sh` and `bash -n ./install-wsl.sh` passed.
- Release 1.4.1: `git diff --check` reported no whitespace errors.
- Release 1.5.0: Added `cdp doctor` update reminder with PowerShell Gallery version comparison.
- Release 1.5.0: Added `cdp about` / `cdp version` brand and runtime information.
- Release 1.5.0: Added a compact fzf picker header with cdp version, project count, and active config path.
- Release 1.5.0: Upgrade guidance uses `Update-Module -Name cdp -Scope CurrentUser -Force`.
- Release 1.5.0: Windows PowerShell 5.1 `Invoke-Pester -Path ./tests -CI` passed 12 tests.
- Release 1.5.0: PowerShell 7 `Invoke-Pester -Path ./tests -CI` passed 12 tests.
- Release 1.5.0: `Invoke-ScriptAnalyzer -Path ./src/cdp.psm1 -Severity Error` reported no errors.
- Release 1.5.0: WSL Arch `bash -n ./src/cdp.sh` and `bash -n ./install-wsl.sh` passed.
- Release 1.5.0: `git diff --check` reported no whitespace errors.
- Release 1.6.0: Added neon-themed fzf rows, right-side picker preview, and compact cdp-ls tables for PowerShell and WSL/bash.
- Release 1.6.1: Fixed PowerShell fzf color theme native argument passing.
- Release 1.6.2: Fixed PowerShell fzf preview placeholder handling on Windows.
- Release 1.6.3: Fixed Windows PowerShell preview script -File path quoting.
- Release 1.7.0: Added recent project tracking for PowerShell and WSL/bash.
- Release 1.7.0: Windows PowerShell 5.1 `Invoke-Pester -Path ./tests -CI` passed 14 tests.
- Release 1.7.0: PowerShell 7 `Invoke-Pester -Path ./tests -CI` passed 14 tests.
- Release 1.7.0: `Invoke-ScriptAnalyzer -Path ./src/cdp.psm1 -Severity Error` reported no errors.
- Release 1.7.0: WSL Arch `bash -n ./src/cdp.sh` and `bash -n ./install-wsl.sh` passed.
- Release 1.7.0: `git diff --check` reported no whitespace errors.
- Release 1.7.0: Local WSL recent smoke was not run end-to-end because this Arch distro does not have `jq`; CI installs `jq` and now covers `cdp recent`.
- Release 1.8.0: Added PowerShell `-Open` and WSL/Linux `--open` workspace launchers.
- Release 1.8.0: Added PowerShell and WSL/Linux project pinning with `cdp pin` / `cdp unpin`.
- Release 1.8.0: Added safe config repair with `cdp clean` / `cdp doctor --fix`.
- Release 1.8.0: Added first-run setup with `cdp init`.
- Release 1.8.0: Added aliases and tags with `cdp alias` / `cdp tag`.
- Release 1.8.0: PowerShell 7 `Invoke-Pester -Path ./tests -CI` passed 24 tests.
- Release 1.8.0: `Invoke-ScriptAnalyzer -Path ./src/cdp.psm1 -Severity Error` reported no errors.
- Release 1.8.0: WSL Arch `bash -n ./src/cdp.sh` and `bash -n ./install-wsl.sh` passed.
- Release 1.8.0: `git diff --check` reported no whitespace errors.
- Release 1.8.0: Local WSL `--open` smoke was not run end-to-end because this Arch distro did not return a `jq` path; CI now includes a dry-run `cdp --open` smoke.
- Release 1.8.0: Reworked the bilingual 28-second HyperFrames demo around workspace launching, project metadata, safe setup/repair, and PowerShell/WSL parity.
- Release 1.8.0: HyperFrames 0.7.47 `validate` and `inspect --samples 15` passed for both English and Simplified Chinese variants.
- Release 1.8.0: Rendered both variants as 1920x1080 30fps MP4 and 720x405 10fps GIF assets.
