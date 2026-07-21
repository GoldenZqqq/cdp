# v2.2.0 自动化与多仓库能力

## Goal

在 v2.1.0 安全工程基础上，为脚本、CI 和 AI Agent 提供稳定机器接口，并完善多仓库工作流。

## Requirements

- 先定义机器可读 contract 和跨平台路径模型，再实现批量执行与 workspace 扩展。
- 新功能默认安全、可 dry-run，并同时覆盖 PowerShell 与 shell。
- 所有 schema 变化必须向后兼容并提供迁移/降级说明。

## Acceptance Criteria

- [x] 6 个子任务完成并各有独立提交。
- [x] JSON、路径 profile、exec、workspace、frecency 均有跨平台 contract tests。
- [x] 全量门禁通过后统一发布 v2.2.0。

## Completion Evidence

- 五个功能任务和 release 任务均有独立提交与验收证据。
- Release commit `b2a1e7b` 的 CI run `29800666822` 五项全部成功。
- Annotated tag、GitHub Release、Scoop 资产和远程 shell 安装均已验证；
  PowerShell Gallery 因缺少外部 API key 停留在 v2.0.4，未虚报发布。
