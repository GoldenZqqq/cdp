# 实现配置原子写入与并发保护

## Goal

避免 projects、state 和 workspaces JSON 在中断或多终端并发写入时损坏或静默覆盖。

## Requirements

- 所有 JSON 写操作走统一持久化层：同目录临时文件、flush、原子替换、失败清理。
- 变更前保留有限备份，并支持可诊断恢复。
- 使用修改时间/内容指纹检测并发更新，冲突时拒绝覆盖。
- PowerShell 与 shell 语义一致。

## Acceptance Criteria

- [ ] 中断、无权限、无效 JSON、并发修改测试不会损坏原文件。
- [ ] 所有已知直接 `Out-File`/重定向配置写入迁移到统一入口。
- [ ] 成功写入后缓存正确失效，备份数量有上限。
