# cdp

<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./docs/assets/cdp-logo-dark-transparent.png">
  <img src="./docs/assets/cdp-logo-light-transparent.png" alt="cdp logo" width="320">
</picture>

**[English](./README.md)** | **简体中文**

**[🌐 访问 cdp 官方网站](https://goldenzqqq.github.io/cdp/)**

在 Vibe Coding 时代，为 Claude Code、Codex、Gemini CLI、Cursor、VS Code 用户准备的**终端项目工作台**。

`cdp` 不只是项目切换器——它知道你的每个仓库是否干净、有没有未推送的提交，还能一键切换并启动 AI CLI。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20WSL-lightgrey)](https://github.com/GoldenZqqq/cdp)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/cdp.svg)](https://www.powershellgallery.com/packages/cdp)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/cdp.svg)](https://www.powershellgallery.com/packages/cdp)

</div>

---

## 演示视频

[![观看 cdp v2.0 演示](./docs/assets/cdp-v2-promo.gif)](https://goldenzqqq.github.io/cdp/#proof)

[在官网体验 AI CLI 交互演示](https://goldenzqqq.github.io/cdp/#workflow) · [观看高清演示](https://goldenzqqq.github.io/cdp/#proof) · [直接打开 v2.0 MP4](https://goldenzqqq.github.io/cdp/assets/cdp-v2-promo.mp4)

这支 v2.0 演示展示了 cdp 的核心功能：`cdp status` 多项目 Git 仪表盘、`cdp api -Open codex` 一步切换并启动 AI CLI、`cdp workspace` 多项目工作区、onEnter 环境自动激活、智能 Tab 补全，以及 Windows / macOS / Linux 全平台支持。

官网交互演示现在把 AI CLI 路线完整展开：解析命名项目、进入当前系统对应的项目根目录、应用已授权的设置，然后让工具从该工作目录启动。它也明确了 cdp 与 `zoxide` / `autojump` 的边界：目录跳转工具负责回忆访问过的路径；cdp 把项目身份、仓库状态和启动器放在同一条路线里。

---

## 为什么需要 cdp

AI CLI 工具把开发者重新带回终端，但多项目切换仍然很笨重：

```powershell
PS C:\> cd E:\Work\Client Projects\VeryLongName\backend
PS E:\Work\Client Projects\VeryLongName\backend> cd ..\..\..\SideProjects\tooling
PS E:\SideProjects\tooling> cd C:\Learn\another-project
```

`cdp` 把这件事缩短成：

```powershell
PS C:\> cdp
# 输入 api / blog / cdp 等关键词
# 回车后直接进入项目根目录
```

更让人头疼的是——你根本不知道哪个仓库还有未提交的代码：

```bash
# 50 个仓库，哪些有未提交的改动？哪些忘了 push？
cd project1 && git status && cd ../project2 && git status && ...
```

`cdp status` 一条命令搞定：

```text
$ cdp status
  #  Project       Branch   Status        Sync   Last Commit
  01 my-api        main     x 3 dirty     ^1     2 hours ago
  02 blog          main     + clean              5 days ago
  03 admin-panel   dev      ! 2 untracked        1 hour ago

3 repos need attention
```

它特别适合：

- 同时维护很多项目的开发者
- 使用 Claude Code、Codex、Gemini CLI 等终端 AI 工具的人
- 依赖 VS Code/Cursor Project Manager 管理项目的人
- 需要在 Windows PowerShell 和 WSL/Linux 之间共享项目列表的人
- macOS / Linux 原生开发者（bash/zsh 全兼容）

---

## 快速开始

### Windows 上的 PowerShell

如果已经习惯 PowerShell Gallery，可以直接安装模块并安装 `fzf`：

```powershell
# 1. 安装 cdp
Install-Module -Name cdp -Scope CurrentUser

# 2. 安装 fzf 依赖
winget install fzf

# 3. 导入并验证
Import-Module cdp
cdp doctor

# 4. 开始切换项目
cdp
```

第一次使用、希望脚本自动处理 `fzf` 和 profile 配置时，推荐从源码安装：

```powershell
git clone https://github.com/GoldenZqqq/cdp.git
cd cdp
.\Install.ps1 -AddToProfile
```

`Install.ps1` 会从 `PSModulePath` 中选择当前 PowerShell edition 可发现的 CurrentUser 或 AllUsers 模块目录，再精确核对本次安装路径与版本。它会依次尝试 `winget`、`scoop`、`chocolatey` 安装 `fzf`；如果安装后当前终端还找不到 `fzf`，重启 PowerShell 后运行 `cdp doctor`。

非交互自动化可使用 `.\Install.ps1 -Force`；只有调用方包管理器已经负责 `fzf` 依赖时才添加 `-SkipFzf`。`-Scope AllUsers` 仍需要在管理员 PowerShell 中运行。

### WSL / Linux / macOS

```bash
# macOS 用户先安装依赖
brew install fzf jq

# 一键安装（WSL/Linux/macOS 通用）
bash <(curl -fsSL https://raw.githubusercontent.com/GoldenZqqq/cdp/v2.1.0/install-wsl.sh) --auto

source ~/.bashrc  # zsh 用户改为 source ~/.zshrc
cdp doctor
cdp
```

`--auto` 会自动安装 `fzf` 和 `jq`；不加 `--auto` 时会逐项询问。

---

## 30 秒使用示例

```powershell
# 添加当前目录为项目
cd E:\Projects\my-api
cdp-add

# 首次使用：先预览，再创建配置并可扫描 Git 仓库
cdp init E:\Projects --dry-run
cdp init E:\Projects --yes

# 从任意位置打开项目选择器
cdp

# 只有一个匹配时直接进入项目；多个匹配时再打开 fzf
cdp api

# 进入项目并启动 AI CLI 或编辑器
cdp api -Open codex
cdp api -Open code

# 批量导入某个目录下的 Git 仓库
cdp-scan E:\Projects --yes

# 查看当前配置健康状态
cdp doctor

# 安全修复失效路径、重复项目和缺失字段
cdp clean --dry-run
cdp clean --yes

# 查看当前版本、配置和升级命令
cdp version

# 查看最近访问过的项目
cdp recent

# 先预览，再清空最近访问历史
cdp recent reset --dry-run
cdp recent reset --yes

# 一条命令查看所有仓库的 Git 状态
cdp status

# 只看需要关注的仓库（dirty / untracked / behind）
cdp status --dirty

# 组合过滤条件并使用显式配置文件
cdp status --dirty '@work' E:\Projects\projects.json

# 调整 status 并发数，并绕过可选的会话缓存
cdp status --jobs 8 --refresh
Show-CdpProjectStatus -ThrottleLimit 8 -Refresh

# 为脚本、CI 和 AI Agent 输出稳定的 schema version 1
cdp status --json
Show-CdpProjectStatus -Json

# 保留人类可读表格，但移除 ANSI / 颜色样式
cdp status --no-color
Show-CdpProjectStatus -NoColor

# 预览或显式确认 status 变更操作
cdp status --fix --dry-run
cdp status --fix --yes
cdp status --push --dry-run

# 将同一 dirty-only 结果返回为结构化 PowerShell 对象
Show-CdpProjectStatus -DirtyOnly -PassThru

# 创建并启动多项目工作区
cdp workspace add fullstack api web --open codex --layout split-horizontal
cdp workspace show fullstack
cdp workspace edit fullstack api web --open codex
cdp workspace validate fullstack --fix --dry-run
cdp workspace open fullstack --yes

# 在多个已选项目中预览、执行或自动化同一个原生命令
cdp exec @work --dry-run -- git status --short
cdp exec --workspace fullstack --jobs 4 --yes -- git status --short
cdp exec --all --json --yes -- git rev-parse --show-toplevel

# 预览或确认项目删除与当前配置选择
cdp remove api --dry-run
cdp remove api --yes
cdp config 1 --yes

# 查看、信任、撤销或跳过项目命令 Hook
cdp hook list
cdp hook trust api
cdp hook revoke api
cdp api --no-hook

# Tab 补全：输入 cdp 后按 Tab 自动补全子命令和项目名
cdp s<TAB>  # → status, scan, ...

# 将常用项目固定在列表顶部
cdp pin api
cdp unpin api

# 添加短别名和标签；PowerShell 查询标签时需要引号
cdp alias api backend
cdp tag api work
cdp backend
cdp '@work'

# 从 PowerShell 直接启动 WSL 并进入项目
cdp -WSL
```

fzf 菜单里输入几个字母即可模糊匹配：

```text
cdp v2.1.0 | 56 projects | enter to warp | C:\Users\you\.cdp\projects.json
cdp > api

  01  my-api          C:\Work\my-api
> 02  company-admin   C:\Work\company-admin
  03  personal-blog   C:\Work\personal-blog

Preview
-------
name   company-admin
state  path exists
git    git repo detected
```

选择后：

- 当前 shell 进入项目根目录
- Windows Terminal / 常见终端标签标题更新为项目名
- WSL 模式会自动把 `C:\path` 转为 `/mnt/c/path`
- 使用 `-Open` 时，会在项目根目录继续启动 Codex、Claude、Gemini、VS Code、Cursor 或其他 PATH 命令

---

## 真实使用场景

### 多仓库日常开发

同时维护公司后台、前端应用、脚本工具和个人项目时，可以先用 `cdp-scan E:\Projects` 批量导入 Git 仓库。之后从任意终端运行 `cdp api`、`cdp admin` 或 `cdp blog`，唯一匹配时直接进入项目，多匹配时再用 `fzf` 选择。

### AI CLI 工作流

使用 Claude Code、Codex、Gemini CLI 等工具时，终端通常是主工作台。`cdp` 会把项目根目录切换、终端标签标题和项目列表放在一起，减少在多个 AI 会话、多个仓库之间反复复制长路径的时间。

需要直接启动 AI CLI 时，可以用 `cdp api -Open codex`、`cdp web -Open claude` 或 `cdp tool -Open gemini`。如果想打开编辑器，可以用 `cdp api -Open code` 或 `cdp api -Open cursor`。

### Workspace 生命周期

`cdp workspace` 现在支持完整生命周期：`list`、`show <name>`、`add <name> <projects...>`、`edit <name> [projects...]`、`remove <name>`、`validate [name] [--fix]` 和 `open <name>`。兼容写法 `cdp workspace <name>` 仍可直接启动。补全同时覆盖 action、workspace 名、项目名、launcher，以及 `tabs`、`split-horizontal`、`split-vertical` 布局。

新定义不再只保存项目名，而是保存稳定项目引用：

```json
{
  "name": "fullstack",
  "open": "codex",
  "layout": { "mode": "split", "direction": "horizontal" },
  "projects": [
    { "name": "api", "rootPath": "C:/Work/api" },
    { "name": "web", "rootPath": "C:/Work/web", "open": "code", "size": 40 }
  ]
}
```

`rootPath` 是稳定身份，`name` 是可读提示。如果项目只改名、raw `rootPath` 不变，验证会报告 `renamed`，启动时安全使用当前项目；如果项目被删除，或旧名称被另一个 raw path 复用，cdp 会报告 `missing-project`，不会按名称错误绑定。旧字符串引用仍可读取；`workspace validate --fix` 会升级可解析字符串、刷新重命名提示，同时保留无法解析的引用与未知未来字段。

Launcher 优先级为 CLI `--open`、项目级 `open`、workspace 级 `open`。split 的 `size` 必须是 10 到 90 的整数。Windows Terminal 接收 `new-tab` / `split-pane` argv，tmux 接收 `new-window` / `split-window` argv；cdp 不会执行拼接的 workspace 命令字符串。启动前会先完成所有引用与本机路径规划；某项失败后仍继续后续安全项目，但只要存在不安全目标，最终结果就失败。使用 PowerShell `-WhatIf` 或 shell `--dry-run` 可在不写入、不启动进程的情况下查看 workspace、layout、当前名称、raw/resolved path、launcher 和引用状态；shell 真正启动仍要求 `--yes`。

### 安全多仓库 Exec

`cdp exec` 可按显式项目集、单个 `@tag`、单个 workspace 或显式 `--all`，在多个仓库中执行同一个原生 executable。强制的 `--` 边界会把后续所有 token 保留为命令 argv，因此 cdp 不会再次解析命令选项，也不会执行 shell 语法：

```bash
cdp exec api web --dry-run -- git status --short
cdp exec @work --jobs 4 --yes -- git fetch --prune
cdp exec --workspace fullstack --json --yes -- git rev-parse --show-toplevel
```

第一个进程启动前会先完成全部选择与本机路径解析。显式项目保持输入顺序，workspace 保持引用顺序，tag / `--all` 保持配置顺序；相同 raw `rootPath` 身份只执行一次。workspace 引用继续保留重命名、删除、歧义保护与 path profile 行为。

所有真实 exec 都按高影响操作处理：PowerShell 使用 `ShouldProcess`（`-WhatIf` / `-Confirm:$false`），bash/zsh 必须使用 `--yes`；`--dry-run` 不创建进程。命令始终以 executable + argv 数组调用，每个项目拥有独立 cwd/stdout/stderr，且没有交互 stdin。cdp 不使用 `eval`，也不隐式启动 shell；只有确实需要管道或重定向时，才显式传入 `sh -c` 或 `pwsh -Command`。

默认策略会在某个仓库失败后继续安全的后续仓库。`--fail-fast` 会完成当前有限并发批次，再把尚未调度的仓库标记为 `canceled`。可用 `--jobs 1-16`、`--timeout 1-3600`、`CDP_EXEC_CONCURRENCY` 和 `CDP_EXEC_TIMEOUT_SECONDS` 控制执行边界。

### 跨平台路径 Profile

同一个项目现在可以保存不同平台的本机路径，同时保留原有、兼容 Project Manager 的 `rootPath`。cdp 会按当前运行环境选择 `paths.windows`、`paths.wsl`、`paths.linux` 或 `paths.macos`。当前映射缺失时，旧配置仍回退到 `rootPath`；WSL 也继续支持把 `C:\...` 自动转换为 `/mnt/c/...`。

容器或自动化场景可设置 `CDP_PATH_PROFILE=windows|wsl|linux|macos` 覆盖自动检测。显式的当前平台路径具有最高优先级：如果它无效或目录不存在，cdp 会报告该路径，不会静默进入 `rootPath` 或其他平台目录。PowerShell 的 `cdp -WSL` 始终按 WSL profile 解析。

项目切换、选择器、status/Git、doctor/repair、workspace、add/scan/init 和最近路径显示共用同一 resolver。`rootPath` 继续作为旧版 cdp 使用的原始身份，文件系统操作则使用解析后的本机路径。

bash/zsh 内置 launcher 会区分编辑器参数与无需参数的 AI CLI，因此 `codex`、`claude` 和 `gemini` 启动时不会误带显示标签参数。workspace 启动与仓库扫描还会隔离迭代和子进程输入，确保每个已配置项目都被处理。zsh 适配器也会在路径操作中保持命令查找能力，并维持一致的补全索引，包括 `workspace` 补全。

---

## 核心特性

- **多项目 Git 状态仪表盘**：`cdp status` 一条命令查看所有仓库的分支、dirty 与 untracked 数量、ahead/behind 同步、linked worktree 和最近提交时间
- **机器可读状态**：`cdp status --json` 输出稳定 schema version 1，包含原始/解析路径、Git 计数、关注原因、脱敏错误、扫描时间、汇总与自动化退出码
- **安全多仓库 Exec**：按项目、tag、workspace 或显式 `--all` 执行一个原生命令，支持 argv 隔离、有限并发/超时、dry-run、fail-fast 和带 schema 版本的 JSON 结果
- **跨平台路径 Profile**：同一个兼容 Project Manager 的项目项可映射 Windows、WSL、Linux 和 macOS 路径，而无需重写 `rootPath`
- **全平台支持**：Windows PowerShell 5.1/7.x + macOS (zsh/bash) + Linux + WSL，CI 覆盖全部
- **智能 Tab 补全**：输入 `cdp` 按 Tab 自动补全子命令和项目名，PowerShell + bash + zsh 全支持
- **模糊搜索切换项目**：由 `fzf` 驱动，键盘优先，不需要记路径
- **Neon 风格 TUI**：彩色候选行、右侧项目预览、路径/Git 状态一眼可见
- **快速 query 跳转**：`cdp api` 唯一匹配时直接进入项目，多匹配时只在候选中选择
- **AI CLI 工作区启动**：`cdp api -Open codex` 先进入项目根目录，再启动 Codex、Claude、Gemini、VS Code 或 Cursor
- **兼容 Project Manager**：自动读取 VS Code/Cursor Project Manager 配置
- **自带项目管理命令**：`cdp-add`、`cdp-rm`、`cdp-ls`、`cdp-config`
- **批量 Git 扫描**：`cdp-scan` 可把目录下的 Git 仓库批量导入配置
- **Frecency 智能排序**：pin 项目始终置顶，随后 picker、列表和多匹配 query 优先常用且最近访问的项目；设置 `CDP_FRECENCY=off` 可恢复 pin + 配置顺序
- **最近访问项目**：`cdp recent` / `cdp-recent` 列出访问历史，`cdp recent reset` 可安全清空历史
- **项目置顶 / 收藏**：`cdp pin api` 把常用项目固定在选择器和列表顶部
- **标签与短别名**：`cdp alias api backend` 添加短别名；`cdp tag api work` 后可用 `cdp '@work'` 过滤项目
- **配置健康检查与修复**：`cdp doctor` 检查依赖、JSON、重复项目名、失效路径；`cdp clean` 安全修复项目配置
- **Windows + WSL/Linux**：PowerShell 和 bash/zsh 版本共享同一类配置
- **终端标签同步**：切换后自动把 tab title 改为项目名

---

## 命令列表

### PowerShell

| 命令 | 别名 | 说明 |
| --- | --- | --- |
| `Invoke-Cdp` | `cdp` | 短命令入口，默认打开项目选择器 |
| `Show-CdpProjectStatus` | `cdp status`, `cdp-status` | Git 状态仪表盘，支持 `--dirty`、`@tag`、`--jobs`、`--refresh`、`--json` 和 `--no-color` |
| `Invoke-Cdp` | `cdp exec`, `cdp run` | 在显式项目、tag、workspace 或显式 `--all` 中安全执行一个原生命令 |
| `Invoke-CdpWorkspace` | `cdp workspace`, `cdp ws` | 列出、查看、添加、编辑、删除、验证、迁移或启动稳定多项目 workspace |
| `Invoke-Cdp` | `cdp hook list/trust/revoke` | 查看脱敏后的 Hook 状态，并管理项目级持久信任 |
| `Invoke-Cdp -Query api` | `cdp api` | 按名称或路径快速匹配项目，唯一匹配时直接切换 |
| `Invoke-Cdp -Query api -Open codex` | `cdp api -Open codex` | 切换到项目并启动 Codex、Claude、Gemini、VS Code、Cursor 或其他 PATH 命令 |
| `Switch-Project` | - | 打开 fzf 菜单并切换项目 |
| `Switch-Project -Query api` | - | 只在匹配 `api` 的项目中切换 |
| `Switch-Project -Query api -Open code` | - | 切换到项目并打开 VS Code |
| `Switch-Project -WSL` | `cdp -WSL` | 选择项目并启动 WSL 进入目录 |
| `Test-ProjectHealth` | `cdp doctor`, `cdp-doctor` | 诊断 cdp 环境和配置 |
| `Repair-ProjectConfig` | `cdp clean`, `cdp-clean` | 安全修复配置：禁用失效路径、去重、补齐 `pinned` 字段 |
| `Initialize-Cdp` | `cdp init`, `cdp-init` | 首次使用初始化：创建配置、保存选择、可扫描 Git 仓库 |
| `Add-ProjectAlias` | `cdp alias`, `cdp-alias` | 给项目添加短别名，之后可直接用别名匹配 |
| `Remove-ProjectAlias` | `cdp unalias`, `cdp-unalias` | 移除项目短别名 |
| `Add-ProjectTag` | `cdp tag`, `cdp-tag` | 给项目添加标签，PowerShell 中用 `cdp '@work'` 查询 |
| `Remove-ProjectTag` | `cdp untag`, `cdp-untag` | 移除项目标签 |
| `Show-CdpAbout` | `cdp about`, `cdp version` | 显示 cdp Logo、版本、配置路径、项目数量和升级命令 |
| `Get-CdpRecentProjects` | `cdp recent`, `cdp-recent` | 列出最近访问过的项目 |
| `Reset-CdpRecentProjects` | `cdp recent reset` | 使用原生 `-WhatIf` / `-Confirm` 安全清空最近访问历史 |
| `Set-ProjectPin` | `cdp pin`, `cdp-pin` | 将项目固定在选择器和列表顶部 |
| `Clear-ProjectPin` | `cdp unpin`, `cdp-unpin` | 取消项目置顶 |
| `Add-Project` | `cdp add`, `cdp-add` | 添加当前目录或指定路径 |
| `Import-GitProjects -RootPath E:\Projects` | `cdp-scan`, `cdp scan` | 扫描 Git 仓库并批量导入配置 |
| `Remove-Project` | `cdp remove`, `cdp-rm` | 删除项目，支持交互选择 |
| `Get-ProjectList` | `cdp-ls` | 列出已启用项目 |
| `Edit-ProjectConfig` | `cdp-edit` | 打开配置文件 |
| `Set-ProjectConfig` | `cdp config`, `cdp-config` | 切换当前使用的配置文件 |

### WSL / Linux

| 命令 | 说明 |
| --- | --- |
| `cdp` | 打开 fzf 菜单并切换项目 |
| `cdp status` / `cdp-status` | Git 状态仪表盘，支持 `--dirty`、`@tag`、`--jobs`、`--refresh`、`--json` 和 `--no-color` |
| `cdp exec` / `cdp run` | 在项目、tag、workspace 或显式 `--all` 中安全执行原生 argv；真实执行必须使用 `--yes` |
| `cdp workspace` / `cdp ws` | 完整 workspace 生命周期，支持稳定引用、验证/修复、launcher 覆盖和 tabs/split 布局 |
| `cdp hook list/trust/revoke` | 查看脱敏后的 Hook 状态，并管理项目级持久信任 |
| `cdp api` | 按名称或路径快速匹配项目，唯一匹配时直接切换 |
| `cdp api --open codex` | 切换到项目并启动 Codex、Claude、Gemini、VS Code、Cursor 或其他 PATH 命令 |
| `cdp doctor` / `cdp-doctor` | 诊断依赖、配置和项目路径 |
| `cdp clean` / `cdp-clean` | 安全修复配置：禁用失效路径、去重、补齐 `pinned` 字段 |
| `cdp init ~/code` / `cdp-init ~/code` | 首次使用初始化：创建配置、保存选择、可扫描 Git 仓库 |
| `cdp alias api backend` / `cdp-alias api backend` | 给项目添加短别名 |
| `cdp tag api work` / `cdp-tag api work` | 给项目添加标签，bash/zsh 中可用 `cdp @work` 查询 |
| `cdp about` / `cdp version` | 显示版本、配置路径、项目数量和升级命令 |
| `cdp recent` / `cdp-recent` | 列出最近访问过的项目 |
| `cdp recent reset --dry-run` / `cdp recent reset --yes` | 预览或确认清空最近访问历史，并保留其他状态字段 |
| `cdp pin api` / `cdp-pin api` | 将项目固定在选择器和列表顶部 |
| `cdp unpin api` / `cdp-unpin api` | 取消项目置顶 |
| `cdp add` / `cdp-add` | 添加当前目录或指定路径 |
| `cdp remove` / `cdp-rm` | 删除唯一匹配的项目；必须使用 `--yes` 或用 `--dry-run` 预览 |
| `cdp-scan ~/code` / `cdp scan ~/code` | 扫描 Git 仓库并批量导入配置 |
| `cdp-ls` | 列出已启用项目 |
| `cdp config 1` / `cdp-config 1` | 切换当前配置；必须使用 `--yes` 或用 `--dry-run` 预览 |

---

## 配置来源

cdp 会按以下规则寻找项目配置：

1. `CDP_CONFIG` 环境变量
2. 已保存的 `cdp-config` 选择
3. Cursor Project Manager 配置
4. VS Code Project Manager 配置
5. 自定义配置 `~/.cdp/projects.json`

如果你已经使用 [Project Manager](https://marketplace.visualstudio.com/items?itemName=alefragnani.project-manager)，通常无需额外配置。否则可以直接用：

```powershell
cd E:\Projects\my-api
cdp-add

# 或者一次性扫描某个目录下的 Git 仓库
cdp-scan E:\Projects --yes
```

自定义配置文件格式：

```json
[
  {
    "name": "my-api",
    "rootPath": "E:/Projects/my-api",
    "paths": {
      "windows": "E:/Projects/my-api",
      "wsl": "/home/me/work/my-api",
      "linux": "/srv/work/my-api",
      "macos": "/Users/me/work/my-api"
    },
    "enabled": true,
    "pinned": false,
    "aliases": ["backend"],
    "tags": ["work", "api"]
  },
  {
    "name": "personal-blog",
    "rootPath": "D:/Code/blog",
    "enabled": true,
    "pinned": true,
    "aliases": [],
    "tags": ["writing"]
  }
]
```

`paths`、`pinned`、`aliases`、`tags` 都是可选字段。旧配置会继续原样使用 `rootPath`。新的 `cdp add`、`cdp scan`、`cdp init` 项会同时写入 `rootPath` 和自动检测到的当前平台映射；旧版 cdp 与 Project Manager 会忽略新增的 `paths` 对象并继续读取 `rootPath`。建议在 JSON 中使用 `/`，避免 Windows 反斜杠转义。

路径选择顺序是确定的：

1. 显式 `paths.<current-profile>` 值。
2. 仅在 WSL 中，未配置 `paths.wsl` 时自动转换 Windows `rootPath`。
3. 旧配置使用原始 `rootPath` fallback。

允许的 profile 为 `windows`、`wsl`、`linux`、`macos`，已声明的值必须是非空字符串。cdp mutation 会保留未知项目字段和未来新增的 `paths` 键。需要强制 profile 时，PowerShell 设置 `$env:CDP_PATH_PROFILE = 'wsl'`，bash/zsh 设置 `export CDP_PATH_PROFILE=wsl`；非法值会直接失败，不会静默 fallback。

### 状态与持久化文件

| 路径 | 用途 | 所有权 / 覆盖方式 |
| --- | --- | --- |
| 当前 `projects.json` | 项目名、路径、启用状态、元数据和 `onEnter` | 由自动发现、`CDP_CONFIG` 或 `cdp config` 选择 |
| `~/.cdp/config` | 指向显式选择的项目配置 | 仅由配置选择命令写入 |
| `~/.cdp/state.json` | 最近访问时间与访问次数 | 自动化可用 `CDP_STATE_PATH` 覆盖 |
| 当前配置同目录的 `workspaces.json` | 带稳定 `{name, rootPath}` 引用、launcher 与布局的命名 workspace 定义 | PowerShell 与 bash/zsh 共享；v2.2+ 写入稳定引用 schema |
| `~/.cdp/hook-trust.json` | 只保存带版本的 Hook 指纹与时间戳 | 隔离测试可用 `CDP_HOOK_TRUST_PATH` 覆盖 |
| 同目录 `*.cdp.lock` / `*.cdp-backup.*` | 并发写入互斥与最新三份有效备份 | 由原子持久化层管理 |

项目路径仍保存在 `projects.json`；最近状态、workspace 定义与 Hook 信任刻意分离，从而保持 Project Manager 兼容，并避免可信命令数据进入公开项目列表。旧字符串 workspace 引用仍可读取，但生命周期编辑与 `validate --fix` 会使用 v2.2 稳定引用 schema。

### 项目环境 Hook

进入项目时会应用结构化环境变量。环境变量名只能包含字母、数字和下划线，且不能以数字开头：

```json
{
  "name": "my-api",
  "rootPath": "E:/Projects/my-api",
  "enabled": true,
  "onEnter": {
    "env": { "NODE_ENV": "development" },
    "powershell": "$env:API_PROFILE = 'local'",
    "bash": "export API_PROFILE=local"
  }
}
```

命令 Hook 默认跳过。PowerShell 使用 `cdp api -AllowHook`、bash/zsh 使用 `cdp api --allow-hook`，只授权当前一次切换。需要持久项目级授权时，先检查当前生效的配置，再运行 `cdp hook trust api`；用 `cdp hook list` 查看状态，用 `cdp hook revoke api` 或 `cdp hook revoke --all` 撤销。信任绑定配置规范化路径、配置内容 SHA-256、项目身份与命令 SHA-256，因此配置移动或内容变化后必须重新信任。`~/.cdp/hook-trust.json` 只保存指纹与时间戳，不保存命令正文、配置内容或环境变量值，并限制文件权限。`--no-hook` 会在本次切换中同时跳过结构化环境变量和命令。

最近访问记录保存在独立状态文件 `~/.cdp/state.json`，不会写回 `projects.json`。自动化或测试场景可以用 `CDP_STATE_PATH` 指向临时状态文件。picker、`cdp-ls`、`Get-ProjectList` 与多匹配 query 始终先展示 pin 分组，再按匹配 exact raw `rootPath` 的历史计算 `floor(clamp(visitCount, 1, 1000) * 1000000 / (ageDays + 1))`；同分依次比较最后访问时间、访问次数和原始配置索引。state 缺失或损坏时退回 pin + 配置顺序，未来时间按 age 0 处理。设置 `CDP_FRECENCY=0`、`false`、`off` 或 `no` 可关闭分值层。

cdp 通过同目录原子替换持久化项目、最近访问和 workspace JSON。并发修改会被拒绝而不是互相覆盖，并保留最新三份 `*.cdp-backup.*` 供显式恢复；项目配置损坏但存在有效备份时，`cdp doctor` 会给出诊断。

### 安全变更

PowerShell 变更函数支持原生 `-WhatIf` 与 `-Confirm`；加 `-PassThru` 可获得 `Action`、`Target`、`Status`、`Changed`、`Error` 字段。bash/zsh 变更命令支持 `--dry-run` 与 `--yes`，并为每个目标打印一行结果。添加项目、置顶、别名/标签、workspace 定义和 Hook 信任属于低风险操作，默认执行行为保持不变。修复、删除、扫描/导入、初始化、status fix/push、当前配置选择、外部 workspace 启动，以及所有真实多仓库 exec 都必须显式授权。shell 高影响命令不会从 stdin 读取确认；使用 `--yes` 执行，或用 `--dry-run` 在不写 JSON、不 push Git、不启动进程的情况下预览。

`cdp clean` 与 `cdp status --fix` 遇到不可用的显式平台路径时，会保留项目而不是删除或禁用共享配置项；旧式 fallback 路径仍保持原有修复行为。这样可以避免缺失挂载点或本机未 checkout 项目时破坏其他平台仍有效的路径。

`cdp config` / `cdp-config` 使用列表中的数字选择配置。shell 自动化应显式传入序号，例如 `cdp config 1 --yes`；PowerShell 可使用 `Set-ProjectConfig -Selection 1 -Confirm:$false`。仅清空 `recentProjects` 可使用 `cdp recent reset --dry-run` / `--yes`，或 `Reset-CdpRecentProjects -WhatIf` / `-Confirm:$false`；损坏 state 绝不会被覆盖，已经为空时也不会写文件或创建备份。

### Status 自动化契约

`cdp status --json` 与 `Show-CdpProjectStatus -Json` 只向 stdout 写入一个 JSON 文档，致命诊断写入 stderr。文档使用 `schemaVersion: 1`，包含扫描时间、当前过滤条件、汇总信息和 `projects` 数组。每个项目会将配置身份 `rawPath` 与本机实际访问的 `resolvedPath` 分开，并包含 `pathExists`、稳定 `status`、`needsAttention`、`attentionReasons`、脱敏 `error` 及嵌套 Git 字段。

稳定状态码为 `clean`、`changed`、`path_missing`、`path_profile_invalid`、`not_git`、`scan_timeout`、`scan_failed`；稳定关注原因为 `dirty`、`untracked`、`behind`、`path_missing`、`path_profile_invalid`、`scan_timeout`、`scan_failed`。消费者应拒绝不支持的 schema 主版本，但可以忽略后续新增字段。

JSON 模式只读，不能与 `--fix` 或 `--push` 组合。退出码：`0` 表示干净成功，`1` 表示输出项目需要关注，`2` 表示部分超时/扫描失败，`3` 表示解析、依赖、配置或序列化致命失败。`--dirty` 会过滤项目数组，但 `summary.total` 仍记录所有已扫描的启用项目。需要纯文本表格时使用 `--no-color` / `-NoColor`。

### Exec 自动化契约

`cdp exec ... --json -- <command> [args...]` 只向 stdout 写入一个 schema version 1 文档。解析、依赖、配置、selector、executable 解析或序列化致命失败只写 stderr。文档包含 selector、原始 executable token 与 argv、解析后的 jobs/timeout/fail-fast/dry-run 选项、按顺序汇总，以及带 `name`、`rawPath`、`resolvedPath`、`status`、`exitCode`、`elapsedMs`、`stdout`、`stderr`、`error` 的有序结果。

稳定结果状态为 `planned`、`succeeded`、`failed`、`timed_out`、`canceled`、`missing_project`、`ambiguous_project`、`disabled_project`、`path_profile_invalid`、`path_missing`。退出码 `0` 表示全部命令成功或 dry-run 计划有效；`1` 表示 continue 模式存在命令或目标失败；`2` 表示 fail-fast 产生 canceled 目标；`3` 表示尚未生成完整结果文档前发生致命失败。

命令边界是强制的。`--` 后的 token（包括 `--json`、空格、空字符串和 shell 元字符）都保留为命令 argv，而不是 cdp 选项。每个仓库独立捕获 stdout/stderr，最终按选择顺序而不是完成顺序输出。

---

## 性能建议

如果第一次打开 Windows Terminal 后运行 `cdp` 需要等待几秒，通常不是项目数量本身造成的。PowerShell 首次自动加载模块、PATH 中查找 `fzf`，以及 Windows 对 `fzf.exe` 的冷启动检查都可能带来额外延迟。

可以在 PowerShell profile 里固定常用配置和 `fzf` 路径，减少首次交互前的探测：

```powershell
$env:CDP_CONFIG = "$HOME\.cdp\projects.json"
$env:CDP_FZF_PATH = "C:\Users\you\AppData\Local\Microsoft\WinGet\Links\fzf.exe"
```

`CDP_FZF_PATH` 应填写 `(Get-Command fzf).Path` 返回的实际路径。`cdp` 也会在同一个 PowerShell 会话中缓存已解析的项目配置，配置文件被 `cdp-add`、`cdp-scan`、`cdp-rm` 修改后会自动失效并重新读取。

`cdp status` 使用有限本地并发；对已有提交的仓库最多执行两次 Git 探测。可通过 `CDP_STATUS_CONCURRENCY`（1-16）或 `--jobs` / `-ThrottleLimit` 调整 worker 数量。`CDP_STATUS_TIMEOUT_SECONDS`（1-60，默认 10）限制单仓库扫描时间，避免一个慢仓库阻塞整个仪表盘。

status 缓存默认关闭。将 `CDP_STATUS_CACHE_TTL` 设置为 1-60 秒可在当前 shell 或 PowerShell 会话中复用结果；需要最新数据时使用 `--refresh` / `-Refresh`。`status --fix` 与 `status --push` 始终绕过缓存。

`cdp exec` 默认最多使用 4 个 worker，并为每个项目设置 300 秒超时。可在单次命令中用 `--jobs`、`--timeout` 覆盖，或设置 `CDP_EXEC_CONCURRENCY`（1-16）与 `CDP_EXEC_TIMEOUT_SECONDS`（1-3600）。

```powershell
$env:CDP_STATUS_CONCURRENCY = "4"
$env:CDP_STATUS_CACHE_TTL = "15"
$env:CDP_STATUS_TIMEOUT_SECONDS = "10"
```

---

## 诊断与排错

先运行：

```powershell
cdp doctor
```

它会检查：

- `fzf` 是否在 `PATH` 中
- PowerShell Gallery 是否有新的 `cdp` 版本
- bash/zsh 版是否安装 `jq`
- 当前使用哪个配置文件
- JSON 是否能解析
- 项目字段是否完整
- 是否有重复项目名
- 启用项目的路径是否存在

常见问题：

```powershell
# fzf 未安装
winget install fzf

# winget 不可用时
scoop install fzf
choco install fzf -y

# 重新导入模块
Import-Module cdp -Force

# 升级 cdp（PowerShell Gallery 安装）
Update-Module -Name cdp -Scope CurrentUser -Force

# 如果不是通过 Install-Module 安装，或 Update-Module 找不到旧安装记录
Install-Module -Name cdp -Scope CurrentUser -Force -AllowClobber

# 查看当前项目列表
cdp-ls

# 安全修复配置
cdp clean --dry-run
cdp clean --yes

# 切换配置文件
cdp-config 1 --yes
```

---

## 和其他工具的区别

| 工具 | 项目切换 | 项目状态总览 | AI CLI 集成 | 说明 |
| --- | --- | --- | --- | --- |
| `cd` / Tab 补全 | 手动输入路径 | 无 | 无 | 路径深、项目多时成本高 |
| `zoxide` / `autojump` | 按频率跳转 | 无 | 无 | 只知道路径，不知道”项目” |
| 纯 `fzf cd` 脚本 | 扫描目录选择 | 无 | 无 | 一次性列表，无统一配置 |
| VS Code Project Manager | 编辑器内切换 | 无 | 无 | 仅限编辑器内使用 |
| **cdp** | **模糊搜索 + query 直达** | **`cdp status` 全仓库仪表盘** | **`-Open codex/claude/gemini`** | 终端里的项目工作台 |

cdp 的重点不是替代所有跳转工具。`zoxide` 和 `autojump` 擅长回忆去过的任意目录；cdp 是项目上下文层：解析命名项目、选择平台对应的本机根目录、展示仓库状态，并能一键启动 AI CLI。两者可以互补使用，而不是互相排斥。

---

## 开发

### 官网预览与发布

官网是 `docs/` 下的纯静态 GitHub Pages 站点，无需安装前端依赖：

```powershell
python -m http.server 4173 --directory docs
```

然后访问 `http://localhost:4173`。首次发布时，在 GitHub 仓库 **Settings → Pages** 中选择 **Deploy from a branch**，分支设为 `main`，目录设为 `/docs`；后续推送到 `main` 会自动更新官网。

```powershell
# 导入本地模块
Import-Module ./cdp.psd1 -Force

# 运行诊断
cdp doctor .\examples\projects.json

# 运行固定版本的 Pester、覆盖率、Analyzer 与发布元数据门禁
.\scripts\Invoke-PowerShellQualityGate.ps1
```

```bash
# 验证 canonical shell 分片与生成的发行文件
bash ./scripts/Build-ShellScript.sh --check
bash ./tests/cdp.Shell.Modularization.Tests.sh
bash ./tests/cdp.Shell.V2.Tests.sh

# 验证确定性发布包
bash ./scripts/Test-ScoopPackage.sh

# 验证文档、媒体策略与真实 Chromium 交互
node ./scripts/Test-Documentation.mjs
pnpm --dir tests/web install --frozen-lockfile
pnpm --dir tests/web exec playwright install chromium
pnpm --dir tests/web test
```

CI 覆盖：

- Windows PowerShell 5.1
- PowerShell 7.x
- Chromium 官网与文档 smoke
- Ubuntu bash、shell 质量、发布包、性能与固定镜像 Bash 3.2 回归
- macOS bash/zsh smoke 与安装器测试

---

## 路线图

- [x] fzf 项目切换
- [x] VS Code/Cursor Project Manager 配置读取
- [x] 自定义配置文件
- [x] 项目添加、删除、列出、配置切换
- [x] PowerShell + WSL/Linux 支持
- [x] `cdp doctor` 诊断命令
- [x] GitHub Actions 基础 CI
- [x] 最近访问项目
- [x] 跨平台 Frecency 智能排序与安全最近历史重置
- [x] 项目置顶 / 收藏
- [x] `cdp <query>` 非交互快速匹配
- [x] 批量扫描 Git 仓库生成配置
- [x] 切换项目后启动 AI CLI / 编辑器
- [x] `cdp doctor --fix` / `cdp clean` 自动修复失效路径和重复项
- [x] `cdp init` 首次使用向导
- [x] 项目标签 / 别名
- [x] `cdp status` 多项目 Git 状态仪表盘
- [x] 带稳定引用、验证/迁移和 tabs/split launcher 的完整 workspace 生命周期
- [x] 支持 selector、argv 隔离、有限并发、超时、dry-run、fail-fast 和 JSON 结果的安全多仓库 exec
- [x] 原子 JSON 持久化、安全变更与项目级 Hook 信任
- [x] 有限并发 status、超时、缓存与基准测试
- [x] 仓库自有覆盖率、发布包、文档、浏览器与媒体质量门禁
- [x] macOS 原生支持（zsh + bash）
- [x] 智能 Tab 补全（PowerShell + bash + zsh）

---

## 贡献

欢迎提交 issue 和 PR。开始前请阅读 [CONTRIBUTING.md](./CONTRIBUTING.md)。

```powershell
git clone https://github.com/GoldenZqqq/cdp.git
cd cdp
git checkout -b feature/your-feature

Import-Module ./cdp.psd1 -Force
Invoke-Pester -Path ./tests -CI
```

使用 Conventional Commits，并采用简短中文摘要：

```text
feat: 增加项目健康检查
fix: 修复 WSL 路径转换
docs: 同步双语使用说明
```

---

## 致谢

- [fzf](https://github.com/junegunn/fzf)
- [Project Manager](https://marketplace.visualstudio.com/items?itemName=alefragnani.project-manager)

## License

[MIT](./LICENSE)
