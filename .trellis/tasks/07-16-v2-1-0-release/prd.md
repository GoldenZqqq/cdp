# 准备并发布 v2.1.0

## Goal

在 9 个工程子任务全部完成后发布 v2.1.0。

## Requirements

- 更新全部版本、迁移说明、ReleaseNotes、CHANGELOG、Scoop 和双语文档。
- 完整运行新增 CI/基准/安装/官网门禁。
- 统一 push 后等待 main CI，再 tag、GitHub Release、Gallery 与渠道核验。

## Acceptance Criteria

- [ ] 所有前置子任务各有提交且验收通过。
- [ ] 发布 SHA、tag、Release、Gallery、Scoop、CI 证据完整。
- [ ] 安装升级不破坏 PowerShell 5.1/7 与 shell 用户。
