# 实施计划：Gallery 与本地安全语义收口

## Ordered steps

1. 校验当前 `main`、v2.2.0 tag/release、Gallery exact package 和工作区状态。
2. 完成并验证 manifest ReleaseNotes 长度门禁与 Gallery publisher native exit-code 修复。
3. 从 `archive/local-status-remote-semantics-48d5dfd` 提取设计、字段、测试矩阵，映射到当前 status modules；先落 focused tests，再实现缺失逻辑。
4. 迁移 PowerShell fetch scheduler、shell bounded fetch worker、sync refresh 和 frozen push plan；保持现有 status JSON v1 与 action result contract。
5. 从 `archive/local-launcher-safety-dbedad5` 迁移安全回归测试，审计当前 PowerShell workspace launch plan 和 shell launcher；仅补足失败路径。
6. 运行 focused tests、双 PowerShell edition Pester、Git Bash/WSL bash+zsh、bundle `--check`、PSScriptAnalyzer、metadata/release gates、Trellis validation 和 `git diff --check`。
7. 按仓库 release gate 将新功能准备为 v2.3.0 本地候选，更新任务验证证据、必要 backend spec 与双语 README；不发布、不打 tag、不 push。
8. 在用户确认的情况下提交；提交前确认新主干已吸收候选需求，再删除旧 backup/archive refs、stash 和 bundle。

## Validation commands

```powershell
pwsh -NoLogo -NoProfile -Command 'Import-Module Pester -MinimumVersion 5.5.0 -Force; Invoke-Pester -Path ./tests -CI'
powershell -NoLogo -NoProfile -Command 'Import-Module Pester -MinimumVersion 5.5.0 -Force; Invoke-Pester -Path ./tests -CI'
pwsh -NoLogo -NoProfile -Command '$r = Invoke-ScriptAnalyzer -Path ./src/cdp.psm1 -Severity Error; if ($r) { throw "PSScriptAnalyzer errors" }'
wsl -d Arch -- bash -lc 'cd /mnt/c/Learn/cdp && bash -n ./src/cdp.sh && bash -n ./install-wsl.sh'
git diff --check
python ./.trellis/scripts/task.py validate
```

## Risk controls

- Do not cherry-pick old commits wholesale; keep old refs until focused tests pass on current main.
- Do not run real push/fetch in tests; use local fixtures and fake native executables.
- Never print API keys or raw remote stderr containing credentials.
- Do not delete backup refs until `git status --short`, stash inventory, archive refs, and test evidence are recorded.

## Verification evidence (2026-07-21)

- Release: `Find-Module -RequiredVersion 2.2.0` returned `cdp 2.2.0`; the Gallery
  exact page returned HTTP 200. GitHub Release `v2.2.0` is public, latest,
  non-draft, and non-prerelease. `HEAD`, `main`, and `origin/main` are
  `b02cc7862996dde6f622fe586aa9657819bb1703`.
- PowerShell 7.6.1: Pester `174/174`, coverage `4079/5466` (`74.62%`),
  PSScriptAnalyzer Error severity clean, and release metadata consistent.
- Shell: bash `16/16` suites and zsh `9/9` applicable suites passed, including
  `cdp.StatusRemote.Tests.sh` and `cdp.LauncherSafety.Tests.sh`. Bundle check,
  bash/zsh syntax, ShellCheck 0.10.0, and deterministic Scoop packaging passed.
- Web/docs: asset/document tests `11/11`, Playwright Chromium `7/7`, and the
  standalone documentation gate passed. The clipboard regression normalizes
  Windows CRLF and browser LF before comparing equivalent command text.
- Windows PowerShell 5.1: a `pwsh` compatibility session passed launcher safety
  `6/6` and status remote `9/11`. The two local-file fetch-success cases timed
  out only through the remoting host; the earlier native 5.1 full matrix passed
  `167/167` before the final deferred-error and dependency-order fixes. Native
  5.1 hosted CI remains required before any v2.3.0 release.
- Artifacts: generated shell SHA-256
  `fb5ab36c0715a2994e2682bdb77e677a8e4a4c2ec558884061ac5d7d26dc6849`;
  deterministic Scoop package SHA-256
  `49e73fa752df91f32b601e1e6999fc7e6d737873fd0709389c74c5197dda6769`.
- Repository checks: Trellis task validation and `git diff --check` passed after
  temporary validation artifacts were removed.

## Remaining boundary

- Add the two new shell suites to `.github/workflows/test.yml` only after user
  confirmation because CI is a protected root-level contract.
- Commit only after user confirmation. Do not push, tag, or publish v2.3.0.
- After the commit leaves the worktree clean, delete the audited backup/archive
  refs, `stash@{0}`, and `C:\Learn\cdp-before-reconciliation-20260721.bundle`.
