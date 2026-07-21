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

Latest verified GitHub release: v2.2.0 (verified 2026-07-21). Latest verified PowerShell Gallery release: v2.0.4.

Current release target: v2.2.0.

Release status: v2.2.0 passed the complete local and hosted matrices and is published as the latest GitHub Release. Its retained, GitHub, and Scoop archives match byte-for-byte, and the tag-pinned shell installer passed a public download smoke. PowerShell Gallery remains at v2.0.4 because neither the local environment nor repository Actions secrets contain `PS_GALLERY_API_KEY`; this is the only external v2.2.0 blocker.

## 2.2.0 Automation and Multi-Repository Checklist

- [x] Define status JSON schema version 1, stable attention/error codes, and automation exit codes.
- [x] Add PowerShell and bash/zsh `--json` / `-Json` plus ANSI-free `--no-color` / `-NoColor` output.
- [x] Add cross-runtime JSON, parser, stdout/stderr, exit-code, and no-color regressions.
- [x] Add cross-platform path profiles.
- [x] Add workspace lifecycle operations.
- [x] Add safe multi-repository exec.
- [x] Add frecency ranking.
- [x] Complete and publish v2.2.0, with the missing Gallery credential recorded as the only external blocker.

Status JSON verification: the PowerShell 7.5.2 quality gate passed Pester `104/104`, command coverage `2311/3344` (`69.11%`), PSScriptAnalyzer, and release metadata. bash, zsh, and the fixed Bash 3.2 container passed the shared schema fixture plus existing status/safety/persistence regressions.

Path profile verification: PowerShell 7.5.2 passed Pester `117/117`, command coverage `2529/3604` (`70.17%`), PSScriptAnalyzer, and release metadata. One shared fixture covers Windows, WSL, Linux, and macOS resolution, legacy fallback, WSL conversion, invalid overrides/mappings, raw/resolved status identity, safe fix/repair behavior, and add/scan-compatible writes. bash, zsh, and the fixed Bash 3.2 container passed the path contract plus the existing CLI/status/safety/persistence matrices. After workspace lifecycle integration, the generated shell SHA-256 is `33fbf6c5b2e0cf003943269b715c34c6e9a24276b023360ea82fce261cce514b`; the current deterministic Scoop draft SHA-256 is `b1dc4e5925e66f5180c978d7f3c1f9035fe793d901adc341d81ec9c28996e771`.

Workspace lifecycle verification: PowerShell and shell now share stable raw-path references, legacy migration, rename/delete/name-reuse diagnostics, unknown-field preservation, no-op fix behavior, launcher precedence, tabs/split layouts, exact WT/tmux argv, partial failure, dry-run, and completion contracts. The full PowerShell 7.5.2 gate passed `129/129` with `72.30%` command coverage (`3088/4271`) and no PSScriptAnalyzer errors. bash, zsh, and the fixed Bash 3.2 image passed lifecycle, CLI, status JSON, path-profile, safe-mutation, shell-v2, persistence, modularization, ShellCheck, documentation, installer, and deterministic Scoop gates. Generated shell SHA-256: `33fbf6c5b2e0cf003943269b715c34c6e9a24276b023360ea82fce261cce514b`; Scoop draft SHA-256: `b1dc4e5925e66f5180c978d7f3c1f9035fe793d901adc341d81ec9c28996e771`.

Multi-repository exec verification: PowerShell, bash, zsh, and Bash 3.2 cover explicit/tag/workspace/`--all` selection, exact raw-identity deduplication, path-profile and stable-reference failures, mandatory `--` argv isolation, bounded workers, timeouts, continue/fail-fast cancellation, dry-run/approval safety, deterministic human/JSON output, and exit codes 0-3. The full PowerShell 7.5.2 gate passed `146/146` with `73.49%` command coverage (`3629/4938`) and no PSScriptAnalyzer errors. Bash, zsh, and the fixed Bash 3.2 matrix passed exec plus the existing modularization, CLI, status, path-profile, workspace, safety, shell-v2, and persistence suites. Generated shell SHA-256: `8a42caa197e3ca54d8c827b4847447d2526b45b03961630e4e4efd38c5af83e2`; deterministic Scoop draft SHA-256: `1124cbd3da5a75f021fde969174d94ac22467eb53bcd0b32708e2eafb9ad6b08`.

Frecency verification: one fixed-time fixture now covers pin groups, integer frequency/decay, future and invalid timestamps, visit-count clamping, duplicate history, exact raw-path identity, opt-out fallback, and original config order across PowerShell, bash, zsh, and Bash 3.2. `cdp recent reset` also covers preview/approval, unknown-field preservation, invalid-state refusal, and empty no-op behavior. The full PowerShell 7.5.2 gate passed `156/156` with `73.98%` command coverage (`3795/5130`) and no PSScriptAnalyzer errors. ShellCheck, documentation, installer, deterministic package, release metadata, and affected shell regressions passed. Generated shell SHA-256: `ada96effe4b5b23b49530d8576898a369f60dcf6eb9d67821b1d5ef7cb80d463`; deterministic Scoop draft SHA-256: `87130587dd8028666e84f0e0beb9726374c2767c43f65222bf787323430c5e9a`.

## 2.2.0 Release Verification

- Archived work commits: status JSON `a0a7c396` / `5dfa68db`, path profiles `03f7af48` / `11329579`, workspace lifecycle `52596c5e` / `b60f339c`, multi-repository exec `11b5435a` / `7e9debed`, and frecency ranking `99655214` / `4c87850b`.
- Final hosted CI run `29800666822` for release commit `b2a1e7beb44d13fa07079f77812233ec60df854c` passed all five jobs, including Windows PowerShell 5.1, PowerShell 7, Bash, macOS Bash/zsh, and Web smoke.
- Local ARM64 PowerShell 7.5.0 container passed Pester `156/156`, command coverage `3795/5130` (`73.98%`), PSScriptAnalyzer with no Error findings, and release metadata.
- Local bash/zsh, fixed Bash 3.2, ShellCheck, installer, documentation, Web/Chromium, quality, persistence, safety, contract, performance, and package gates passed.
- Status benchmark on 50 repositories: jobs=4 min/median/p95 `2.967/3.076/3.536s`; jobs=8 `2.852/2.994/3.486s`.
- Annotated tag `v2.2.0` peels to the release commit; https://github.com/GoldenZqqq/cdp/releases/tag/v2.2.0 is public, latest, non-draft, and non-prerelease.
- Retained, public GitHub, and Scoop `cdp-2.2.0.tar.gz` archives are each `141,245` bytes with 54 entries and SHA-256 `87130587dd8028666e84f0e0beb9726374c2767c43f65222bf787323430c5e9a`; an independent second build also matched byte-for-byte.
- Temporary HOME local and tag-pinned remote shell installations plus an isolated PowerShell package installation all discovered v2.2.0 successfully.
- Gallery verification enumerated the official feed, which still ends at v2.0.4. The versioned package endpoint redirects a missing v2.2.0 request to `cdp.2.0.4.nupkg`, so HTTP 200 alone was rejected as false evidence. No local or Actions API key is available for publication.

## 2.1.0 Engineering Foundation Checklist

- [x] Route cdp-owned JSON mutations through atomic persistence boundaries in PowerShell and shell.
- [x] Reject stale writes with SHA-256 fingerprints and sibling locks.
- [x] Retain three bounded backups and expose explicit recovery helpers.
- [x] Diagnose valid backups when the active project config is damaged.
- [x] Bind persistent command-hook trust to config, project, and command fingerprints without storing command text.
- [x] Add PowerShell ShouldProcess/WhatIf/Confirm and shell dry-run/yes safety boundaries to mutating commands.
- [x] Return or print per-target action results and continue safe batch processing after item failures.
- [x] Split the PowerShell module into bounded domain files with a stable bootstrap, export surface, and recursive package coverage.
- [x] Split bash/zsh source into bounded domain fragments with deterministic single-file generation and offline-install verification.
- [x] Replace per-repository status probes with porcelain-v2 collection, bounded concurrency, timeouts, optional TTL cache, refresh controls, and fixed-size benchmarks.
- [x] Add status performance regressions and Bash/zsh/Bash 3.2 CI coverage.
- [x] Synchronize status performance behavior, options, and environment settings in both README files and release metadata.
- [x] Centralize PowerShell coverage/analyzer/metadata and Scoop package integrity gates in repository scripts with deliberate failure fixtures.
- [x] Pin CI test-tool versions and Bash 3.2 image digest; add per-job timeouts and PowerShell report artifacts.
- [x] Add pinned Chromium smoke for website interaction, keyboard, accessibility semantics, and reduced motion.
- [x] Enforce local-resource integrity and exact media-growth budgets without deleting legacy assets.
- [x] Replace placeholder Trellis specs and refresh bilingual README, architecture, contribution, and agent guidance.
- [x] Add automated bilingual structure, manifest command coverage, placeholder, and stale-guidance documentation checks.
- [x] Complete the remaining v2.1.0 release task with the Gallery credential blocker recorded.
- [x] Pass the full cross-platform release gate and publish/verify GitHub and Scoop.
- [ ] Publish and verify PowerShell Gallery v2.1.0 when an API key is available.

## 2.1.0 Engineering Verification

- PowerShell 7.5.2: Pester `88/88`; PSScriptAnalyzer Error severity reported no findings across `src`.
- PowerShell modularization: all `119/119` function bodies match the pre-split AST text; the largest domain file is 557 lines.
- Bash, zsh, and Bash 3.2: persistence, stale-fingerprint, invalid JSON, lock,
  flush/replacement failure, backup recovery, doctor diagnostics, and syntax checks passed.
- Shell installer digest: `25ab6256178bb1322a32e59b062820cfc87a349ea2c7fc4e679d4630c2775e47`.
- Deterministic Scoop package digest: `07e2b39dfdc77361b6abd0fe67f1bf2ad923deb7e81ce5a081b62755f71bb74c`.
- Status performance work: Bash 50-repository benchmark on this workspace measured jobs=4 in 5 runs at min `2.007s`, median `2.083s`, p95 `2.246s`; jobs=8 measured min `1.912s`, median `2.082s`, p95 `2.198s`. PowerShell 7.5.2 with one worker measured min `1.941s`, median `2.209s`, p95 `2.917s`.
- Status correctness: Bash status performance tests, Bash/zsh v2 regressions, zsh persistence, and Bash 3.2 container smoke passed after the zsh default-concurrency compatibility fix. An isolated official PowerShell 7.5.2 arm64 runtime passed Pester `95/95` and PSScriptAnalyzer Error severity; Windows PowerShell 5.1 remains a hosted-CI-only gate on this Linux environment.
- CI quality gate baseline: PowerShell 7.5.2 with Pester 5.7.1 passed `98/98`; command coverage is `67.54%` (`2097/3105`) against a 60% threshold. Coverage, package hash, release metadata, and shell installer deliberate-drift fixtures all fail with layer-specific diagnostics.
- Website quality: Playwright 1.61.1 Chromium smoke passed `6/6`; Node media fixtures passed `6/6`. The current gate records 12 published and 13 repository media files at `67,433,719` / `69,115,162` bytes and rejects missing resources, new over-budget or unreferenced media, total growth, and unregistered duplicates.
- Documentation quality: Node fixtures passed `5/5`; the current gate validates 39 exported PowerShell functions/aliases across both maintained READMEs and 13 source-backed backend/frontend specs with no template placeholders or stale architecture/commit guidance.
- Release candidate: all nine engineering child tasks are archived and their work commits resolve. The retained `cdp-2.1.0.tar.gz` is `91,067` bytes with SHA-256 `07e2b39dfdc77361b6abd0fe67f1bf2ad923deb7e81ce5a081b62755f71bb74c`, matching Scoop.
- Release benchmark rerun: Bash jobs=4 measured min `1.401s`, median `1.443s`, p95 `1.575s`; jobs=8 measured min `1.324s`, median `1.370s`, p95 `1.505s`. PowerShell 7.5.2 workers=4 measured min `0.630s`, median `0.732s`, p95 `1.012s`.
- Hosted release CI: run `29703151619` passed all five jobs after adding fresh-checkout CRLF parsing and caller-umask package determinism regressions.
- Pages deployment run `29703151069` passed for the same release commit.
- Published release: annotated tag `v2.1.0` points to `f000538f995804adba785f8a3d68413dd90e9431`; https://github.com/GoldenZqqq/cdp/releases/tag/v2.1.0 is public/latest.
- Public asset verification: GitHub Release and Scoop downloads both returned SHA-256 `07e2b39dfdc77361b6abd0fe67f1bf2ad923deb7e81ce5a081b62755f71bb74c`.
- Gallery blocker: `PS_GALLERY_API_KEY` is missing and the official Gallery feed still ends at v2.0.4; v2.1.0 was not falsely reported as published there.

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
