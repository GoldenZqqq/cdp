# v2.0.5 安全热修设计

## Boundaries

本任务保持 `projects.json`、`state.json` 和 `workspaces.json` 结构不变，只收紧执行和变更入口。PowerShell 与 shell 各自实现适配器，但共享命令语义和回归 fixture。

## Hook Policy

1. 先处理结构化 `env`，逐个验证 key 后设置当前进程环境。
2. 从 hook 对象提取当前平台命令，或识别 legacy string hook。
3. 未收到当前次 `AllowHook` 时只输出固定提示，不输出命令正文。
4. 收到授权后在现有 shell 进程执行，以保留环境激活语义；异常只输出固定 warning。

`--allow-hook` 不持久化。v2.1.0 将以配置规范化路径与命令指纹建立持久信任。

## Mutation Policy

- PowerShell `Show-CdpProjectStatus` 声明 `SupportsShouldProcess` 和 High `ConfirmImpact`。
- parser 将 `--dry-run` 映射到 `WhatIf`，将 `--yes` 映射到 `Confirm:$false`。
- shell action 在扫描和展示目标后：dry-run 返回成功；无 `--yes` 返回非零并提示；有 `--yes` 才执行。
- 单项目失败不得被渲染成成功；push 最终状态保留逐项目结果。

## Launcher Policy

launcher 是一个可执行文件 token，而不是命令行。允许字母、数字、点、下划线、连字符以及显式路径分隔符；拒绝空白、引号、分号、管道、重定向和控制字符。

- Windows Terminal：`wt.exe ... -- <command> <args...>`。
- tmux：`tmux new-session/new-window ... <command> <args...>`。
- 无 launcher 时保持现有终端启动行为。

## Installer Integrity

远程安装器使用 `CDP_INSTALL_REF`（默认 `v2.0.5`）构建 raw URL。下载到同目录临时文件，使用系统可用的 `sha256sum`、`shasum` 或 `openssl` 校验，再原子替换目标。发布前从最终 `src/cdp.sh` 计算摘要。

Scoop 不直接下载包含 manifest 自身的 GitHub tag archive，避免 manifest hash 自引用循环。`scripts/New-ScoopPackage.sh` 生成只包含 `cdp.psd1`、`Install.ps1`、安装 helper 和 `src/` 的独立 tar.gz；GitHub Release 上传该资产后，将其摘要写入 Scoop manifest。

## Compatibility

- 旧配置继续解析，合法 `env` 无需迁移。
- 旧命令 hook 不再静默执行，这是安全行为变更；用户必须显式授权当前一次切换。
- 自定义 launcher 仍支持 PATH 中的单一命令，不再支持把参数嵌入 launcher 字符串。
