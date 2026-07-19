# 增加官网冒烟测试与媒体治理

## Goal

保护官网关键交互、基础可访问性和静态资源完整性，并通过可审计预算停止媒体资产继续放大 CLI 仓库的克隆成本。

## Background

- 官网是 `docs/` 下的无构建静态页面，交互集中在 `docs/script.js`。
- 页面已有语言切换、命令/安装 tabs、复制、移动导航、Escape 关闭、键盘焦点和 reduced-motion 路径，但没有真实浏览器回归。
- `docs/assets` 当前为 `67,433,719` bytes；四个未被官网或 README 引用的旧 demo 文件各约 16 MB，是主要历史债务。
- `docs/assets/cdp-v2-promo.mp4` 与 `videos/cdp-v2-promo/renders/cdp-v2-promo.mp4` 内容相同，属于已知发布物/源产物重复。

## Requirements

- 使用固定版本 Playwright 在 Chromium 无头环境覆盖语言切换、tabs、安装复制、移动导航、Escape、键盘焦点、基础语义和 reduced motion。
- 使用独立 `tests/web` pnpm 包与 lockfile，不把浏览器依赖加入 PowerShell/Shell 发布包。
- 仓库脚本检查 HTML/CSS 本地资源引用、`docs/script.js` 语法、媒体单文件预算、发布目录总预算、仓库媒体总预算、未引用发布资产和未登记重复资产。
- 当前超预算或未引用历史资产必须显式登记为基线豁免；新增媒体默认受更严格限制，超预算、未引用或未登记重复时非零退出。
- CI 使用独立 `web` job 并在失败时保留 Playwright 报告。
- 建立成品/源文件存放规则与旧媒体迁移清单。

## Acceptance Criteria

- [x] `pnpm --dir tests/web test` 在无头 Chromium 通过 `6/6`，覆盖全部关键交互和基础无障碍契约。
- [x] 静态资源与媒体 gate 对当前仓库通过；Node `6/6` 故意失败 fixture 覆盖缺失资源、超预算、未引用、总量增长和未登记重复。
- [x] PR/main CI 使用独立 Web job 分层运行 assets 与 browser gate，并以 `if: always()` 上传浏览器报告。
- [x] 媒体策略记录精确基线、默认新文件预算、允许的历史债务和非破坏迁移顺序。
- [x] 未删除现有媒体、未重写 Git 历史、未改变官网视觉方向。

## Verification Notes

- Playwright `1.61.1` / Chromium: `6/6` passed.
- Node media policy fixtures: `6/6` passed.
- Current media baseline: 12 published / 13 repository media files;
  `67,433,719` / `69,115,162` bytes.
- PowerShell quality gate: Pester `98/98`, coverage `2097/3105`
  (`67.54%`), PSScriptAnalyzer and release metadata passed.
- Scoop package gate: `715777a30af8acd5d3981e0c0f52c8ee2bf7feda27aa4a2f916a95750213b04c`.

## Out of Scope

- 删除、移动或重新编码现有大媒体文件。
- Git LFS / Git 历史重写。
- 官网视觉重设计或引入前端应用框架。
- 全量 WCAG 自动审计替代人工评审。
