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

Latest verified GitHub release: v2.0.5 (verified 2026-07-19). Latest verified PowerShell Gallery release: v2.0.4.

Current release target: v2.1.0.

Release status: v2.0.5 passed local and hosted CI and is published on GitHub. PowerShell Gallery publication is pending because no Gallery API key is available in the local or GitHub Actions environment. v2.1.0 engineering-foundation work is in progress and is not yet published.

## 2.1.0 Engineering Foundation Checklist

- [x] Route cdp-owned JSON mutations through atomic persistence boundaries in PowerShell and shell.
- [x] Reject stale writes with SHA-256 fingerprints and sibling locks.
- [x] Retain three bounded backups and expose explicit recovery helpers.
- [x] Diagnose valid backups when the active project config is damaged.
- [x] Bind persistent command-hook trust to config, project, and command fingerprints without storing command text.
- [ ] Complete the remaining v2.1.0 engineering, performance, CI, media, and documentation tasks.
- [ ] Pass the full cross-platform release gate and publish/verify every public channel.

## 2.1.0 Atomic Config Verification

- PowerShell 7.5.2: Pester `71/71`; PSScriptAnalyzer Error severity reported no findings.
- Bash, zsh, and Bash 3.2: persistence, stale-fingerprint, invalid JSON, lock,
  flush/replacement failure, backup recovery, doctor diagnostics, and syntax checks passed.
- Shell installer digest: `1e24985aadfc1d8d716c3463e268d426f74bfa468a044386ffa50dd379873484`.
- Deterministic Scoop package digest: `732276c93fdf9954fb77867932e86e510d3a1ce8dcb4bbe03d431fa9c87c3a48`.

## 2.0.5 Security Checklist

- [x] Skip command hooks by default and require one-time explicit authorization.
- [x] Validate structured hook environment keys without exposing command contents.
- [x] Add dry-run and explicit confirmation to status fix/push actions.
- [x] Launch workspace commands through argv instead of command-string injection paths.
- [x] Pin remote shell installation to v2.0.5 and verify the downloaded script digest.
- [x] Replace Scoop hash skipping with the independent release package SHA-256.
- [ ] Publish and verify v2.0.5 on PowerShell Gallery when an API key is available.

## 2.0.5 Verification Log

- PowerShell 7.5.2: Pester 64/64 passed across core, v2, and installer suites with `USERPROFILE` isolated to `$TestDrive` equivalent.
- PowerShell 7.5.2: PSScriptAnalyzer Error severity reported no findings for `src/cdp.psm1`.
- Bash and zsh: CLI parser, status, shell v2, installer negative tests, syntax, and shell installer metadata passed.
- Scoop package: `scripts/New-ScoopPackage.sh` generated `cdp-2.0.5.tar.gz`; local release asset SHA-256 `d97225a5be0f9cc857b2692e1d73f6c951be546c577db760b51ef86e7ad92716` matches `scoop/cdp.json`. CI validates the package contents and manifest hash shape; the published asset is verified byte-for-byte after upload because gzip output differs across tool versions.
- Release metadata, workflow YAML, and `git diff --check` passed locally. Final hosted CI run `29674789288` passed Windows PowerShell 5.1, PowerShell 7, Ubuntu Bash, and macOS Bash/zsh.
- GitHub release `v2.0.5` is public at https://github.com/GoldenZqqq/cdp/releases/tag/v2.0.5 from commit `85d798216a7561dcd6c1cae1ef29e47af2651f00`.
- PowerShell Gallery remains at v2.0.4 because neither the local environment nor GitHub Actions has `PS_GALLERY_API_KEY`.

## 2.0.4 Stability Checklist

- [x] Fix CLI argument parsing and cross-platform status correctness.
- [x] Add PowerShell and bash/zsh v2 regression suites.
- [x] Select source-install module paths by PowerShell edition and discoverable `PSModulePath` roots.
- [x] Verify source installs against the exact target path and manifest version.
- [x] Update Scoop metadata to 2.0.4 and reuse the root installer.
- [x] Add canonical release-metadata validation to PowerShell 5.1 and 7 CI jobs.
- [x] Pass 58/58 Pester tests under PowerShell 7 and Windows PowerShell 5.1.
- [x] Pass PSScriptAnalyzer Error, Git Bash CLI/status/shared regressions, WSL bash/zsh shared regressions, and shell syntax checks.
- [x] Push the completed v2.0.4 commits, pass remote CI, create the tag and GitHub Release, publish PowerShell Gallery, and verify all public channels.

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
- Release 2.0.4 candidate: repaired pre-tag CI fixture isolation for runner-provided `tmux` and trailing-slash `TMPDIR`, then repeated the complete local validation matrix successfully.
- Release 2.0.4: commit/tag `b85177a234ecaa6a6e5ade42fb73966f29fc1a6a`; main CI run `29558638580` passed all four jobs, and Pages deployment run `29558637771` passed.
- Release 2.0.4: GitHub Release is public/latest at https://github.com/GoldenZqqq/cdp/releases/tag/v2.0.4.
- Release 2.0.4: PowerShell Gallery latest/exact version is 2.0.4 and https://www.powershellgallery.com/packages/cdp/2.0.4 returned HTTP 200.
- Release 2.0.4: tag ZIP metadata, manifest, PowerShell parse, and shell syntax passed; `Save-Module` manifest 2.0.4 was verified under PowerShell 7 and Windows PowerShell 5.1.

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
