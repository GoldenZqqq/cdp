# cdp

<div align="center">

**[English](./README_EN.md)** | **简体中文**

*别再 cd 来 cd 去了！*

在 Vibe Coding 时代，用 CLI 驾驭 AI 编码工具
Claude Code、Codex、Gemini CLI、Droid...
**一键急停定位，瞬间切换项目 ⚡**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey)](https://github.com/GoldenZqqq/cdp)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/cdp.svg)](https://www.powershellgallery.com/packages/cdp)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/cdp.svg)](https://www.powershellgallery.com/packages/cdp)

</div>

---

## 💡 痛点？我懂！

**2025 年，Vibe Coding 时代已经到来：**

- 🤖 Claude Code 让你在终端用 AI 写代码
- ⚡ Codex、Gemini CLI、Droid 等 CLI AI 编程助手遍地开花
- 🖥️ 越来越多开发者回归命令行，享受纯键盘流

**但是...**

```powershell
# 每天重复这些？
PS C:\> cd E:\Projects\WebApp
PS E:\Projects\WebApp> # 写了半天，突然想起另一个项目...
PS E:\Projects\WebApp> cd ..\..\OtherProject\Backend
PS E:\OtherProject\Backend> # 路径太长记不住？又要回去？
PS E:\OtherProject\Backend> cd "E:\Work\Client Projects\Some Long Name\Nested\Folder"
# 😭 够了！我只是想切个项目而已！
```

**问题来了：**
- ❌ 项目路径记不住，每次都要翻文件管理器
- ❌ 多层嵌套目录，`cd ../../../` 数到头晕
- ❌ Tab 补全太慢，项目名字太长
- ❌ 终端标签一堆，搞不清哪个是哪个项目

---

## 🚀 解决方案：cdp

**一个命令，搞定一切：**

```powershell
PS C:\> cdp

  ┌─ Select project: ────────────────────────────┐
  │ > cdp                                 │
  │   MyAwesomeApp                               │
  │   ClientProjectAlpha                         │
  │   Backend-API-v2                             │
  │   ...                                        │
  └──────────────────────────────────────────────┘

# 输入几个字母，模糊匹配，回车 → 瞬间切换！
# 终端标签标题自动更新为项目名
```

**就这么简单。**

---

## ✨ 特性

### 🎯 为 Vibe Coding 而生

- **模糊搜索**：输入 `web` 匹配 `WebApp`、`WebSite`、`MyWebProject`
- **键盘流**：方向键 + Enter，零鼠标操作
- **视觉感知**：终端标签自动显示项目名，再也不会迷路
- **零配置**：已有 Project Manager 插件？直接用！

### ⚡ 快如闪电

- **即时启动**：fzf 驱动，毫秒级响应
- **智能配置**：自动读取 Project Manager 插件配置
- **一键切换**：`cdp` 三个字母，搞定所有项目
- **快速管理**：`cdp-add` 添加项目，`cdp-rm` 删除项目，`cdp-ls` 查看所有项目

### 🛠️ 开发者友好

- **PowerShell 原生**：5.1+ 和 7+ 全兼容
- **WSL/Linux 支持**：bash/zsh 版本，与 Windows 版本共享配置
- **自动安装脚本**：一行命令完成安装
- **扩展性强**：可自定义 fzf 选项和快捷命令

---

## 📦 安装

### Windows (PowerShell)

#### 方式 1: 从 PowerShell Gallery 安装（推荐）⭐

**一行命令，开箱即用！**

```powershell
# 安装模块
Install-Module -Name cdp -Scope CurrentUser

# 导入模块
Import-Module cdp

# 立即开始使用！
cdp
```

**优点：**
- ✅ 最简单、最快捷的安装方式
- ✅ 自动管理更新：`Update-Module cdp`
- ✅ PowerShell 官方包管理，安全可靠
- ✅ 无需下载源码，一条命令搞定

> **注意**：安装后需手动安装 fzf 依赖（见下方说明）

---

#### 方式 2: 从源码安装

适合想要自定义或贡献代码的开发者。

#### 前置要求

1. **PowerShell 5.1+** 或 **PowerShell 7+**（Windows 自带）
2. **项目配置**（以下任选其一）
   - **选项 A**：[Project Manager](https://marketplace.visualstudio.com/items?itemName=alefragnani.project-manager) 扩展（VS Code/Cursor）
   - **选项 B**：自定义 JSON 配置文件（见下方示例）

> **注意**：安装脚本会自动检测并安装 fzf（如果未安装），无需手动操作！

#### 安装步骤

```powershell
# 克隆仓库
git clone https://github.com/GoldenZqqq/cdp.git
cd cdp

# 运行安装脚本（自动安装 fzf + 自动配置）
.\Install.ps1 -AddToProfile

# 重启终端或重新加载配置
. $PROFILE
```

**安装脚本会自动：**
- ✅ 检测 fzf 是否已安装
- ✅ 如果未安装，自动使用 winget/scoop/chocolatey 安装 fzf
- ✅ 将模块安装到 PowerShell 模块目录
- ✅ 添加 `cdp` 别名到 PowerShell 配置文件

---

#### 安装 fzf 依赖

cdp 使用 [fzf](https://github.com/junegunn/fzf) 提供模糊搜索功能。

**方式 A：自动安装（推荐）**

如果使用方式 2 从源码安装，安装脚本会自动为你安装 fzf。

**方式 B：手动安装**

```powershell
# 方法 1: 使用 winget（推荐）
winget install fzf

# 方法 2: 使用 scoop
scoop install fzf

# 方法 3: 使用 chocolatey
choco install fzf

# 重启终端后验证
fzf --version
```

---

### WSL / Linux (bash/zsh)

cdp 现在支持在 WSL 和 Linux 环境中使用！**一行命令即可完成安装**。

#### 一键安装（推荐）⭐

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/GoldenZqqq/cdp/main/install-wsl.sh) --auto
```

这一条命令会自动完成：
- ✅ 检测并安装 fzf（如果未安装）
- ✅ 检测并安装 jq（JSON 解析工具）
- ✅ 下载并安装 cdp.sh 到 `~/.local/bin`
- ✅ 添加配置到 `~/.bashrc` 或 `~/.zshrc`
- ✅ 设置正确的 PATH

安装完成后，重启终端或运行：
```bash
source ~/.bashrc  # 对于 bash
source ~/.zshrc   # 对于 zsh
```

#### 手动安装（可选）

如果你想从本地安装：

```bash
# 克隆仓库
git clone https://github.com/GoldenZqqq/cdp.git
cd cdp

# 运行安装脚本
chmod +x install-wsl.sh
./install-wsl.sh --auto  # 自动安装依赖
```

#### WSL/Linux 版本特性

- **路径自动转换**：自动将 Windows 路径（`C:\path`）转换为 WSL 路径（`/mnt/c/path`）
- **共享配置**：可以使用与 PowerShell 版本相同的项目配置文件
- **自动检测配置**：优先级顺序：
  1. `$CDP_CONFIG` 环境变量
  2. `~/.cdp/projects.json`（自定义配置）
  3. Windows Cursor Project Manager 配置（通过 `/mnt/c/...` 访问）
  4. Windows VS Code Project Manager 配置（通过 `/mnt/c/...` 访问）

#### 可用命令（WSL/Linux）

```bash
cdp          # 选择并切换到项目
cdp-add      # 添加当前目录为项目
cdp-ls       # 列出所有项目
```

---

## 🎮 使用

### 🚀 快速切换项目

```powershell
# 使用别名（推荐）
cdp

# 或使用完整命令
Switch-Project

# WSL 场景：直接启动 WSL 并切换到项目目录
cdp -WSL
```

**交互流程：**
1. 打开 fzf 模糊搜索菜单
2. 输入项目名称（支持模糊匹配）
3. 方向键选择，回车确认
4. 自动切换到项目目录
5. 终端标签标题自动更新

**WSL 支持：**
- 使用 `-WSL` 参数可从 PowerShell 直接启动 WSL 并进入项目目录
- Windows 路径自动转换为 WSL 挂载路径（`C:\path` → `/mnt/c/path`）
- 也可以在 WSL 内使用 bash/zsh 版本的 cdp（见上文安装说明）

### ➕ 添加当前项目

```powershell
# 添加当前目录（自动使用文件夹名作为项目名）
cdp-add

# 或使用自定义名称
Add-Project -Name "我的超级项目"

# 添加指定路径
Add-Project -Path "E:\Projects\MyApp" -Name "MyApp"
```

### 📝 列出所有项目

```powershell
# 使用别名（推荐）
cdp-ls

# 或使用完整命令
Get-ProjectList
```

显示所有已启用的项目及其路径，带有索引编号。

### 🗑️ 删除项目

```powershell
# 使用 fzf 交互式选择要删除的项目
cdp-rm

# 或指定项目名称直接删除
Remove-Project -Name "旧项目"
```

### ⚙️ 编辑配置文件

```powershell
# 打开配置文件进行手动编辑
cdp-edit

# 或使用完整命令
Edit-ProjectConfig
```

会自动使用 VS Code/Cursor 或系统默认编辑器打开配置文件。

### 高级用法

#### 自定义配置路径

```powershell
Switch-Project -ConfigPath "C:\my-projects.json"
```

#### 集成到工作流

```powershell
# 添加到 PowerShell 配置文件 ($PROFILE)

# 切换项目并打开 VS Code
function cdpv { cdp; code . }

# 切换项目并显示 Git 状态
function cdpg { cdp; git status }

# 切换项目并启动开发服务器
function cdpd { cdp; npm run dev }

# 切换项目并在资源管理器中打开
function cdpe { cdp; explorer . }
```

---

## 📋 命令列表

### PowerShell 版本

| 命令 | 别名 | 描述 |
|------|------|------|
| `Switch-Project` | `cdp` | 打开 fzf 菜单选择并切换项目 |
| `Switch-Project -WSL` | `cdp -WSL` | 选择项目并启动 WSL 进入该目录 |
| `Add-Project` | `cdp-add` | 添加当前目录或指定路径到项目列表 |
| `Remove-Project` | `cdp-rm` | 删除项目（支持交互式选择） |
| `Get-ProjectList` | `cdp-ls` | 列出所有已启用的项目及路径 |
| `Edit-ProjectConfig` | `cdp-edit` | 打开配置文件进行编辑 |

### WSL/Linux 版本

| 命令 | 描述 |
|------|------|
| `cdp` | 打开 fzf 菜单选择并切换项目 |
| `cdp-add` | 添加当前目录或指定路径到项目列表 |
| `cdp-ls` | 列出所有已启用的项目及路径 |

---

## 🎨 截图示例

```powershell
PS C:\> cdp

# fzf 界面示例
┌───────────────────────────────────────┐
│ Select project: proj                 │
├───────────────────────────────────────┤
│ > cdp                         │  ← 当前选择
│   ProjectAlpha                       │
│   ProjectManager-Extension           │
└───────────────────────────────────────┘
  3/15  ← 匹配 15 个项目中的 3 个

# 选择后
✓ Switched to project: cdp
PS E:\Learn\cdp>  # 终端标题 → "cdp"
```

---

## 🔧 配置

### 配置优先级

cdp 按以下优先级自动查找配置文件：

1. **环境变量** `$env:CDP_CONFIG`（最高优先级）
2. **用户自定义配置** `~/.cdp/projects.json`（首次使用时自动创建）
3. **Cursor Project Manager 插件** `%APPDATA%\Cursor\User\globalStorage\alefragnani.project-manager\projects.json`
4. **VS Code Project Manager 插件** `%APPDATA%\Code\User\globalStorage\alefragnani.project-manager\projects.json`

### 选项 1: 使用默认配置（最简单）

首次使用 `cdp-add` 命令时，会自动创建 `~/.cdp/projects.json` 配置文件：

```powershell
# 在项目目录中
cd E:\Projects\MyApp
cdp-add  # 自动添加到配置并创建文件（如果不存在）
```

### 选项 2: 使用 Project Manager 插件

如果你已安装 [Project Manager](https://marketplace.visualstudio.com/items?itemName=alefragnani.project-manager) 插件（VS Code/Cursor），cdp 会自动读取插件的配置文件。

**无需额外配置！** 在 Project Manager 中添加项目，cdp 自动识别。

### 选项 3: 使用自定义配置文件

#### 1. 创建配置文件

在任意位置创建一个 JSON 文件，例如 `C:\my-projects.json`：

```json
[
  {
    "name": "我的网站项目",
    "rootPath": "E:\\Projects\\MyWebsite",
    "enabled": true
  },
  {
    "name": "后端API",
    "rootPath": "D:\\Work\\Backend-API",
    "enabled": true
  },
  {
    "name": "个人博客",
    "rootPath": "C:\\Code\\PersonalBlog",
    "enabled": true
  },
  {
    "name": "旧项目（已禁用）",
    "rootPath": "E:\\Archive\\OldProject",
    "enabled": false
  }
]
```

**字段说明：**
- `name`: 项目名称（在 fzf 菜单中显示）
- `rootPath`: 项目根目录的绝对路径（**注意：Windows 路径中的 `\` 需要写成 `\\`**）
- `enabled`: 是否启用此项目（`true` 或 `false`）

#### 2. 使用自定义配置

**设置环境变量（推荐）：**

```powershell
# 添加到 $PROFILE
$env:CDP_CONFIG = "C:\my-projects.json"

# 模块会自动检测此环境变量
```

### 自定义 fzf 样式

```powershell
# 添加到 $PROFILE
$env:FZF_DEFAULT_OPTS = @"
--height=50%
--layout=reverse
--border=rounded
--prompt='🚀 项目: '
--color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9
"@
```

---

## 🐛 故障排除

### 安装脚本未能自动安装 fzf

如果安装脚本未能自动安装 fzf，手动安装：

```powershell
# 方法 1: 使用 winget（推荐）
winget install fzf

# 方法 2: 使用 scoop
scoop install fzf

# 方法 3: 使用 chocolatey
choco install fzf

# 重启终端后验证
fzf --version
```

### "未找到 Project Manager 配置"

1. 确保已安装 Project Manager 扩展
2. 在 VS Code/Cursor 中保存至少一个项目
3. 检查配置文件路径是否正确

### 模块加载失败

```powershell
# 重新加载配置
. $PROFILE

# 或手动导入
Import-Module cdp -Force

# 检查模块是否存在
Get-Module -ListAvailable cdp
```

---

## 🌟 为什么选择 cdp？

### 对比传统方式

| 方式 | 操作步骤 | 时间 | 痛点 |
|------|---------|------|------|
| **手动 cd** | 记路径 → 输入 → Tab 补全 | 15-30秒 | 记不住路径，层级深 |
| **文件管理器** | 打开资源管理器 → 找文件夹 → 右键终端 | 20-40秒 | 打断键盘流，效率低 |
| **cdp** | `cdp` → 输入几个字母 → 回车 | **2-5秒** | ✅ 无痛点 |

### 适合谁？

- ✅ 使用 Claude Code、Cursor 等 AI 编程工具的开发者
- ✅ 管理多个项目的全栈工程师
- ✅ 热爱命令行和键盘流的效率党
- ✅ 使用 VS Code/Cursor + Project Manager 插件的用户

---

## 🗺️ 路线图

- [x] 核心功能：模糊搜索切换项目
- [x] 终端标签标题同步
- [x] 支持 Cursor 和 VS Code Project Manager 插件
- [x] 安装脚本自动安装 fzf 依赖
- [x] 快速添加/删除/列出项目命令
- [x] 自动创建默认配置文件
- [x] WSL/Linux 支持（bash/zsh 版本）
- [x] PowerShell 直接启动 WSL 并切换项目
- [ ] 最近访问项目快速切换
- [ ] 项目标签和分组功能
- [ ] 项目收藏/置顶
- [ ] 切换时自动执行脚本（如启动服务）
- [ ] 支持更多项目管理工具

---

## 🤝 贡献

欢迎贡献代码！请查看 [CONTRIBUTING.md](./CONTRIBUTING.md) 了解详情。

### 快速开始

```powershell
# Fork 仓库并克隆
git clone https://github.com/GoldenZqqq/cdp.git
cd cdp

# 修改代码
# src/cdp.psm1

# 本地测试
Import-Module ./cdp.psd1 -Force
cdp

# 提交 PR
git checkout -b feature/your-feature
git commit -m "Add: your feature"
git push origin feature/your-feature
```

---

## 📄 许可证

MIT License - 详见 [LICENSE](./LICENSE)

---

## 🙏 致谢

- [fzf](https://github.com/junegunn/fzf) - 强大的模糊搜索工具
- [Project Manager](https://marketplace.visualstudio.com/items?itemName=alefragnani.project-manager) - 优秀的 VS Code 项目管理扩展

---

## 💬 反馈与支持

- 🐛 [提交 Bug](https://github.com/GoldenZqqq/cdp/issues)
- 💡 [功能建议](https://github.com/GoldenZqqq/cdp/issues)
- ⭐ 觉得有用？给个 Star 吧！

---

<div align="center">

**让项目切换像呼吸一样自然 🌊**

Made with ❤️ for Vibe Coders

[⬆ 回到顶部](#cdp)

</div>
