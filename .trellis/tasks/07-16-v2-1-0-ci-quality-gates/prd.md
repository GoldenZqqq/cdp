# 强化 CI 与质量门禁

## Goal

让跨平台行为、覆盖率、安装、元数据和发布契约的回归在合并前自动失败。

## Requirements

- 加入 ShellCheck、覆盖率报告/阈值、安装器 smoke、版本同步和 package 内容检查。
- 关键测试矩阵覆盖 PowerShell 5.1/7、Ubuntu bash、macOS zsh。
- CI 逻辑调用仓库脚本，避免 workflow 内重复业务断言。
- 固定关键 action/tool 主版本并控制执行时间。

## Acceptance Criteria

- [x] 每个新增门禁有故意失败验证记录：coverage threshold、Scoop hash，以及既有 metadata/installer drift fixtures 均验证非零退出。
- [x] main 与 PR CI 通过仓库脚本输出分层阶段，PowerShell 质量报告上传为 artifact；每个 job 有 20 分钟超时。
- [x] 本地 PowerShell 7.5.2/Pester 5.7.1 `98/98`、coverage `67.54%`、ScriptAnalyzer、Bash/zsh/Bash 3.2、ShellCheck、package、YAML/JSON 和 Trellis 门禁通过。

## Verification Notes

- Quality gate: Pester `98/98`; coverage `2097/3105` (`67.54%`) against `60%`.
- Negative coverage run with `-CoverageThreshold 100` exited `1` and reported the expected/actual counts.
- Scoop package gate accepted `b776dd0d45feea8e3987d4be6afb6ef9f5dbcfcaa795ad90c69e5e5260cb68f6` and rejected a zero hash.
- Windows PowerShell 5.1 remains a hosted CI validation because the current host is Linux arm64.
