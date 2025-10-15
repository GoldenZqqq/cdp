# ProjSwitch

<div align="center">

**English** | **[简体中文](./README.md)**

*Stop cd-ing around!*

In the era of Vibe Coding, harness AI coding tools with CLI
Claude Code, Codex, Cursor, Windsurf...
**One-key Quick Stop & Switch ⚡**

[![PowerShell Gallery](https://img.shields.io/badge/PowerShell_Gallery-Coming_Soon-blue)](https://www.powershellgallery.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey)](https://github.com/yourusername/ProjSwitch)

</div>

---

## 💡 The Pain Point

**Welcome to 2025, the Vibe Coding Era:**

- 🤖 Claude Code brings AI coding to your terminal
- ⚡ Cursor, Windsurf, Codex and other AI assistants are everywhere
- 🖥️ More developers are returning to the command line, embracing keyboard-first workflows

**But...**

```powershell
# Repeating this every day?
PS C:\> cd E:\Projects\WebApp
PS E:\Projects\WebApp> # Working for hours, then remember another project...
PS E:\Projects\WebApp> cd ..\..\OtherProject\Backend
PS E:\OtherProject\Backend> # Path too long to remember? Need to go back?
PS E:\OtherProject\Backend> cd "E:\Work\Client Projects\Some Long Name\Nested\Folder"
# 😭 Enough! I just want to switch projects!
```

**The problems:**
- ❌ Can't remember project paths, always opening file explorer
- ❌ Deeply nested directories, counting `cd ../../../` until dizzy
- ❌ Tab completion too slow, project names too long
- ❌ Multiple terminal tabs, can't tell which is which project

---

## 🚀 The Solution: ProjSwitch

**One command, solves everything:**

```powershell
PS C:\> cdp

  ┌─ Select project: ────────────────────────────┐
  │ > ProjSwitch                                 │
  │   MyAwesomeApp                               │
  │   ClientProjectAlpha                         │
  │   Backend-API-v2                             │
  │   ...                                        │
  └──────────────────────────────────────────────┘

# Type a few letters, fuzzy match, Enter → Instant switch!
# Terminal tab title auto-updates to project name
```

**That's it.**

---

## ✨ Features

### 🎯 Built for Vibe Coding

- **Fuzzy Search**: Type `web` to match `WebApp`, `WebSite`, `MyWebProject`
- **Keyboard Flow**: Arrow keys + Enter, zero mouse required
- **Visual Context**: Terminal tab auto-shows project name, never get lost
- **Zero Config**: Already have Project Manager plugin? Just use it!

### ⚡ Lightning Fast

- **Instant Launch**: Powered by fzf, millisecond response
- **Smart Cache**: Auto-reads VS Code/Cursor project configs
- **One-Key Switch**: `cdp` - three letters, all projects

### 🛠️ Developer Friendly

- **PowerShell Native**: Compatible with 5.1+ and 7+
- **Auto Install Script**: One command completes installation
- **Highly Extensible**: Customize fzf options and shortcuts

---

## 📦 Installation

### Prerequisites

1. **PowerShell 5.1+** or **PowerShell 7+** (pre-installed on Windows)
2. **fzf** - Fuzzy finder for command line

```powershell
# Install fzf (required)
winget install fzf

# Or use other package managers
choco install fzf
scoop install fzf
```

3. **Project Manager** - VS Code/Cursor extension (for managing project list)
   - [Installation Link](https://marketplace.visualstudio.com/items?itemName=alefragnani.project-manager)

### Method 1: Quick Install (Recommended)

```powershell
# Clone repository
git clone https://github.com/yourusername/ProjSwitch.git
cd ProjSwitch

# Run install script (auto-configure)
.\Install.ps1 -AddToProfile

# Restart terminal or reload config
. $PROFILE
```

### Method 2: PowerShell Gallery (Coming Soon)

```powershell
# Install from official gallery
Install-Module -Name ProjSwitch -Scope CurrentUser
Import-Module ProjSwitch
```

---

## 🎮 Usage

### Basic Usage

```powershell
# Quick project switch
cdp

# Or use full command
Switch-Project
```

**Interactive Flow:**
1. Opens fzf fuzzy search menu
2. Type project name (fuzzy matching supported)
3. Arrow keys to select, Enter to confirm
4. Auto-switches to project directory
5. Terminal tab title auto-updates

### List All Projects

```powershell
Get-ProjectList
```

Displays all enabled projects with their paths.

### Advanced Usage

#### Custom Config Path

```powershell
Switch-Project -ConfigPath "C:\my-projects.json"
```

#### Workflow Integration

```powershell
# Add to PowerShell profile ($PROFILE)

# Switch project and open VS Code
function cdpv { cdp; code . }

# Switch project and show Git status
function cdpg { cdp; git status }

# Switch project and start dev server
function cdpd { cdp; npm run dev }

# Switch project and open in Explorer
function cdpe { cdp; explorer . }
```

---

## 📋 Command List

| Command | Alias | Description |
|---------|-------|-------------|
| `Switch-Project` | `cdp` | Open fzf menu to select and switch project |
| `Get-ProjectList` | - | List all enabled projects with paths |

---

## 🎨 Screenshot Example

```powershell
PS C:\> cdp

# fzf interface example
┌───────────────────────────────────────┐
│ Select project: proj                 │
├───────────────────────────────────────┤
│ > ProjSwitch                         │  ← Current selection
│   ProjectAlpha                       │
│   ProjectManager-Extension           │
└───────────────────────────────────────┘
  3/15  ← Matched 3 out of 15 projects

# After selection
✓ Switched to project: ProjSwitch
PS E:\Learn\ProjSwitch>  # Terminal title → "ProjSwitch"
```

---

## 🔧 Configuration

ProjSwitch directly reads Project Manager config files:

- **Cursor**: `%APPDATA%\Cursor\User\globalStorage\alefragnani.project-manager\projects.json`
- **VS Code**: `%APPDATA%\Code\User\globalStorage\alefragnani.project-manager\projects.json`

**No extra config needed!** Add projects in Project Manager, ProjSwitch auto-detects.

### Customize fzf Style

```powershell
# Add to $PROFILE
$env:FZF_DEFAULT_OPTS = @"
--height=50%
--layout=reverse
--border=rounded
--prompt='🚀 Project: '
--color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9
"@
```

---

## 🐛 Troubleshooting

### "fzf: command not found"

```powershell
# Install fzf
winget install fzf

# Restart terminal
exit  # Then open new terminal
```

### "Project Manager configuration not found"

1. Ensure Project Manager extension is installed
2. Save at least one project in VS Code/Cursor
3. Check config file path is correct

### Module loading failed

```powershell
# Reload config
. $PROFILE

# Or manually import
Import-Module ProjSwitch -Force

# Check if module exists
Get-Module -ListAvailable ProjSwitch
```

---

## 🌟 Why Choose ProjSwitch?

### Comparison with Traditional Methods

| Method | Steps | Time | Pain Points |
|--------|-------|------|-------------|
| **Manual cd** | Remember path → Type → Tab complete | 15-30s | Can't remember paths, deep nesting |
| **File Explorer** | Open explorer → Find folder → Right-click terminal | 20-40s | Breaks keyboard flow, inefficient |
| **ProjSwitch** | `cdp` → Type few letters → Enter | **2-5s** | ✅ No pain points |

### Who is it for?

- ✅ Developers using Claude Code, Cursor and other AI coding tools
- ✅ Full-stack engineers managing multiple projects
- ✅ Efficiency lovers who prefer command line and keyboard flow
- ✅ VS Code/Cursor + Project Manager plugin users

---

## 🗺️ Roadmap

- [x] Core feature: Fuzzy search project switching
- [x] Terminal tab title sync
- [x] Support for Cursor and VS Code
- [ ] Publish to PowerShell Gallery
- [ ] Recent projects quick access
- [ ] Project tags and grouping
- [ ] Project favorites/pinning
- [ ] Auto-execute scripts on switch (e.g., start services)
- [ ] Support for more project management tools

---

## 🤝 Contributing

Contributions welcome! Check out [CONTRIBUTING.md](./CONTRIBUTING.md) for details.

### Quick Start

```powershell
# Fork repository and clone
git clone https://github.com/yourusername/ProjSwitch.git
cd ProjSwitch

# Make changes
# src/ProjSwitch.psm1

# Test locally
Import-Module ./ProjSwitch.psd1 -Force
cdp

# Submit PR
git checkout -b feature/your-feature
git commit -m "Add: your feature"
git push origin feature/your-feature
```

---

## 📄 License

MIT License - See [LICENSE](./LICENSE) for details

---

## 🙏 Acknowledgments

- [fzf](https://github.com/junegunn/fzf) - Powerful fuzzy finder
- [Project Manager](https://marketplace.visualstudio.com/items?itemName=alefragnani.project-manager) - Excellent VS Code project management extension

---

## 💬 Feedback & Support

- 🐛 [Report Bug](https://github.com/yourusername/ProjSwitch/issues)
- 💡 [Feature Request](https://github.com/yourusername/ProjSwitch/issues)
- ⭐ Find it useful? Give it a star!

---

<div align="center">

**Make project switching as natural as breathing 🌊**

Made with ❤️ for Vibe Coders

[⬆ Back to top](#projswitch)

</div>
