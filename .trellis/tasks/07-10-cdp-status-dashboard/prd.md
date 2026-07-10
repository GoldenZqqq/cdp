# P0: cdp status - 多项目 Git 状态仪表盘

## Goal

实现 `cdp status` 命令，一次性展示所有已配置项目的 Git 状态。这是 cdp 与 zoxide/autojump 拉开差距的**杀手级功能**——zoxide 只知道路径，cdp 知道项目的完整状态。

## Why This Matters

每个管理 10+ 仓库的开发者都有这个痛点：
- "我哪个仓库有没提交的代码？"
- "哪个仓库落后远程了？"
- "我在哪个分支上？"

目前没有轻量级 CLI 工具能一条命令回答这些问题。

## Requirements

### 核心功能

- `cdp status` 遍历所有 enabled 项目，显示每个项目的 Git 状态
- 显示列：序号、项目名、当前分支、工作区状态（clean/dirty/untracked）、落后远程几个 commit、最后 commit 时间
- 用颜色区分状态：green=clean, red=dirty, yellow=untracked
- 底部汇总行："X repos need attention"
- 非 Git 仓库或路径不存在的项目用灰色标记 "not a git repo" / "path missing"

### 过滤参数

- `cdp status` — 显示所有项目
- `cdp status --dirty` / `cdp status -d` — 只显示有未提交修改的项目
- `cdp status @work` — 只显示带 `work` 标签的项目

### 性能

- 对每个项目目录执行 `git` 命令应该足够快（通常 10-50ms/项目）
- 50 个项目应该在 3 秒内完成
- 路径不存在时快速跳过，不要阻塞

### 跨平台

- PowerShell 版实现在 `src/cdp.psm1`
- bash/zsh 版实现在 `src/cdp.sh`
- 输出格式一致

## Implementation Hints

每个项目执行以下 git 命令：
```
git -C <rootPath> rev-parse --is-inside-work-tree    # 是否是 git 仓库
git -C <rootPath> branch --show-current              # 当前分支
git -C <rootPath> status --porcelain                  # 工作区状态
git -C <rootPath> rev-list --count @{u}..HEAD         # ahead count
git -C <rootPath> rev-list --count HEAD..@{u}          # behind count
git -C <rootPath> log -1 --format=%cr                 # 最后 commit 时间
```

## Expected Output

```
 cdp project status (12 projects)
 ─────────────────────────────────────────────────────────────────
  #  Project          Branch       Status       Behind  Last Commit
 ─────────────────────────────────────────────────────────────────
  01 my-api           main         ✓ clean      ↓2      3 hours ago
  02 frontend         feat/auth    ✗ 3 dirty            12 min ago
  03 docs             main         ✓ clean              2 days ago
  04 cdp              main         ✗ 1 dirty    ↓5      just now
  05 side-project     dev          ⚠ untracked          1 week ago
  06 archived-tool    —            path missing
 ─────────────────────────────────────────────────────────────────
  2 repos need attention | 1 path missing
```

## Acceptance Criteria

- [ ] `cdp status` 显示所有项目的 Git 状态表格
- [ ] 非 Git 项目和缺失路径正确处理
- [ ] `--dirty` 过滤正常工作
- [ ] 标签过滤 `cdp status @work` 正常工作
- [ ] PowerShell 版实现完成并通过测试
- [ ] bash/zsh 版实现完成并通过测试
- [ ] 50 个项目场景下 3 秒内完成
- [ ] Pester 测试覆盖核心逻辑
