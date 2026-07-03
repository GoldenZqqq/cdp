# cdp

<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./docs/assets/cdp-logo-dark-transparent.png">
  <img src="./docs/assets/cdp-logo-light-transparent.png" alt="cdp logo" width="320">
</picture>

**简体中文** | **[English](./README_EN.md)**

在 Vibe Coding 时代，为 Claude Code、Codex、Gemini CLI、Cursor、VS Code 用户准备的快速项目切换器。

`cdp` 用 `fzf` 打开你的项目列表，输入几个字母，回车，终端立刻切到项目根目录并更新标签标题。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20WSL%20%7C%20Linux-lightgrey)](https://github.com/GoldenZqqq/cdp)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/cdp.svg)](https://www.powershellgallery.com/packages/cdp)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/cdp.svg)](https://www.powershellgallery.com/packages/cdp)

</div>

---

## 演示视频

![cdp 中文演示：用模糊搜索快速切换项目](./docs/assets/cdp-demo-short-zh.gif)

[观看中文 28 秒 MP4](./docs/assets/cdp-demo-short-zh.mp4) · [English GIF](./docs/assets/cdp-demo-short-en.gif) · [English MP4](./docs/assets/cdp-demo-short-en.mp4)

这支短版演示讲清楚：Vibe Coding 时代为什么项目切换变成高频痛点，`cdp` 如何用 `fzf`、Project Manager / JSON 配置、`cdp doctor` 和 WSL 支持把这件事变成一个稳定的终端工作流。

视频脚本、设计规范与 HyperFrames composition：
[docs/video/cdp-intro-script.md](./docs/video/cdp-intro-script.md)、
[docs/video/cdp-intro/frame.md](./docs/video/cdp-intro/frame.md)、
[docs/video/cdp-intro/index.html](./docs/video/cdp-intro/index.html)。

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

它特别适合：

- 同时维护很多项目的开发者
- 使用 Claude Code、Codex、Gemini CLI 等终端 AI 工具的人
- 依赖 VS Code/Cursor Project Manager 管理项目的人
- 需要在 Windows PowerShell 和 WSL/Linux 之间共享项目列表的人

---

## 快速开始

### Windows PowerShell

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

`Install.ps1` 会依次尝试 `winget`、`scoop`、`chocolatey` 安装 `fzf`；如果安装后当前终端还找不到 `fzf`，重启 PowerShell 后运行 `cdp doctor`。

### WSL / Linux

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/GoldenZqqq/cdp/main/install-wsl.sh) --auto

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

# 从任意位置打开项目选择器
cdp

# 只有一个匹配时直接进入项目；多个匹配时再打开 fzf
cdp api

# 批量导入某个目录下的 Git 仓库
cdp-scan E:\Projects

# 查看当前配置健康状态
cdp doctor

# 查看当前版本、配置和升级命令
cdp version

# 从 PowerShell 直接启动 WSL 并进入项目
cdp -WSL
```

fzf 菜单里输入几个字母即可模糊匹配：

```text
cdp v1.6.2 | 56 projects | enter to warp | C:\Users\you\.cdp\projects.json
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

---

## 真实使用场景

### 多仓库日常开发

同时维护公司后台、前端应用、脚本工具和个人项目时，可以先用 `cdp-scan E:\Projects` 批量导入 Git 仓库。之后从任意终端运行 `cdp api`、`cdp admin` 或 `cdp blog`，唯一匹配时直接进入项目，多匹配时再用 `fzf` 选择。

### AI CLI 工作流

使用 Claude Code、Codex、Gemini CLI 等工具时，终端通常是主工作台。`cdp` 会把项目根目录切换、终端标签标题和项目列表放在一起，减少在多个 AI 会话、多个仓库之间反复复制长路径的时间。

### Windows + WSL 混合环境

Windows PowerShell 可以读取 Cursor / VS Code Project Manager 配置；WSL/Linux 版也能使用同类 JSON 项目列表。需要从 PowerShell 进入 WSL 项目时，用 `cdp -WSL` 选择项目，Windows 路径会自动转换为 `/mnt/c/...`。

---

## 核心特性

- **模糊搜索切换项目**：由 `fzf` 驱动，键盘优先，不需要记路径
- **Neon 风格 TUI**：彩色候选行、右侧项目预览、路径/Git 状态一眼可见
- **快速 query 跳转**：`cdp api` 唯一匹配时直接进入项目，多匹配时只在候选中选择
- **兼容 Project Manager**：自动读取 VS Code/Cursor Project Manager 配置
- **自带项目管理命令**：`cdp-add`、`cdp-rm`、`cdp-ls`、`cdp-config`
- **批量 Git 扫描**：`cdp-scan` 可把目录下的 Git 仓库批量导入配置
- **配置健康检查**：`cdp doctor` 检查依赖、JSON、重复项目名、失效路径
- **Windows + WSL/Linux**：PowerShell 和 bash/zsh 版本共享同一类配置
- **终端标签同步**：切换后自动把 tab title 改为项目名

---

## 命令列表

### PowerShell

| 命令 | 别名 | 说明 |
| --- | --- | --- |
| `Invoke-Cdp` | `cdp` | 短命令入口，默认打开项目选择器 |
| `Invoke-Cdp -Query api` | `cdp api` | 按名称或路径快速匹配项目，唯一匹配时直接切换 |
| `Switch-Project` | - | 打开 fzf 菜单并切换项目 |
| `Switch-Project -Query api` | - | 只在匹配 `api` 的项目中切换 |
| `Switch-Project -WSL` | `cdp -WSL` | 选择项目并启动 WSL 进入目录 |
| `Test-ProjectHealth` | `cdp doctor`, `cdp-doctor` | 诊断 cdp 环境和配置 |
| `Show-CdpAbout` | `cdp about`, `cdp version` | 显示 cdp Logo、版本、配置路径、项目数量和升级命令 |
| `Add-Project` | `cdp-add` | 添加当前目录或指定路径 |
| `Import-GitProjects -RootPath E:\Projects` | `cdp-scan`, `cdp scan` | 扫描 Git 仓库并批量导入配置 |
| `Remove-Project` | `cdp-rm` | 删除项目，支持交互选择 |
| `Get-ProjectList` | `cdp-ls` | 列出已启用项目 |
| `Edit-ProjectConfig` | `cdp-edit` | 打开配置文件 |
| `Set-ProjectConfig` | `cdp-config` | 切换当前使用的配置文件 |

### WSL / Linux

| 命令 | 说明 |
| --- | --- |
| `cdp` | 打开 fzf 菜单并切换项目 |
| `cdp api` | 按名称或路径快速匹配项目，唯一匹配时直接切换 |
| `cdp doctor` / `cdp-doctor` | 诊断依赖、配置和项目路径 |
| `cdp about` / `cdp version` | 显示版本、配置路径、项目数量和升级命令 |
| `cdp-add` | 添加当前目录或指定路径 |
| `cdp-scan ~/code` / `cdp scan ~/code` | 扫描 Git 仓库并批量导入配置 |
| `cdp-ls` | 列出已启用项目 |
| `cdp-config` | 切换当前使用的配置文件 |

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
cdp-scan E:\Projects
```

自定义配置文件格式：

```json
[
  {
    "name": "my-api",
    "rootPath": "E:/Projects/my-api",
    "enabled": true
  },
  {
    "name": "personal-blog",
    "rootPath": "D:/Code/blog",
    "enabled": true
  }
]
```

建议在 JSON 中使用 `/`，避免 Windows 反斜杠转义。

---

## 性能建议

如果第一次打开 Windows Terminal 后运行 `cdp` 需要等待几秒，通常不是项目数量本身造成的。PowerShell 首次自动加载模块、PATH 中查找 `fzf`，以及 Windows 对 `fzf.exe` 的冷启动检查都可能带来额外延迟。

可以在 PowerShell profile 里固定常用配置和 `fzf` 路径，减少首次交互前的探测：

```powershell
$env:CDP_CONFIG = "$HOME\.cdp\projects.json"
$env:CDP_FZF_PATH = "C:\Users\you\AppData\Local\Microsoft\WinGet\Links\fzf.exe"
```

`CDP_FZF_PATH` 应填写 `(Get-Command fzf).Path` 返回的实际路径。`cdp` 也会在同一个 PowerShell 会话中缓存已解析的项目配置，配置文件被 `cdp-add`、`cdp-scan`、`cdp-rm` 修改后会自动失效并重新读取。

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

# 切换配置文件
cdp-config
```

---

## 和其他工具的区别

| 工具 | 更适合 | 和 `cdp` 的区别 |
| --- | --- | --- |
| `cd` / Tab 补全 | 少量路径、路径很短 | 仍然需要记住目录层级；项目多、路径深时切换成本高 |
| `zoxide` / `autojump` | 按访问频率跳转任意目录 | 依赖历史访问和 frecency 排名，适合“去过的地方”；`cdp` 面向明确的项目清单，新项目可以通过 Project Manager、`cdp-add` 或 `cdp-scan` 直接出现 |
| 纯 `fzf cd` 脚本 | 从扫描目录或 shell 历史中临时选择 | 通常是一次性列表，没有统一配置、健康检查、跨 PowerShell/WSL 的共享项目表 |
| VS Code/Cursor Project Manager | 编辑器内管理项目 | 很适合编辑器内打开项目；`cdp` 把同一份项目清单带到终端和 AI CLI 工作流里 |
| `cdp` | 在终端和 AI CLI 工作流里按项目列表快速切换根目录 | 关注“项目根目录”而不是任意目录，支持 `cdp <query>`、批量 Git 扫描、终端标签同步和配置诊断 |

cdp 的重点不是替代所有跳转工具，而是把“项目根目录切换”这件事做得稳定、可见、可共享。如果你想跳到最近访问过的任意目录，`zoxide` 很好；如果你想把 VS Code/Cursor、PowerShell、WSL 和 Claude Code/Codex/Gemini CLI 都连接到同一份项目列表，`cdp` 更贴近这个场景。

---

## 开发

```powershell
# 导入本地模块
Import-Module ./cdp.psd1 -Force

# 运行诊断
cdp doctor .\examples\projects.json

# 运行测试
Import-Module Pester -MinimumVersion 5.5.0 -Force
Invoke-Pester -Path ./tests -CI
```

CI 覆盖：

- Windows PowerShell 5.1
- PowerShell 7.x
- bash/zsh 脚本语法和 `cdp doctor` smoke test

---

## 路线图

- [x] fzf 项目切换
- [x] VS Code/Cursor Project Manager 配置读取
- [x] 自定义配置文件
- [x] 项目添加、删除、列出、配置切换
- [x] PowerShell + WSL/Linux 支持
- [x] `cdp doctor` 诊断命令
- [x] GitHub Actions 基础 CI
- [ ] 最近访问项目
- [ ] 项目置顶 / 收藏
- [x] `cdp <query>` 非交互快速匹配
- [x] 批量扫描 Git 仓库生成配置
- [ ] 切换项目后自动执行脚本

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

提交信息建议：

```text
Add: 添加项目健康检查命令
Fix: 修复 WSL 路径转换
Docs: 重写快速开始说明
```

---

## 致谢

- [fzf](https://github.com/junegunn/fzf)
- [Project Manager](https://marketplace.visualstudio.com/items?itemName=alefragnani.project-manager)

## License

[MIT](./LICENSE)
