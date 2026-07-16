# cdp

<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="./docs/assets/cdp-logo-dark-transparent.png">
  <img src="./docs/assets/cdp-logo-light-transparent.png" alt="cdp logo" width="320">
</picture>

**English** | **[简体中文](./README_ZH.md)**

**[🌐 Visit the official cdp website](https://goldenzqqq.github.io/cdp/)**

A fast **project workbench** for the Vibe Coding era — one command to see all repo statuses, switch projects, and launch AI CLIs.

`cdp` is more than a project switcher — it knows whether each of your repos is clean, has unpushed commits, and can switch and launch an AI CLI in one move.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20WSL-lightgrey)](https://github.com/GoldenZqqq/cdp)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/cdp.svg)](https://www.powershellgallery.com/packages/cdp)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/cdp.svg)](https://www.powershellgallery.com/packages/cdp)

</div>

---

## Intro Video

[![Watch the cdp v2.0 demo](./docs/assets/cdp-v2-promo.gif)](https://goldenzqqq.github.io/cdp/#proof)

[Watch the HD demo on the official website](https://goldenzqqq.github.io/cdp/#proof) · [Open the v2.0 MP4 directly](https://goldenzqqq.github.io/cdp/assets/cdp-v2-promo.mp4)

This v2.0 demo showcases cdp's core features: `cdp status` multi-project Git dashboard, `cdp api -Open codex` one-step switch and AI CLI launch, `cdp workspace` multi-project workspaces, onEnter environment hooks, intelligent tab completion, and full Windows / macOS / Linux support.

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

Even worse — you have no idea which repos have uncommitted changes:

```bash
# 50 repos — which ones have uncommitted work? Which forgot to push?
cd project1 && git status && cd ../project2 && git status && ...
```

`cdp status` handles it in one command:

```text
$ cdp status
  #  Project       Branch   Status        Sync   Last Commit
  01 my-api        main     x 3 dirty     ^1     2 hours ago
  02 blog          main     + clean              5 days ago
  03 admin-panel   dev      ! 2 untracked        1 hour ago

3 repos need attention
```

It is built for:

- Developers who work across many repositories
- Users of Claude Code, Codex, Gemini CLI, and other terminal AI tools
- VS Code/Cursor Project Manager users
- People who want one shared project list across Windows PowerShell and WSL/Linux
- macOS / Linux native developers (full bash/zsh compatibility)

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

### WSL / Linux / macOS

```bash
# macOS users: install dependencies first
brew install fzf jq

# One-liner install (WSL/Linux/macOS)
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

# First run: create config and optionally scan Git repositories
cdp init E:\Projects

# Open the project picker from anywhere
cdp

# Jump directly when one project matches; fall back to fzf for multiple matches
cdp api

# Enter a project and start an AI CLI or editor
cdp api -Open codex
cdp api -Open code

# Bulk import Git repositories under a directory
cdp-scan E:\Projects

# Check your setup
cdp doctor

# Safely repair missing paths, duplicates, and missing fields
cdp clean
cdp doctor --fix

# Show the current version, config, and upgrade command
cdp version

# Show recently visited projects
cdp recent

# See all repo statuses at a glance
cdp status

# Show only repos that need attention
cdp status --dirty

# Combine filters and use an explicit config
cdp status --dirty '@work' E:\Projects\projects.json

# Create and launch a multi-project workspace
cdp workspace --add fullstack api web --open codex
cdp workspace fullstack

# Tab completion: press Tab after cdp to auto-complete subcommands and project names
cdp s<TAB>  # → status, scan, ...

# Keep frequent projects at the top
cdp pin api
cdp unpin api

# Add short aliases and tags; quote tag queries in PowerShell
cdp alias api backend
cdp tag api work
cdp backend
cdp '@work'

# Launch WSL directly into a selected project
cdp -WSL
```

Type a few letters in the fzf menu:

```text
cdp v2.0.4 | 56 projects | enter to warp | C:\Users\you\.cdp\projects.json
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
- With `-Open`, cdp starts Codex, Claude, Gemini, VS Code, Cursor, or another PATH command from the project root

---

## Real-World Workflows

### Multi-Repository Development

When you maintain a backend, frontend, scripts, and personal projects side by side, start with `cdp-scan E:\Projects` to bulk import Git repositories. After that, run `cdp api`, `cdp admin`, or `cdp blog` from any terminal. One match switches directly; multiple matches fall back to `fzf`.

### AI CLI Workflows

When using Claude Code, Codex, Gemini CLI, or similar tools, the terminal becomes the main workspace. `cdp` keeps project-root switching, terminal tab titles, and a shared project list together, reducing the time spent copying long paths across AI sessions and repositories.

When you want to start an AI CLI immediately, use `cdp api -Open codex`, `cdp web -Open claude`, or `cdp tool -Open gemini`. For editors, use `cdp api -Open code` or `cdp api -Open cursor`.

### Windows + WSL

Windows PowerShell can read Cursor / VS Code Project Manager configs, and the WSL/Linux version can use the same JSON shape. When you need to enter a WSL project from PowerShell, run `cdp -WSL`; Windows paths are converted to `/mnt/c/...` automatically.

---

## Features

- **Multi-project Git dashboard**: `cdp status` shows branch, dirty/untracked count, ahead/behind sync, and last commit time for every project
- **Full cross-platform support**: Windows PowerShell 5.1/7.x + macOS (zsh/bash) + Linux + WSL, all covered by CI
- **Intelligent tab completion**: Press Tab after `cdp` to auto-complete subcommands and project names on PowerShell, bash, and zsh
- **Fuzzy project switching**: powered by `fzf`, keyboard-first, no path memorization
- **Neon TUI**: colored candidates, right-side project preview, and visible path/Git status
- **Fast query jumps**: `cdp api` switches directly on one match, or filters fzf to matching projects
- **AI CLI workspace launching**: `cdp api -Open codex` enters the project root and starts Codex, Claude, Gemini, VS Code, or Cursor
- **Project Manager compatible**: reads VS Code/Cursor Project Manager configs
- **Project management commands**: `cdp-add`, `cdp-rm`, `cdp-ls`, `cdp-config`
- **Bulk Git scanning**: `cdp-scan` imports Git repositories under a directory into your config
- **Recent projects**: `cdp recent` / `cdp-recent` lists projects ordered by last visit
- **Pinned / favorite projects**: `cdp pin api` keeps frequent projects at the top of pickers and lists
- **Tags and short aliases**: `cdp alias api backend` adds a short alias; after `cdp tag api work`, PowerShell can query it with `cdp '@work'`
- **Health checks and repair**: `cdp doctor` checks dependencies, JSON, duplicates, and missing paths; `cdp clean` safely repairs project config
- **Windows + WSL/Linux**: PowerShell and bash/zsh versions share the same config shape
- **Terminal tab titles**: selected project names become visible in terminal tabs

---

## Commands

### PowerShell

| Command | Alias | Description |
| --- | --- | --- |
| `Invoke-Cdp` | `cdp` | Short entry point. Opens the project picker by default |
| `Show-CdpProjectStatus` | `cdp status`, `cdp-status` | Git status dashboard for all projects; supports `--dirty` and `@tag` filters |
| `Invoke-CdpWorkspace` | `cdp workspace`, `cdp ws` | Adds, lists, or launches a multi-project workspace; supports `--open` and `--config` |
| `Invoke-Cdp -Query api` | `cdp api` | Quickly matches by project name or path and switches directly on one match |
| `Invoke-Cdp -Query api -Open codex` | `cdp api -Open codex` | Switches to a project and starts Codex, Claude, Gemini, VS Code, Cursor, or another PATH command |
| `Switch-Project` | - | Opens the fzf menu and switches projects |
| `Switch-Project -Query api` | - | Switches within projects matching `api` |
| `Switch-Project -Query api -Open code` | - | Switches to a project and opens VS Code |
| `Switch-Project -WSL` | `cdp -WSL` | Selects a project and launches WSL in that directory |
| `Test-ProjectHealth` | `cdp doctor`, `cdp-doctor` | Diagnoses the cdp environment and config |
| `Repair-ProjectConfig` | `cdp clean`, `cdp-clean` | Safely repairs config by disabling missing paths, deduping projects, and filling `pinned` |
| `Initialize-Cdp` | `cdp init`, `cdp-init` | First-run setup: creates config, saves the choice, and can scan Git repositories |
| `Add-ProjectAlias` | `cdp alias`, `cdp-alias` | Adds a short project alias for faster matching |
| `Remove-ProjectAlias` | `cdp unalias`, `cdp-unalias` | Removes a project alias |
| `Add-ProjectTag` | `cdp tag`, `cdp-tag` | Adds a project tag; query with `cdp '@work'` in PowerShell |
| `Remove-ProjectTag` | `cdp untag`, `cdp-untag` | Removes a project tag |
| `Show-CdpAbout` | `cdp about`, `cdp version` | Shows the cdp logo, version, config path, project count, and upgrade command |
| `Get-CdpRecentProjects` | `cdp recent`, `cdp-recent` | Lists recently visited projects |
| `Set-ProjectPin` | `cdp pin`, `cdp-pin` | Keeps a project at the top of pickers and lists |
| `Clear-ProjectPin` | `cdp unpin`, `cdp-unpin` | Removes a project pin |
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
| `cdp status` / `cdp-status` | Git status dashboard for all projects; supports `--dirty` and `@tag` filters |
| `cdp workspace` / `cdp ws` | Adds, lists, or launches a multi-project workspace; supports `--open` and `--config` |
| `cdp api` | Quickly matches by project name or path and switches directly on one match |
| `cdp api --open codex` | Switches to a project and starts Codex, Claude, Gemini, VS Code, Cursor, or another PATH command |
| `cdp doctor` / `cdp-doctor` | Diagnoses dependencies, config, and project paths |
| `cdp clean` / `cdp-clean` | Safely repairs config by disabling missing paths, deduping projects, and filling `pinned` |
| `cdp init ~/code` / `cdp-init ~/code` | First-run setup: creates config, saves the choice, and can scan Git repositories |
| `cdp alias api backend` / `cdp-alias api backend` | Adds a short project alias |
| `cdp tag api work` / `cdp-tag api work` | Adds a project tag; query with `cdp @work` in bash/zsh |
| `cdp about` / `cdp version` | Shows the version, config path, project count, and upgrade command |
| `cdp recent` / `cdp-recent` | Lists recently visited projects |
| `cdp pin api` / `cdp-pin api` | Keeps a project at the top of pickers and lists |
| `cdp unpin api` / `cdp-unpin api` | Removes a project pin |
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

`pinned`, `aliases`, and `tags` are optional; old configs without these fields are treated as unpinned and without metadata. Using `/` in JSON paths avoids escaping Windows backslashes.

Recent visits are stored in a separate state file at `~/.cdp/state.json`, so `projects.json` stays compatible with Project Manager. Automation or tests can point `CDP_STATE_PATH` to a temporary state file.

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

# Safely repair config
cdp clean
cdp doctor --fix

# Change config file
cdp-config
```

---

## How It Compares

| Tool | Project Switching | Status Overview | AI CLI Integration | Notes |
| --- | --- | --- | --- | --- |
| `cd` / Tab | Manual path typing | None | None | Costly with deep paths and many projects |
| `zoxide` / `autojump` | Frecency-based jump | None | None | Knows paths, not "projects" |
| Plain `fzf cd` scripts | Scan & select | None | None | One-off lists, no unified config |
| VS Code Project Manager | In-editor switch | None | None | Editor-only |
| **cdp** | **Fuzzy search + query jump** | **`cdp status` full dashboard** | **`-Open codex/claude/gemini`** | Your project workbench in the terminal |

cdp does not try to replace every directory jumper. zoxide excels at jumping to any recently visited directory; cdp knows your project list, each repo's Git status, and can launch an AI CLI in one move.

---

## Development

### Preview and Publish the Website

The website is a dependency-free static GitHub Pages site under `docs/`:

```powershell
python -m http.server 4173 --directory docs
```

Then open `http://localhost:4173`. For the first deployment, open the GitHub repository's **Settings → Pages**, choose **Deploy from a branch**, set the branch to `main`, and select `/docs`; future pushes to `main` will update the site automatically.

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
- Ubuntu bash smoke test
- macOS zsh smoke test

---

## Roadmap

- [x] fzf project switching
- [x] VS Code/Cursor Project Manager config discovery
- [x] Custom config files
- [x] Add, remove, list, and config selection commands
- [x] PowerShell + WSL/Linux support
- [x] `cdp doctor` diagnostics
- [x] GitHub Actions baseline CI
- [x] Recent projects
- [x] Pinned / favorite projects
- [x] `cdp <query>` non-interactive matching
- [x] Bulk scan Git repositories into config
- [x] Start an AI CLI / editor after switching projects
- [x] `cdp doctor --fix` / `cdp clean` for stale paths and duplicates
- [x] `cdp init` first-run setup wizard
- [x] Project tags / aliases
- [x] `cdp status` multi-project Git status dashboard
- [x] Native macOS support (zsh + bash)
- [x] Intelligent tab completion (PowerShell + bash + zsh)

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
