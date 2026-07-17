# cdp 全面优化与版本演进路线

## Goal

把 cdp 从功能快速扩张后的 v2.0.3 状态，分阶段推进为可稳定安装、可安全扩展、可被脚本与 AI Agent 使用的终端项目工作台。

## Requirements

- 路线固定为 `v2.0.4 -> v2.1.0 -> v2.2.0`，版本任务必须按顺序完成。
- 每个叶子任务必须独立规划、验证和提交；一个提交只承载该任务直接相关的改动。
- 每个版本里程碑内所有叶子任务完成后，才允许统一 push、tag 和发布。
- 每个公开版本必须同步 GitHub Release、PowerShell Gallery、Scoop、双语 README、CHANGELOG 和版本元数据。
- PowerShell 5.1/7、bash、zsh、Windows、WSL/Linux、macOS 的既有兼容性不得被静默破坏。
- 共享 contract、配置 schema、根级 CI、依赖与发布操作只在对应任务中串行修改。

## Task Map

- `v2.0.4`：安装与元数据、CLI 解析、status 正确性、PowerShell/shell 回归测试、发布。
- `v2.1.0`：模块化、原子写入、安全动作、hook 信任、status 性能、CI、官网媒体与规范文档、发布。
- `v2.2.0`：机器输出、跨平台路径 profile、多仓库执行、workspace 生命周期、frecency、发布。

## Acceptance Criteria

- [ ] 26 个 Trellis 任务均有明确范围、验收标准和父子关系。
- [x] v2.0.4 的全部子任务独立提交并完成发布核验。
- [ ] v2.1.0 的全部子任务独立提交并完成发布核验。
- [ ] v2.2.0 的全部子任务独立提交并完成发布核验。
- [ ] 最终全量验证覆盖 PowerShell 5.1/7、bash、zsh、CI、文档和发布渠道。

## Out of Scope

- 未经单独确认不重写 Git 历史。
- 不在版本中途 push 半成品或创建公开 tag。
