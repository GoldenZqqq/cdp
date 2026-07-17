# 补齐 PowerShell v2 回归测试

## Goal

为 v2.0 已发布但缺少验证的 PowerShell 行为建立可重复的 Pester 回归网。

## Background

- 当前 PowerShell 5.1/7 共用 38 个 Pester 用例。
- 本任务开始时 `src/cdp.psm1` 命令覆盖率为 55.90%（1185/2120），已高于路线建立时记录的 47.04%，但 workspace、onEnter 与 argument completer 仍缺少行为级断言。
- 现有 `tests/cdp.Tests.ps1` 已接近千行；新增 v2 场景使用独立测试文件，不继续扩大该文件。

## Requirements

- 覆盖 status 数据收集、过滤和动作选择。
- 覆盖 workspace add/list/launch dry-run、缺失项目与路径空格。
- 覆盖 onEnter env、PowerShell hook 和失败隔离，不执行不可信外部命令。
- 覆盖 argument completer 的子命令、项目和 launcher。
- 所有测试隔离 `$TestDrive`、环境变量、当前目录和模块缓存。

## Technical Notes

- status Git fixture 只使用 `$TestDrive` 与本地 bare remote，不访问网络。
- workspace 启动使用 Pester mock 验证 `wt.exe` 参数，不启动真实 Windows Terminal。
- onEnter 只执行受控的环境赋值或预期异常脚本，不启动外部命令。
- completion 通过 `TabExpansion2` 验证已注册 completer，并用临时 `CDP_CONFIG` 提供项目名。
- 若测试暴露生产缺陷，只做完成本验收所需的最小修复，并补失败用例。

## Out of Scope

- v2.1.0 的 onEnter 信任/确认模型。
- PowerShell 模块拆分与公共 API 重构。
- bash/zsh 回归测试；由相邻叶子任务独立完成。

## Acceptance Criteria

- [x] PowerShell 5.1 与 7 运行相同测试集且全部通过。
- [x] status、workspace、onEnter 与 completer 均有成功、边界或失败路径断言。
- [x] 新增测试不会依赖真实用户配置、网络、Windows Terminal 或已安装 AI CLI。
- [x] 命令覆盖率高于本任务基线 55.90%，并记录 executed/analyzed 证据。

## Verification

- PowerShell 7：48 passed、0 failed。
- Windows PowerShell 5.1：48 passed、0 failed。
- Pester command coverage：63.67%（1353/2125），较任务基线 55.90% 提升 7.77 个百分点。
- 新增 10 个 v2 行为用例在两种 PowerShell 中均为 10/10。
- PSScriptAnalyzer `Severity Error`：0 findings。
- Git Bash：CLI parser 与 status regression tests 均通过。
- WSL Arch：`bash -n src/cdp.sh` 与 `zsh -n src/cdp.sh` 均通过。
- `git diff --check` 与 Trellis task validation 均通过。
- 首次并行执行两个默认 `-CI` Pester 进程时争用 `testResults.xml`；改为独立无共享报告运行后 PS7 48/48，通过结果与该编排问题已分别验证。
