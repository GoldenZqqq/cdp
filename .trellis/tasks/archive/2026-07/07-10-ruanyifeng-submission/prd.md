# P3: 阮一峰周刊再投稿

## Goal

向阮一峰科技爱好者周刊提交 cdp v2.0，争取被收录。

## Requirements

### 投稿准备

- 确认所有 P0/P1 功能已发布到 PowerShell Gallery 和 GitHub Releases
- GitHub Stars 争取达到 10+（可通过社交媒体、开发者社区推广）
- README 首屏截图/GIF 需要在 5 秒内抓住注意力

### 投稿内容

在 ruanyf/weekly 仓库提交 issue 或 PR，包含：
- 项目名称和一句话描述
- GitHub 链接
- 核心卖点（`cdp status` 仪表盘 + AI CLI 工作台）
- 截图/GIF

### 投稿定位

**不要说**："一个项目目录切换器"（和 zoxide 同质）
**应该说**："终端里的项目工作台 —— 一条命令看所有仓库状态、模糊切换项目、启动 AI CLI、管理项目 workspace"

### 投稿时机

- 避开重大新闻周（大型发布、节日前后）
- 周一至周三提交（周五发布的周刊通常周三前截稿）

## Dependencies

- 所有 P0-P2 功能完成
- README 重写完成
- 宣传视频制作完成
- GitHub Releases 发布

## Acceptance Criteria

- [ ] cdp v2.0 发布到 PowerShell Gallery
- [ ] GitHub Release 创建（带 changelog）
- [ ] 投稿 issue/PR 提交到 ruanyf/weekly
- [ ] 投稿内容突出 cdp status 仪表盘差异点
