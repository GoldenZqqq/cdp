# P2: Workspace 模式 - 一键启动多项目工作区

## Goal

支持在 projects.json 中定义 workspace（项目组合），用一条命令同时打开多个相关项目。强化 cdp 作为"项目工作台"而非单纯 cd 工具的定位。

## User Stories

1. 全栈开发者每天早上开工，需要同时打开后端 API、前端、文档仓库
2. 微服务开发者需要同时进入 gateway、service-a、service-b
3. 用户想在一条命令里给多个项目分别打开不同的编辑器/AI CLI

## Requirements

### 配置格式

在 `~/.cdp/workspaces.json` 或在 `projects.json` 同目录下的 `workspaces.json`：

```json
[
  {
    "name": "fullstack",
    "projects": ["my-api", "frontend", "docs"],
    "open": "code"
  },
  {
    "name": "ai-dev",
    "projects": ["my-api", "ml-pipeline"],
    "open": "claude"
  }
]
```

### 命令

- `cdp workspace fullstack` — 在 Windows Terminal 中为每个项目打开新 tab 并 cd 进去
- `cdp workspace fullstack --open code` — 每个项目都打开 VS Code
- `cdp ws fullstack` — 短别名
- `cdp workspace --list` — 列出所有已定义的 workspace
- `cdp workspace --add <name> <project1> <project2> ...` — 快速添加 workspace

### Windows Terminal 集成

PowerShell 版使用 `wt.exe` 打开新 tab：
```powershell
wt -w 0 new-tab -d "E:\Projects\api" --title "api"
```

### bash/zsh 集成

- 使用 tmux（如果可用）创建多个 pane/window
- 无 tmux 时退回到顺序 cd + 启动

## Acceptance Criteria

- [ ] `cdp workspace <name>` 按定义打开多个项目
- [ ] Windows Terminal 中能打开多 tab
- [ ] bash/zsh 中使用 tmux 打开多 pane（tmux 可用时）
- [ ] `cdp workspace --list` 列出所有 workspace
- [ ] `cdp workspace --add` 快速创建 workspace
- [ ] PowerShell 和 bash/zsh 版都实现
- [ ] 添加测试覆盖
