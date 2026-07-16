# 准备并发布 v2.0.4

## Goal

在 v2.0.4 其他 5 个子任务完成后执行唯一的版本发布收口。

## Requirements

- 更新全部版本文件、ReleaseNotes、CHANGELOG、PROGRESS、Scoop 和双语 README。
- 运行仓库 release checklist 中的 PowerShell 5.1/7、Analyzer、shell、whitespace 和新增回归测试。
- 每个前置任务必须已有独立提交；发布准备另有一个提交。
- 仅在全部验证成功后统一 push main，等待 CI，再创建 tag、GitHub Release 和 Gallery 包。
- 完成远端 tag、Release、Gallery、Scoop/安装核验并记录证据。

## Acceptance Criteria

- [ ] 5 个前置子任务完成且工作树仅含发布改动。
- [ ] 发布提交、push、main CI、annotated tag、GitHub Release、Gallery 依次成功。
- [ ] tag 指向最终 release commit。
- [ ] 最终报告包含 SHA、tag、Release URL、Gallery URL/版本、CI 结果和非阻塞警告。
