# v2.0.4 发布实施计划

## Order

- [x] 1. 核对五个前置任务归档、工作树、origin divergence、tag/Release/Gallery/key 状态。
- [x] 2. 运行 `git pull --rebase --autostash`，确认无 behind/冲突。
- [x] 3. 执行完整本地 release validation matrix。
- [x] 4. 更新 PROGRESS release-candidate 状态与 task 证据，提交 `chore: 准备 2.0.4 发布`。
- [ ] 5. `git push origin main`，等待并记录 release SHA 对应 main CI。
- [ ] 6. 创建/push annotated `v2.0.4`，核对三处 SHA。
- [ ] 7. 从 tag 创建 latest GitHub Release 并核对公开属性。
- [ ] 8. 使用环境 key 发布 PowerShell Gallery，等待 indexing 并核对 exact version/page。
- [ ] 9. 下载/验证 tag archive；`Save-Module` 验证 Gallery artifact；核对 Scoop metadata/URL。
- [ ] 10. 更新 PROGRESS 与 PRD 发布证据，提交/推送 bookkeeping；归档 release child 与 v2.0.4 parent。
- [ ] 11. 输出发布完成报告并进入 v2.1.0 第一个叶子任务。

## Release Notes

GitHub Release notes 从 `CHANGELOG.md` 2.0.4 段生成，聚焦：

- CLI 参数顺序与 workspace token 修复；
- linked worktree/status/`--fix`/push 正确性；
- PowerShell 与 bash/zsh v2 回归覆盖；
- launcher/workspace/scan/zsh compatibility 修复；
- edition-aware installer、Scoop 2.0.4 与 canonical metadata validator。

## Validation Commands

- PowerShell 7/5.1 full Pester + metadata validator（串行 Pester）。
- PSScriptAnalyzer Error。
- Git Bash CLI/status/shared；WSL bash/zsh shared + syntax。
- JSON/YAML、metadata、whitespace、Trellis。
- `gh run watch <id> --exit-status`。
- `git rev-parse HEAD`、`git rev-parse 'v2.0.4^{}'`、`git ls-remote --tags origin v2.0.4`。
- `gh release view`、`Find-Module -RequiredVersion 2.0.4`、Gallery page HTTP、tag archive/source、`Save-Module`。

## Risk Controls

- 不打印 Gallery key，不在命令中展开 key 值。
- 不并行运行两个默认 `Invoke-Pester -CI`。
- 不在 CI green 前打 tag，不在 tag verified 前创建 Release/Gallery。
- 不用 destructive git，不强推 main，不执行真实用户目录安装。
- 任一渠道失败立即停在该阶段并保留已成功状态供重试。

## Spec Review

Phase 3.3 复核无需新增 code-spec：本任务执行的 canonical version、双端 metadata validation、发布顺序与 artifact verification 约束，已由 `.trellis/spec/backend/quality-guidelines.md` 的 release scenario 和仓库 `AGENTS.md` 覆盖；本任务未引入新的代码契约或非显然陷阱。
