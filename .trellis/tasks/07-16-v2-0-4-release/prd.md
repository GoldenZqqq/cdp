# 准备并发布 v2.0.4

## Goal

在 v2.0.4 其他 5 个子任务完成后执行唯一的版本发布收口。

## Background

- 五个前置叶子任务均已归档并拥有独立 work/archive 提交。
- 2026-07-17 fetch 后 `main...origin/main` 为 `0 behind / 11 ahead`，工作树干净。
- 本地/远端 `v2.0.4` tag、GitHub Release 与 PowerShell Gallery 2.0.4 均不存在。
- GitHub Release 与 PowerShell Gallery 最新公开版本均为 2.0.3。
- `PS_GALLERY_API_KEY` 已存在；只允许检查 PRESENT/MISSING，不打印值。

## Requirements

- 复核全部版本文件、ReleaseNotes、CHANGELOG、PROGRESS、Scoop 和双语 README；以 `cdp.psd1` 为 canonical version。
- 运行仓库 release checklist 中的 PowerShell 5.1/7、Analyzer、shell、whitespace 和新增回归测试。
- 每个前置任务必须已有独立提交；发布准备另有一个提交。
- 发布准备提交前执行 `git pull --rebase --autostash`，只在全部本地验证成功后统一 push main。
- 等待 main CI 成功后，才在 release commit 创建/push annotated `v2.0.4` tag，并核对 tag peeled SHA。
- 只从已核验 tag 创建非 draft、非 prerelease 的 latest GitHub Release，再发布 Gallery 2.0.4。
- 完成远端 tag、Release、Gallery、Scoop archive/source artifact 核验并记录证据；不覆盖真实用户模块。
- 发布后更新 PROGRESS/Trellis 证据并推送 bookkeeping，不移动 release tag，除非发现真正的 release-blocking content fix。

## Out of Scope

- v2.1.0 功能或重构。
- 修改 git 历史、强推 main 或删除旧 tag/Release。
- 在真实用户模块目录执行 Scoop/Install.ps1；artifact verification 使用临时目录与 `Save-Module`。

## Acceptance Criteria

- [x] 5 个前置子任务完成；release candidate 工作树只含 `PROGRESS.md` 与当前 release task artifacts。
- [x] PowerShell 5.1/7 `58/58`、两端 metadata validator、PSScriptAnalyzer、Git Bash/WSL shell、syntax、YAML 与 whitespace 全部通过。
- [ ] 发布提交、push、main CI、annotated tag、GitHub Release、Gallery 按规定顺序成功。
- [ ] tag 指向最终 release commit。
- [ ] GitHub tag archive 可下载并通过 metadata/source artifact 检查；Gallery `Save-Module` 包版本与 manifest 为 2.0.4。
- [ ] PROGRESS 记录公开完成状态，release leaf 与 v2.0.4 parent 均归档，bookkeeping 已 push。
- [ ] 最终报告包含 SHA、tag、Release URL、Gallery URL/版本、CI 结果和非阻塞警告。

## Local Validation Evidence

2026-07-17 已完成 release candidate 独立验证：

- PowerShell 7 Pester：58/58；Windows PowerShell 5.1 Pester：58/58。
- `scripts/Test-ReleaseMetadata.ps1`：PowerShell 7 与 Windows PowerShell 5.1 均通过。
- PSScriptAnalyzer Error severity：0。
- Git Bash：CLI parser、status、shared shell v2 全部通过。
- WSL Arch：bash/zsh shared shell v2 与 bash/zsh syntax 全部通过。
- Scoop JSON 与 workflow YAML 可解析；`git diff --check` 与 Trellis validation 通过。
- `main...origin/main`：0 behind / 11 ahead；release 渠道初始版本均为 2.0.3，2.0.4 尚不存在。
- Gallery key 仅核验为 PRESENT，未读取或输出值。

## Remote Validation Evidence

- 首次 main CI run `29557952851` 在 SHA `36204d2d1c34dacd88e24d7959bfcc7ba98c7148` 暴露两个 pre-tag blocker：Ubuntu runner 的真实 `tmux` 被测试误启动；macOS runner 的尾斜杠 `TMPDIR` 造成逻辑/物理路径比较漂移。
- 两项均发生在 shell fixture 隔离边界，tag/Release/Gallery 尚未创建；按发布状态机先提交最小测试修复并重新运行完整 main CI。
- 首轮 run 最终状态为 failure；PowerShell 7 与 Windows PowerShell 5.1 jobs 成功，Ubuntu 与 macOS shell jobs 失败。
- 修复后已在本地重跑完整 release matrix 并全部通过；新 SHA 的 main CI 仍为下一道发布门禁。
