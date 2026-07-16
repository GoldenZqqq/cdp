# 补齐 PowerShell v2 回归测试

## Goal

为 v2.0 已发布但缺少验证的 PowerShell 行为建立可重复的 Pester 回归网。

## Requirements

- 覆盖 status 数据收集、过滤和动作选择。
- 覆盖 workspace add/list/launch dry-run、缺失项目与路径空格。
- 覆盖 onEnter env、PowerShell hook 和失败隔离，不执行不可信外部命令。
- 覆盖 argument completer 的子命令、项目和 launcher。
- 所有测试隔离 `$TestDrive`、环境变量、当前目录和模块缓存。

## Acceptance Criteria

- [ ] PowerShell 5.1 与 7 运行相同测试集且全部通过。
- [ ] v2 核心函数不再只有 smoke 覆盖。
- [ ] 新增测试不会依赖真实用户配置、网络、Windows Terminal 或已安装 AI CLI。
- [ ] 代码覆盖率相较 47.04% 有可解释提升，关键分支有断言。
