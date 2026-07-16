# 为变更性命令增加安全确认

## Goal

让批量删除、修复、push 和配置修改可预览、可取消、可审计。

## Requirements

- PowerShell 变更函数支持 `ShouldProcess`、`-WhatIf`、`-Confirm`。
- shell 对等命令支持 `--dry-run` 与显式 `--yes`。
- `status` 默认保持只读；批量 push 必须展示仓库、remote/upstream 和计划。
- 返回结构化逐项结果与明确失败状态。

## Acceptance Criteria

- [ ] dry-run/WhatIf 不修改文件、不 push、不启动外部工作区。
- [ ] 非交互环境未显式确认时不执行高影响动作。
- [ ] 部分失败不会掩盖其他项目结果，并产生非零退出或失败对象。
