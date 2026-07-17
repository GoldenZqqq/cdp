# 安装器与发布元数据一致性实施计划

## Order

- [x] 新增 PowerShell 5.1 兼容的 installation pure functions。
- [x] 改造 `Install.ps1` 使用 edition-aware resolver、`-Force`、`-SkipFzf` 与 exact target verification。
- [x] 更新 Scoop 2.0.4 metadata，并复用根安装器。
- [x] 新增 canonical-version metadata validator。
- [x] 新增 PowerShell 5.1/7 共用 installer/metadata Pester 回归。
- [x] 将 validator 接入两个 Windows CI job。
- [x] 更新 `PROGRESS.md`、CHANGELOG、ReleaseNotes 与双语安装说明。
- [x] 运行定向 Pester 与 validator negative case。
- [x] 运行 PowerShell 5.1/7 full Pester、PSScriptAnalyzer、Shell regressions、bash/zsh syntax、YAML、whitespace 与 Trellis validation。
- [ ] 更新 installer/release metadata code-spec，提交并归档一次；不 push。

## Files

- `scripts/Cdp.Installation.ps1`
- `scripts/Test-ReleaseMetadata.ps1`
- `Install.ps1`
- `scoop/cdp.json`
- `tests/cdp.Install.Tests.ps1`
- `.github/workflows/test.yml`
- `PROGRESS.md`
- `CHANGELOG.md`
- `cdp.psd1`
- `README.md`
- `README_ZH.md`
- `.trellis/spec/backend/quality-guidelines.md`
- 当前 Trellis task artifacts

## Validation

- PowerShell 7 与 Windows PowerShell 5.1：installer/metadata targeted + full Pester。
- 两端独立执行 `scripts/Test-ReleaseMetadata.ps1`。
- PSScriptAnalyzer 检查 `Install.ps1`、`scripts/*.ps1` 与 `src/cdp.psm1` 的 Error severity。
- Git Bash CLI/status/shared tests；WSL bash/zsh syntax 与 shared test。
- workflow YAML parse、`git diff --check` 与 `task.py validate`。

## Risk Controls

- tests 不调用真实 `Install.ps1` 写入用户模块目录，而是测试纯 resolver/selector。
- Scoop 只在 manifest 中改调用入口，本任务不运行真实 Scoop install/uninstall。
- validator 只读仓库文件，不访问网络、不读取 secret。
- release 远程动作全部保留给下一叶子任务。
