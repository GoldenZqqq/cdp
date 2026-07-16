# v2.2.0 自动化与多仓库能力

## Goal

在 v2.1.0 安全工程基础上，为脚本、CI 和 AI Agent 提供稳定机器接口，并完善多仓库工作流。

## Requirements

- 先定义机器可读 contract 和跨平台路径模型，再实现批量执行与 workspace 扩展。
- 新功能默认安全、可 dry-run，并同时覆盖 PowerShell 与 shell。
- 所有 schema 变化必须向后兼容并提供迁移/降级说明。

## Acceptance Criteria

- [ ] 6 个子任务完成并各有独立提交。
- [ ] JSON、路径 profile、exec、workspace、frecency 均有跨平台 contract tests。
- [ ] 全量门禁通过后统一发布 v2.2.0。
