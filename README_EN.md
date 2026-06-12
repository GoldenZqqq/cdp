# cdp

<div align="center">

**English** | **[简体中文](./README.md)**

A fast project directory switcher for the Vibe Coding era, built for Claude Code, Codex, Gemini CLI, Cursor, and VS Code users.

`cdp` opens your project list with `fzf`. Type a few letters, press Enter, and your terminal jumps to the project root with the tab title updated.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20WSL%20%7C%20Linux-lightgrey)](https://github.com/GoldenZqqq/cdp)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/cdp.svg)](https://www.powershellgallery.com/packages/cdp)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/cdp.svg)](https://www.powershellgallery.com/packages/cdp)

</div>

---

## Intro Video

![cdp demo: switch projects quickly with fuzzy search](./docs/assets/cdp-demo-short-en.gif)

[Open the English 28-second MP4](./docs/assets/cdp-demo-short-en.mp4) · [中文 GIF](./docs/assets/cdp-demo-short-zh.gif) · [中文 MP4](./docs/assets/cdp-demo-short-zh.mp4)

This short demo shows why project switching becomes a high-frequency pain point in the Vibe Coding era, and how `cdp` turns `fzf`, Project Manager / JSON config, `cdp doctor`, and WSL support into one stable terminal workflow.

Video script, frame spec, and HyperFrames composition:
[docs/video/cdp-intro-script.md](./docs/video/cdp-intro-script.md),
[docs/video/cdp-intro/frame.md](./docs/video/cdp-intro/frame.md),
[docs/video/cdp-intro/index.html](./docs/video/cdp-intro/index.html).

---

## Why cdp

AI CLI tools bring developers back to the terminal, but switching between many projects is still clumsy:

```powershell
PS C:\> cd E:\Work\Client Projects\VeryLongName\backend
PS E:\Work\Client Projects\VeryLongName\backend> cd ..\..\..\SideProjects\tooling
PS E:\SideProjects\tooling> cd C:\Learn\another-project
```

With `cdp`, that becomes:

```powershell
PS C:\> cdp
# type api / blog / cdp
# press Enter and jump to the project root
```

It is built for:

- Developers who work across many repositories
- Users of Claude Code, Codex, Gemini CLI, and other terminal AI tools
- VS Code/Cursor Project Manager users
- People who want one shared project list across Windows PowerShell and WSL/Linux

---

## Quick Start

### Windows PowerShell

```powershell
# 1. Install cdp
Install-Module -Name cdp -Scope CurrentUser

# 2. Install the fzf dependency
winget install fzf

# 3. Import and verify
Import-Module cdp
cdp doctor

# 4. Start switching projects
cdp
```

If you want the install script to handle fzf and profile setup:

```powershell
git clone https://github.com/GoldenZqqq/cdp.git
cd cdp
.\Install.ps1 -AddToProfile
```

### WSL / Linux

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/GoldenZqqq/cdp/main/install-wsl.sh) --auto

source ~/.bashrc  # zsh users: source ~/.zshrc
cdp doctor
cdp
```

---

## 30-Second Usage

```powershell
# Add the current directory as a project
cd E:\Projects\my-api
cdp-add

# Open the project picker from anywhere
cdp

# Check your setup
cdp doctor

# Launch WSL directly into a selected project
cdp -WSL
```

Type a few letters in the fzf menu:

```text
Select project: api

> my-api
  company-admin
  personal-blog
  cdp
```

After selection:

- The current shell changes to the project root
- Windows Terminal and common terminals update the tab title
- WSL mode converts `C:\path` to `/mnt/c/path`

---

## Features

- **Fuzzy project switching**: powered by `fzf`, keyboard-first, no path memorization
- **Project Manager compatible**: reads VS Code/Cursor Project Manager configs
- **Project management commands**: `cdp-add`, `cdp-rm`, `cdp-ls`, `cdp-config`
- **Health checks**: `cdp doctor` checks dependencies, JSON, duplicates, and missing paths
- **Windows + WSL/Linux**: PowerShell and bash/zsh versions share the same config shape
- **Terminal tab titles**: selected project names become visible in terminal tabs

---

## Commands

### PowerShell

| Command | Alias | Description |
| --- | --- | --- |
| `Invoke-Cdp` | `cdp` | Short entry point. Opens the project picker by default |
| `Switch-Project` | - | Opens the fzf menu and switches projects |
| `Switch-Project -WSL` | `cdp -WSL` | Selects a project and launches WSL in that directory |
| `Test-ProjectHealth` | `cdp doctor`, `cdp-doctor` | Diagnoses the cdp environment and config |
| `Add-Project` | `cdp-add` | Adds the current directory or a specific path |
| `Remove-Project` | `cdp-rm` | Removes a project, with interactive selection support |
| `Get-ProjectList` | `cdp-ls` | Lists enabled projects |
| `Edit-ProjectConfig` | `cdp-edit` | Opens the config file |
| `Set-ProjectConfig` | `cdp-config` | Changes the active config file |

### WSL / Linux

| Command | Description |
| --- | --- |
| `cdp` | Opens the fzf menu and switches projects |
| `cdp doctor` / `cdp-doctor` | Diagnoses dependencies, config, and project paths |
| `cdp-add` | Adds the current directory or a specific path |
| `cdp-ls` | Lists enabled projects |
| `cdp-config` | Changes the active config file |

---

## Configuration Sources

cdp discovers project config in this order:

1. `CDP_CONFIG` environment variable
2. The saved choice from `cdp-config`
3. Cursor Project Manager config
4. VS Code Project Manager config
5. Custom config at `~/.cdp/projects.json`

If you already use [Project Manager](https://marketplace.visualstudio.com/items?itemName=alefragnani.project-manager), cdp usually works without extra setup. Otherwise:

```powershell
cd E:\Projects\my-api
cdp-add
```

Custom config format:

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

Using `/` in JSON paths avoids escaping Windows backslashes.

---

## Diagnostics

Start with:

```powershell
cdp doctor
```

It checks:

- Whether `fzf` is available in `PATH`
- Whether `jq` is installed for the bash/zsh version
- Which config file is active
- Whether JSON parsing works
- Whether project fields are complete
- Whether project names are duplicated
- Whether enabled project paths exist

Common fixes:

```powershell
# fzf missing
winget install fzf

# Reload the module
Import-Module cdp -Force

# List current projects
cdp-ls

# Change config file
cdp-config
```

---

## How It Compares

| Tool | Best for |
| --- | --- |
| `cd` / tab completion | A few short paths |
| `zoxide` / `autojump` | Frecency-based jumping to any directory |
| VS Code/Cursor Project Manager | Managing projects inside the editor |
| `cdp` | Fast terminal switching between known project roots |

cdp does not try to replace every directory jumper. It focuses on making project root switching stable, visible, and shareable.

---

## Development

```powershell
# Import the local module
Import-Module ./cdp.psd1 -Force

# Run diagnostics
cdp doctor .\examples\projects.json

# Run tests
Import-Module Pester -MinimumVersion 5.5.0 -Force
Invoke-Pester -Path ./tests -CI
```

CI covers:

- Windows PowerShell 5.1
- PowerShell 7.x
- bash/zsh syntax and `cdp doctor` smoke test

---

## Roadmap

- [x] fzf project switching
- [x] VS Code/Cursor Project Manager config discovery
- [x] Custom config files
- [x] Add, remove, list, and config selection commands
- [x] PowerShell + WSL/Linux support
- [x] `cdp doctor` diagnostics
- [x] GitHub Actions baseline CI
- [ ] Recent projects
- [ ] Pinned / favorite projects
- [ ] `cdp <query>` non-interactive matching
- [ ] Bulk scan Git repositories into config
- [ ] Run scripts after switching projects

---

## Contributing

Issues and PRs are welcome. Please read [CONTRIBUTING.md](./CONTRIBUTING.md) first.

```powershell
git clone https://github.com/GoldenZqqq/cdp.git
cd cdp
git checkout -b feature/your-feature

Import-Module ./cdp.psd1 -Force
Invoke-Pester -Path ./tests -CI
```

Suggested commit messages:

```text
Add: 添加项目健康检查命令
Fix: 修复 WSL 路径转换
Docs: 重写快速开始说明
```

---

## Credits

- [fzf](https://github.com/junegunn/fzf)
- [Project Manager](https://marketplace.visualstudio.com/items?itemName=alefragnani.project-manager)

## License

[MIT](./LICENSE)
