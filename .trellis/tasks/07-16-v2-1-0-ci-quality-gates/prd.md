# 强化 CI 与质量门禁

## Goal

让跨平台行为、覆盖率、安装、元数据和发布契约的回归在合并前自动失败。

## Requirements

- 加入 ShellCheck、覆盖率报告/阈值、安装器 smoke、版本同步和 package 内容检查。
- 关键测试矩阵覆盖 PowerShell 5.1/7、Ubuntu bash、macOS zsh。
- CI 逻辑调用仓库脚本，避免 workflow 内重复业务断言。
- 固定关键 action/tool 主版本并控制执行时间。

## Acceptance Criteria

- [ ] 每个新增门禁有故意失败验证记录。
- [ ] main 与 PR CI 输出清晰的分层失败原因。
- [ ] 正常完整 CI 在可接受时间内通过。
