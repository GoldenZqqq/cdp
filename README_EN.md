# cdp

<div align="center">

**English** | **[简体中文](./README.md)**

*Stop cd-ing around!*

In the era of Vibe Coding, harness AI coding tools with CLI
Claude Code, Codex, Gemini CLI, Droid...
**One-key Quick Stop & Switch ⚡**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows-lightgrey)](https://github.com/GoldenZqqq/cdp)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/cdp.svg)](https://www.powershellgallery.com/packages/cdp)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/cdp.svg)](https://www.powershellgallery.com/packages/cdp)

</div>

---

## 💡 The Pain Point

**Welcome to 2025, the Vibe Coding Era:**

- 🤖 Claude Code brings AI coding to your terminal
- ⚡ Codex, Gemini CLI, Droid and other CLI AI assistants are everywhere
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

## 🚀 The Solution: cdp

**One command, solves everything:**

```powershell
PS C:\> cdp

  ┌─ Select project: ────────────────────────────┐
  │ > cdp                                 │
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
- **Smart Config**: Auto-reads Project Manager plugin configuration
- **One-Key Switch**: `cdp` - three letters, all projects
- **Quick Management**: `cdp-add` to add projects, `cdp-rm` to remove, `cdp-ls` to list all

### 🛠️ Developer Friendly

- **PowerShell Native**: Compatible with 5.1+ and 7+
- **WSL/Linux Support**: bash/zsh version, shares config with Windows version
- **Auto Install Script**: One command completes installation
- **Highly Extensible**: Customize fzf options and shortcuts

---

## 📦 Installation

### Windows (PowerShell)

#### Method 1: Install from PowerShell Gallery (Recommended) ⭐

**One command, ready to use!**

```powershell
# Install the module
Install-Module -Name cdp -Scope CurrentUser

# Import the module
Import-Module cdp

# Start using it immediately!
cdp
```

**Benefits:**
- ✅ Simplest and fastest installation method
- ✅ Auto-managed updates: `Update-Module cdp`
- ✅ Official PowerShell package management, safe and reliable
- ✅ No need to download source code, one command does it all

> **Note**: After installation, you'll need to manually install the fzf dependency (see instructions below)

---

#### Method 2: Install from Source

For developers who want to customize or contribute code.

#### Prerequisites

1. **PowerShell 5.1+** or **PowerShell 7+** (pre-installed on Windows)
2. **Project Configuration** (choose one)
   - **Option A**: [Project Manager](https://marketplace.visualstudio.com/items?itemName=alefragnani.project-manager) extension (VS Code/Cursor)
   - **Option B**: Custom JSON config file (see example below)

> **Note**: The install script will automatically detect and install fzf if not already installed. No manual setup required!

#### Installation Steps

```powershell
# Clone repository
git clone https://github.com/GoldenZqqq/cdp.git
cd cdp

# Run install script (auto-install fzf + auto-configure)
.\Install.ps1 -AddToProfile

# Restart terminal or reload config
. $PROFILE
```

**The install script automatically:**
- ✅ Detects if fzf is installed
- ✅ If not installed, automatically installs fzf using winget/scoop/chocolatey
- ✅ Installs module to PowerShell modules directory
- ✅ Adds `cdp` alias to your PowerShell profile

---

#### Installing fzf Dependency

cdp uses [fzf](https://github.com/junegunn/fzf) to provide fuzzy search functionality.

**Method A: Automatic Installation (Recommended)**

If you install from source using Method 2, the install script will automatically install fzf for you.

**Method B: Manual Installation**

```powershell
# Option 1: Using winget (recommended)
winget install fzf

# Option 2: Using scoop
scoop install fzf

# Option 3: Using chocolatey
choco install fzf

# Verify after restarting terminal
fzf --version
```

---

### WSL / Linux (bash/zsh)

cdp now supports WSL and Linux environments! **One command to install everything**.

#### One-liner Install (Recommended) ⭐

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/GoldenZqqq/cdp/main/install-wsl.sh) --auto
```

This single command automatically:
- ✅ Detects and installs fzf (if not already installed)
- ✅ Detects and installs jq (JSON parsing tool)
- ✅ Downloads and installs cdp.sh to `~/.local/bin`
- ✅ Adds configuration to `~/.bashrc` or `~/.zshrc`
- ✅ Sets up correct PATH

After installation, restart your terminal or run:
```bash
source ~/.bashrc  # For bash
source ~/.zshrc   # For zsh
```

#### Manual Install (Optional)

If you want to install from a local copy:

```bash
# Clone the repository
git clone https://github.com/GoldenZqqq/cdp.git
cd cdp

# Run install script
chmod +x install-wsl.sh
./install-wsl.sh --auto  # Auto-install dependencies
```

#### WSL/Linux Version Features

- **Automatic Path Conversion**: Automatically converts Windows paths (`C:\path`) to WSL paths (`/mnt/c/path`)
- **Shared Configuration**: Can use the same project config file as the PowerShell version
- **Auto-detect Config**: Priority order:
  1. `$CDP_CONFIG` environment variable
  2. `~/.cdp/projects.json` (custom config)
  3. Windows Cursor Project Manager config (via `/mnt/c/...`)
  4. Windows VS Code Project Manager config (via `/mnt/c/...`)

#### Available Commands (WSL/Linux)

```bash
cdp          # Select and switch to a project
cdp-add      # Add current directory as a project
cdp-ls       # List all projects
```

---

## 🎮 Usage

### 🚀 Quick Project Switch

```powershell
# Use alias (recommended)
cdp

# Or use full command
Switch-Project

# WSL scenario: Launch WSL and switch to project directory
cdp -WSL
```

**Interactive Flow:**
1. Opens fzf fuzzy search menu
2. Type project name (fuzzy matching supported)
3. Arrow keys to select, Enter to confirm
4. Auto-switches to project directory
5. Terminal tab title auto-updates

**WSL Support:**
- Use `-WSL` parameter to launch WSL from PowerShell and enter project directory
- Windows paths are automatically converted to WSL mount paths (`C:\path` → `/mnt/c/path`)
- You can also use the bash/zsh version of cdp inside WSL (see installation instructions above)

### ➕ Add Current Project

```powershell
# Add current directory (auto-uses folder name as project name)
cdp-add

# Or use custom name
Add-Project -Name "My Awesome Project"

# Add specific path
Add-Project -Path "E:\Projects\MyApp" -Name "MyApp"
```

### 📝 List All Projects

```powershell
# Use alias (recommended)
cdp-ls

# Or use full command
Get-ProjectList
```

Displays all enabled projects with their paths, with index numbers.

### 🗑️ Remove Project

```powershell
# Use fzf interactive selection to remove project
cdp-rm

# Or specify project name directly
Remove-Project -Name "Old Project"
```

### ⚙️ Edit Config File

```powershell
# Open config file for manual editing
cdp-edit

# Or use full command
Edit-ProjectConfig
```

Automatically opens config file with VS Code/Cursor or system default editor.

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

### PowerShell Version

| Command | Alias | Description |
|---------|-------|-------------|
| `Switch-Project` | `cdp` | Open fzf menu to select and switch project |
| `Switch-Project -WSL` | `cdp -WSL` | Select project and launch WSL in that directory |
| `Add-Project` | `cdp-add` | Add current directory or specified path to project list |
| `Remove-Project` | `cdp-rm` | Remove project (supports interactive selection) |
| `Get-ProjectList` | `cdp-ls` | List all enabled projects with paths |
| `Edit-ProjectConfig` | `cdp-edit` | Open config file for editing |

### WSL/Linux Version

| Command | Description |
|---------|-------------|
| `cdp` | Open fzf menu to select and switch project |
| `cdp-add` | Add current directory or specified path to project list |
| `cdp-ls` | List all enabled projects with paths |

---

## 🎨 Screenshot Example

```powershell
PS C:\> cdp

# fzf interface example
┌───────────────────────────────────────┐
│ Select project: proj                 │
├───────────────────────────────────────┤
│ > cdp                         │  ← Current selection
│   ProjectAlpha                       │
│   ProjectManager-Extension           │
└───────────────────────────────────────┘
  3/15  ← Matched 3 out of 15 projects

# After selection
✓ Switched to project: cdp
PS E:\Learn\cdp>  # Terminal title → "cdp"
```

---

## 🔧 Configuration

### Configuration Priority

cdp automatically searches for config files in this priority order:

1. **Environment variable** `$env:CDP_CONFIG` (highest priority)
2. **User custom config** `~/.cdp/projects.json` (auto-created on first use)
3. **Cursor Project Manager plugin** `%APPDATA%\Cursor\User\globalStorage\alefragnani.project-manager\projects.json`
4. **VS Code Project Manager plugin** `%APPDATA%\Code\User\globalStorage\alefragnani.project-manager\projects.json`

### Option 1: Use Default Config (Simplest)

When you first use the `cdp-add` command, it will automatically create `~/.cdp/projects.json`:

```powershell
# In your project directory
cd E:\Projects\MyApp
cdp-add  # Automatically adds to config and creates file (if doesn't exist)
```

### Option 2: Use Project Manager Plugin

If you have [Project Manager](https://marketplace.visualstudio.com/items?itemName=alefragnani.project-manager) plugin installed (VS Code/Cursor), cdp will automatically read the plugin's config file.

**No extra config needed!** Add projects in Project Manager, cdp auto-detects.

### Option 3: Use Custom Config File

#### 1. Create Config File

Create a JSON file anywhere, e.g., `C:\my-projects.json`:

```json
[
  {
    "name": "My Website",
    "rootPath": "E:/Projects/MyWebsite",
    "enabled": true
  },
  {
    "name": "Backend API",
    "rootPath": "D:/Work/Backend-API",
    "enabled": true
  },
  {
    "name": "Personal Blog",
    "rootPath": "C:/Code/PersonalBlog",
    "enabled": true
  },
  {
    "name": "Old Project (Disabled)",
    "rootPath": "E:/Archive/OldProject",
    "enabled": false
  }
]
```

**Field Descriptions:**
- `name`: Project display name (shown in fzf menu)
- `rootPath`: Absolute path to project root (**Use `/` or `\\` for Windows paths**)
- `enabled`: Whether to enable this project (`true` or `false`)

#### 2. Use Custom Config

**Set environment variable (recommended):**

```powershell
# Add to $PROFILE
$env:CDP_CONFIG = "C:\my-projects.json"

# Module will auto-detect this environment variable
```

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

### Install script failed to auto-install fzf

If the install script couldn't automatically install fzf, install manually:

```powershell
# Method 1: Using winget (recommended)
winget install fzf

# Method 2: Using scoop
scoop install fzf

# Method 3: Using chocolatey
choco install fzf

# Verify after restarting terminal
fzf --version
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
Import-Module cdp -Force

# Check if module exists
Get-Module -ListAvailable cdp
```

---

## 🌟 Why Choose cdp?

### Comparison with Traditional Methods

| Method | Steps | Time | Pain Points |
|--------|-------|------|-------------|
| **Manual cd** | Remember path → Type → Tab complete | 15-30s | Can't remember paths, deep nesting |
| **File Explorer** | Open explorer → Find folder → Right-click terminal | 20-40s | Breaks keyboard flow, inefficient |
| **cdp** | `cdp` → Type few letters → Enter | **2-5s** | ✅ No pain points |

### Who is it for?

- ✅ Developers using Claude Code, Cursor and other AI coding tools
- ✅ Full-stack engineers managing multiple projects
- ✅ Efficiency lovers who prefer command line and keyboard flow
- ✅ VS Code/Cursor + Project Manager plugin users

---

## 🗺️ Roadmap

- [x] Core feature: Fuzzy search project switching
- [x] Terminal tab title sync
- [x] Support for Cursor and VS Code Project Manager plugin
- [x] Install script auto-installs fzf dependency
- [x] Quick add/remove/list project commands
- [x] Auto-create default config file
- [x] WSL/Linux support (bash/zsh version)
- [x] PowerShell direct launch WSL and switch project
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
git clone https://github.com/GoldenZqqq/cdp.git
cd cdp

# Make changes
# src/cdp.psm1

# Test locally
Import-Module ./cdp.psd1 -Force
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

- 🐛 [Report Bug](https://github.com/GoldenZqqq/cdp/issues)
- 💡 [Feature Request](https://github.com/GoldenZqqq/cdp/issues)
- ⭐ Find it useful? Give it a star!

---

<div align="center">

**Make project switching as natural as breathing 🌊**

Made with ❤️ for Vibe Coders

[⬆ Back to top](#cdp)

</div>
