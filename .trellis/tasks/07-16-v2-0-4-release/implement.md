# v2.0.4 发布实施计划

## Order

- [x] 1. 核对五个前置任务归档、工作树、origin divergence、tag/Release/Gallery/key 状态。
- [x] 2. 运行 `git pull --rebase --autostash`，确认无 behind/冲突。
- [x] 3. 执行完整本地 release validation matrix。
- [x] 4. 更新 PROGRESS release-candidate 状态与 task 证据，提交 `chore: 准备 2.0.4 发布`。
- [x] 5. `git push origin main`，等待并记录 release SHA 对应 main CI。
- [x] 6. 创建/push annotated `v2.0.4`，核对三处 SHA。
- [x] 7. 从 tag 创建 latest GitHub Release 并核对公开属性。
- [x] 8. 使用环境 key 发布 PowerShell Gallery，等待 indexing 并核对 exact version/page。
- [x] 9. 下载/验证 tag archive；`Save-Module` 验证 Gallery artifact；核对 Scoop metadata/URL。
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

首次 main CI 暴露两项 runner-specific fixture 陷阱，已补入 `.trellis/spec/backend/quality-guidelines.md`：测试必须规范化带尾斜杠的 `TMPDIR`，且任何 workspace 调用都必须 shadow 预装的真实 `tmux`。canonical version、发布顺序与 artifact verification 仍由既有 release scenario 和仓库 `AGENTS.md` 覆盖。

## Main CI Attempt 1

- Run: `29557952851`，release candidate SHA `36204d2d1c34dacd88e24d7959bfcc7ba98c7148`。
- Run 最终为 failure：PowerShell 7 与 Windows PowerShell 5.1 jobs 通过，Ubuntu 与 macOS shell jobs 失败。
- Ubuntu status suite 命中 runner 预装的真实 `tmux`，在无交互终端 attach 失败并留下 server。
- macOS zsh v2 suite 因 `$TMPDIR` 带尾斜杠，fixture expected path 含 `//`，实际物理路径为 `/`。
- 两项均为测试隔离/路径规范化缺陷；tag 尚未创建。修复后追加 release-blocking commit、重新 push 并等待新 SHA 的完整 CI。
- 修复后本地完整矩阵再次通过：PowerShell 7/5.1 各 58/58、两端 metadata validator、Analyzer、Git Bash CLI/status/bash v2、WSL bash/zsh v2、syntax、JSON/YAML、Trellis 与 whitespace。

## Main CI Attempt 2 and Publication

- Final release SHA: `b85177a234ecaa6a6e5ade42fb73966f29fc1a6a`。
- CI run `29558638580` 与 Pages run `29558637771` 全部 success。
- Annotated `v2.0.4` 的 HEAD/local peeled/remote peeled SHA 三处一致。
- GitHub Release：https://github.com/GoldenZqqq/cdp/releases/tag/v2.0.4，公开且 latest。
- Gallery：https://www.powershellgallery.com/packages/cdp/2.0.4，latest/exact 2.0.4，HTTP 200。
- Tag archive 与 Gallery `Save-Module` 制品核验通过；未执行真实用户模块目录安装。
- 非阻塞 warnings：Node 20 action runtime、Homebrew tap trust、Gallery `licenseUrl` deprecation。
