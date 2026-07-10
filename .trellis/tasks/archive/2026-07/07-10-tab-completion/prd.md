# P1: Tab 补全 (PowerShell + bash/zsh)

## Goal

为 cdp 添加智能 Tab 补全，让用户输入 `cdp <TAB>` 时自动补全子命令和项目名。这是成熟 CLI 工具的标志性特征。

## Requirements

### PowerShell Tab 补全

使用 `Register-ArgumentCompleter` 实现：
- `cdp <TAB>` — 补全子命令（doctor, status, recent, pin, unpin, alias, tag, scan, init, clean, about）
- `cdp <TAB>` — 同时补全项目名（从配置文件读取 enabled 项目的 name）
- `cdp pin <TAB>` — 只补全项目名
- `cdp tag <TAB>` — 补全项目名
- `cdp -Open <TAB>` — 补全常用启动器（code, cursor, codex, claude, gemini）
- 在 module 加载时自动注册，无需用户手动配置

### bash/zsh 补全

生成补全脚本：
- bash: 输出到 `completions/cdp.bash` 或通过 `cdp --completions bash` 动态生成
- zsh: 输出到 `completions/_cdp` 或通过 `cdp --completions zsh` 动态生成
- `cdp <TAB>` — 子命令 + 项目名
- `cdp --open <TAB>` — 常用启动器
- 安装脚本自动将补全脚本放到正确位置

### 性能

- 补全响应时间 < 200ms
- 利用已有的配置缓存读取项目列表

## Implementation Hints

### PowerShell

```powershell
Register-ArgumentCompleter -CommandName Invoke-Cdp -ParameterName Command -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    # 返回子命令 + 项目名
}
```

### bash

```bash
_cdp_completions() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local subcommands="doctor status recent pin unpin alias tag scan init clean about"
    local projects=$(cdp --list-names 2>/dev/null)
    COMPREPLY=($(compgen -W "$subcommands $projects" -- "$cur"))
}
complete -F _cdp_completions cdp
```

## Acceptance Criteria

- [ ] PowerShell 中 `cdp <TAB>` 能补全子命令和项目名
- [ ] PowerShell 中 `cdp -Open <TAB>` 能补全启动器名称
- [ ] bash 中 `cdp <TAB>` 能补全子命令和项目名
- [ ] zsh 中 `cdp <TAB>` 能补全子命令和项目名
- [ ] 补全脚本随 module/source 自动加载
- [ ] 补全响应 < 200ms
- [ ] 添加 `cdp --completions <shell>` 输出补全脚本（bash/zsh）
