# ProjSwitch

<div align="center">

**[English](./README_EN.md)** | **简体中文**

*别再 cd 来 cd 去了！*

在 Vibe Coding 时代，用 CLI 驾驭 AI 编码工具
Claude Code、Codex、Gemini CLI、Droid...
**一键急停定位，瞬间切换项目 ⚡**

[![PowerShell Gallery](https://img.shields.io/badge/PowerShell_Gallery-Coming_Soon-blue)](https://www.powershellgallery.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey)](https://github.com/yourusername/ProjSwitch)

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

## 🚀 解决方案：ProjSwitch

**一个命令，搞定一切：**

```powershell
PS C:\> cdp

  ┌─ Select project: ────────────────────────────┐
  │ > ProjSwitch                                 │
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
- **智能缓存**：自动读取 VS Code/Cursor 项目配置
- **一键切换**：`cdp` 三个字母，搞定所有项目

### 🛠️ 开发者友好

- **PowerShell 原生**：5.1+ 和 7+ 全兼容
- **自动安装脚本**：一行命令完成安装
- **扩展性强**：可自定义 fzf 选项和快捷命令

---

## 📦 安装

### 前置要求

1. **PowerShell 5.1+** 或 **PowerShell 7+**（Windows 自带）
2. **fzf** - 模糊搜索工具

```powershell
# 安装 fzf（必需）
winget install fzf

# 或使用其他包管理器
choco install fzf
scoop install fzf
```

3. **项目配置**（以下任选其一）
   - **选项 A**：[Project Manager](https://marketplace.visualstudio.com/items?itemName=alefragnani.project-manager) 扩展（VS Code/Cursor）
   - **选项 B**：自定义 JSON 配置文件（见下方示例）

### 方法一：快速安装（推荐）

```powershell
# 克隆仓库
git clone https://github.com/yourusername/ProjSwitch.git
cd ProjSwitch

# 运行安装脚本（自动配置）
.\Install.ps1 -AddToProfile

# 重启终端或重新加载配置
. $PROFILE
```

### 方法二：PowerShell Gallery（即将上线）

```powershell
# 从官方仓库安装
Install-Module -Name ProjSwitch -Scope CurrentUser
Import-Module ProjSwitch
```

---

## 🎮 使用

### 基础用法

```powershell
# 快速切换项目
cdp

# 或使用完整命令
Switch-Project
```

**交互流程：**
1. 打开 fzf 模糊搜索菜单
2. 输入项目名称（支持模糊匹配）
3. 方向键选择，回车确认
4. 自动切换到项目目录
5. 终端标签标题自动更新

### 列出所有项目

```powershell
Get-ProjectList
```

显示所有已启用的项目及其路径。

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

| 命令 | 别名 | 描述 |
|------|------|------|
| `Switch-Project` | `cdp` | 打开 fzf 菜单选择并切换项目 |
| `Get-ProjectList` | - | 列出所有已启用的项目及路径 |

---

## 🎨 截图示例

```powershell
PS C:\> cdp

# fzf 界面示例
┌───────────────────────────────────────┐
│ Select project: proj                 │
├───────────────────────────────────────┤
│ > ProjSwitch                         │  ← 当前选择
│   ProjectAlpha                       │
│   ProjectManager-Extension           │
└───────────────────────────────────────┘
  3/15  ← 匹配 15 个项目中的 3 个

# 选择后
✓ Switched to project: ProjSwitch
PS E:\Learn\ProjSwitch>  # 终端标题 → "ProjSwitch"
```

---

## 🔧 配置

### 选项 1: 使用 Project Manager 扩展（推荐）

ProjSwitch 自动读取 Project Manager 的配置文件：

- **Cursor**: `%APPDATA%\Cursor\User\globalStorage\alefragnani.project-manager\projects.json`
- **VS Code**: `%APPDATA%\Code\User\globalStorage\alefragnani.project-manager\projects.json`

**无需额外配置！** 在 Project Manager 中添加项目，ProjSwitch 自动识别。

### 选项 2: 使用自定义 JSON 配置文件

**不想依赖 VS Code/Cursor？** 你可以创建自己的项目配置文件！

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

**方法 A：每次指定路径**

```powershell
Switch-Project -ConfigPath "C:\my-projects.json"
```

**方法 B：设置默认路径（添加到 $PROFILE）**

```powershell
# 打开 PowerShell 配置文件
notepad $PROFILE

# 添加以下内容
function cdp {
    Switch-Project -ConfigPath "C:\my-projects.json"
}
```

**方法 C：设置环境变量**

```powershell
# 添加到 $PROFILE
$env:PROJSWITCH_CONFIG = "C:\my-projects.json"

# 模块会自动检测此环境变量
```

#### 3. 快速生成配置文件

```powershell
# 使用 PowerShell 快速创建配置模板
@"
[
  {
    "name": "项目名称",
    "rootPath": "C:\\\\项目路径",
    "enabled": true
  }
]
"@ | Out-File -FilePath "C:\my-projects.json" -Encoding UTF8
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

### "fzf: command not found"

```powershell
# 安装 fzf
winget install fzf

# 重启终端
exit  # 然后打开新终端
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
Import-Module ProjSwitch -Force

# 检查模块是否存在
Get-Module -ListAvailable ProjSwitch
```

---

## 🌟 为什么选择 ProjSwitch？

### 对比传统方式

| 方式 | 操作步骤 | 时间 | 痛点 |
|------|---------|------|------|
| **手动 cd** | 记路径 → 输入 → Tab 补全 | 15-30秒 | 记不住路径，层级深 |
| **文件管理器** | 打开资源管理器 → 找文件夹 → 右键终端 | 20-40秒 | 打断键盘流，效率低 |
| **ProjSwitch** | `cdp` → 输入几个字母 → 回车 | **2-5秒** | ✅ 无痛点 |

### 适合谁？

- ✅ 使用 Claude Code、Cursor 等 AI 编程工具的开发者
- ✅ 管理多个项目的全栈工程师
- ✅ 热爱命令行和键盘流的效率党
- ✅ 使用 VS Code/Cursor + Project Manager 插件的用户

---

## 🗺️ 路线图

- [x] 核心功能：模糊搜索切换项目
- [x] 终端标签标题同步
- [x] 支持 Cursor 和 VS Code
- [ ] 发布到 PowerShell Gallery
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
git clone https://github.com/yourusername/ProjSwitch.git
cd ProjSwitch

# 修改代码
# src/ProjSwitch.psm1

# 本地测试
Import-Module ./ProjSwitch.psd1 -Force
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

- 🐛 [提交 Bug](https://github.com/yourusername/ProjSwitch/issues)
- 💡 [功能建议](https://github.com/yourusername/ProjSwitch/issues)
- ⭐ 觉得有用？给个 Star 吧！

---

<div align="center">

**让项目切换像呼吸一样自然 🌊**

Made with ❤️ for Vibe Coders

[⬆ 回到顶部](#projswitch)

</div>
