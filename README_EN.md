# cdp

<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./docs/assets/cdp-logo-dark-transparent.png">
  <img src="./docs/assets/cdp-logo-light-transparent.png" alt="cdp logo" width="320">
</picture>

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

If you are comfortable with PowerShell Gallery, install the module and `fzf` directly:

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

For a first-time setup where the script should handle `fzf` and profile configuration, use the source installer:

```powershell
git clone https://github.com/GoldenZqqq/cdp.git
cd cdp
.\Install.ps1 -AddToProfile
```

`Install.ps1` tries `winget`, `scoop`, then `chocolatey` for `fzf`. If the current terminal still cannot find `fzf` after installation, restart PowerShell and run `cdp doctor`.

### WSL / Linux

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/GoldenZqqq/cdp/main/install-wsl.sh) --auto

source ~/.bashrc  # zsh users: source ~/.zshrc
cdp doctor
cdp
```

`--auto` installs `fzf` and `jq` automatically. Without `--auto`, the installer asks before each dependency.

---

## 30-Second Usage

```powershell
# Add the current directory as a project
cd E:\Projects\my-api
cdp-add

# Open the project picker from anywhere
cdp

# Jump directly when one project matches; fall back to fzf for multiple matches
cdp api

# Bulk import Git repositories under a directory
cdp-scan E:\Projects

# Check your setup
cdp doctor

# Show the current version, config, and upgrade command
cdp version

# Launch WSL directly into a selected project
cdp -WSL
```

Type a few letters in the fzf menu:

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

After selection:

- The current shell changes to the project root
- Windows Terminal and common terminals update the tab title
- WSL mode converts `C:\path` to `/mnt/c/path`

---

## Real-World Workflows

### Multi-Repository Development

When you maintain a backend, frontend, scripts, and personal projects side by side, start with `cdp-scan E:\Projects` to bulk import Git repositories. After that, run `cdp api`, `cdp admin`, or `cdp blog` from any terminal. One match switches directly; multiple matches fall back to `fzf`.

### AI CLI Workflows

When using Claude Code, Codex, Gemini CLI, or similar tools, the terminal becomes the main workspace. `cdp` keeps project-root switching, terminal tab titles, and a shared project list together, reducing the time spent copying long paths across AI sessions and repositories.

### Windows + WSL

Windows PowerShell can read Cursor / VS Code Project Manager configs, and the WSL/Linux version can use the same JSON shape. When you need to enter a WSL project from PowerShell, run `cdp -WSL`; Windows paths are converted to `/mnt/c/...` automatically.

---

## Features

- **Fuzzy project switching**: powered by `fzf`, keyboard-first, no path memorization
- **Neon TUI**: colored candidates, right-side project preview, and visible path/Git status
- **Fast query jumps**: `cdp api` switches directly on one match, or filters fzf to matching projects
- **Project Manager compatible**: reads VS Code/Cursor Project Manager configs
- **Project management commands**: `cdp-add`, `cdp-rm`, `cdp-ls`, `cdp-config`
- **Bulk Git scanning**: `cdp-scan` imports Git repositories under a directory into your config
- **Health checks**: `cdp doctor` checks dependencies, JSON, duplicates, and missing paths
- **Windows + WSL/Linux**: PowerShell and bash/zsh versions share the same config shape
- **Terminal tab titles**: selected project names become visible in terminal tabs

---

## Commands

### PowerShell

| Command | Alias | Description |
| --- | --- | --- |
| `Invoke-Cdp` | `cdp` | Short entry point. Opens the project picker by default |
| `Invoke-Cdp -Query api` | `cdp api` | Quickly matches by project name or path and switches directly on one match |
| `Switch-Project` | - | Opens the fzf menu and switches projects |
| `Switch-Project -Query api` | - | Switches within projects matching `api` |
| `Switch-Project -WSL` | `cdp -WSL` | Selects a project and launches WSL in that directory |
| `Test-ProjectHealth` | `cdp doctor`, `cdp-doctor` | Diagnoses the cdp environment and config |
| `Show-CdpAbout` | `cdp about`, `cdp version` | Shows the cdp logo, version, config path, project count, and upgrade command |
| `Add-Project` | `cdp-add` | Adds the current directory or a specific path |
| `Import-GitProjects -RootPath E:\Projects` | `cdp-scan`, `cdp scan` | Scans Git repositories and imports them into the config |
| `Remove-Project` | `cdp-rm` | Removes a project, with interactive selection support |
| `Get-ProjectList` | `cdp-ls` | Lists enabled projects |
| `Edit-ProjectConfig` | `cdp-edit` | Opens the config file |
| `Set-ProjectConfig` | `cdp-config` | Changes the active config file |

### WSL / Linux

| Command | Description |
| --- | --- |
| `cdp` | Opens the fzf menu and switches projects |
| `cdp api` | Quickly matches by project name or path and switches directly on one match |
| `cdp doctor` / `cdp-doctor` | Diagnoses dependencies, config, and project paths |
| `cdp about` / `cdp version` | Shows the version, config path, project count, and upgrade command |
| `cdp-add` | Adds the current directory or a specific path |
| `cdp-scan ~/code` / `cdp scan ~/code` | Scans Git repositories and imports them into the config |
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

# Or scan Git repositories under a directory in one pass
cdp-scan E:\Projects
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

## Performance Tips

If `cdp` takes a few seconds to show the picker right after opening Windows Terminal, the project count is usually not the main cause. PowerShell module autoloading, PATH lookup for `fzf`, and the cold start check for `fzf.exe` can all add latency before the first interactive panel appears.

You can pin the active config and `fzf` executable in your PowerShell profile to reduce first-use discovery work:

```powershell
$env:CDP_CONFIG = "$HOME\.cdp\projects.json"
$env:CDP_FZF_PATH = "C:\Users\you\AppData\Local\Microsoft\WinGet\Links\fzf.exe"
```

Set `CDP_FZF_PATH` to the actual path returned by `(Get-Command fzf).Path`. `cdp` also caches the parsed project config within the current PowerShell session and automatically invalidates that cache after `cdp-add`, `cdp-scan`, or `cdp-rm` changes the config file.

---

## Diagnostics

Start with:

```powershell
cdp doctor
```

It checks:

- Whether `fzf` is available in `PATH`
- Whether a newer `cdp` version is available on PowerShell Gallery
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

# If winget is unavailable
scoop install fzf
choco install fzf -y

# Reload the module
Import-Module cdp -Force

# Upgrade cdp when installed from PowerShell Gallery
Update-Module -Name cdp -Scope CurrentUser -Force

# If it was not installed with Install-Module, or Update-Module cannot find the old install record
Install-Module -Name cdp -Scope CurrentUser -Force -AllowClobber

# List current projects
cdp-ls

# Change config file
cdp-config
```

---

## How It Compares

| Tool | Best for | How it differs from `cdp` |
| --- | --- | --- |
| `cd` / tab completion | A few short paths | You still need to remember directory structure; deep or numerous projects become slower |
| `zoxide` / `autojump` | Frecency-based jumping to any directory | They learn from visited directories and ranking history; `cdp` is driven by an explicit project list, so new projects can appear through Project Manager, `cdp-add`, or `cdp-scan` |
| Plain `fzf cd` scripts | Ad-hoc selection from scanned or historical directories | They are usually one-off lists without shared config, diagnostics, or a project table that works across PowerShell and WSL |
| VS Code/Cursor Project Manager | Managing projects inside the editor | Great inside the editor; `cdp` brings the same project list into terminal and AI CLI workflows |
| `cdp` | Fast terminal switching between known project roots | Focuses on project roots, not arbitrary directories; supports `cdp <query>`, bulk Git scanning, terminal tab titles, and config diagnostics |

cdp does not try to replace every directory jumper. If you want to jump to any recently visited directory, `zoxide` is excellent. If you want VS Code/Cursor, PowerShell, WSL, and Claude Code/Codex/Gemini CLI to share one predictable project list, `cdp` is tuned for that workflow.

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
- [x] `cdp <query>` non-interactive matching
- [x] Bulk scan Git repositories into config
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
