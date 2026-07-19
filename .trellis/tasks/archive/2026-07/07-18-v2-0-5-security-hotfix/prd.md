# v2.0.5 安全与安装完整性热修

## Goal

阻断未信任 hook 执行、增加变更操作确认、修复 launcher 参数注入风险，并将 shell/Scoop 安装来源固定到可验证 release。

## Background

- PowerShell `onEnter` 当前通过 `Invoke-Expression` 执行字符串或 `powershell` 字段。
- bash/zsh `onEnter` 当前通过 `eval` 执行字符串或 `bash` 字段。
- 自动发现的 Cursor/VS Code Project Manager 配置与 cdp 自有配置共享同一读取边界。
- `status --fix` 会覆盖项目配置，`status --push` 会对所有 ahead 仓库直接执行 push。
- PowerShell workspace launcher 拼接 `pwsh -Command` 字符串；tmux workspace 通过 `send-keys` 执行配置中的 launcher 文本。
- shell 一键安装器默认下载 `main`，Scoop manifest 尚未校验归档 hash。

## Requirements

- R1：结构化 `onEnter.env` 默认可应用，但环境变量名称必须匹配 `[A-Za-z_][A-Za-z0-9_]*`；非法名称只产生警告。
- R2：字符串 hook、`onEnter.powershell` 和 `onEnter.bash` 默认不执行；仅当前次切换显式使用 `-AllowHook` / `--allow-hook` 时执行。
- R3：hook 失败保持隔离，不阻止目录切换；提示不得回显完整命令。
- R4：`status --fix` 与 `status --push` 支持 dry-run，实际变更要求显式确认；自动化可使用 `--yes`。
- R5：PowerShell 变更入口使用 `ShouldProcess`；shell 未提供 `--yes` 时不得在非交互式路径直接变更或 push。
- R6：workspace launcher 只接受单一可执行文件名或安全路径，不接受内联参数或 shell 元字符；Windows Terminal/tmux 通过 argv 直接启动。
- R7：shell 远程安装默认固定到 `v2.0.5` tag，下载 `cdp.sh` 后校验 SHA-256；校验失败不得覆盖现有安装。
- R8：Scoop 使用不包含 manifest 自身的独立 `cdp-v2.0.5.tar.gz` release asset，并写入真实 SHA-256，禁止保留 `hash: skip`。
- R9：PowerShell 5.1/7、bash、zsh 的既有无 hook/只读行为保持兼容；用户可见行为同步到英文 README 和中文镜像。
- R10：所有版本镜像、ReleaseNotes、CHANGELOG、PROGRESS 和发布元数据同步到 2.0.5。

## Acceptance Criteria

- [x] 未显式授权时，legacy/string/PowerShell/bash hook 均不执行，结构化合法 env 正常生效。
- [x] 显式 `-AllowHook` / `--allow-hook` 只授权当前一次切换，hook 异常被隔离且不泄露命令正文。
- [x] 非法 env key 不写入进程环境，并产生可测试警告。
- [x] status fix/push 的默认、dry-run、yes 和失败路径在两端都有回归测试。
- [x] workspace 带空格项目路径仍能启动，launcher 元字符输入被拒绝，测试断言不存在 `pwsh -Command`/`tmux send-keys` 注入路径。
- [x] tag 固定安装、下载摘要校验、Scoop package hash 和负向漂移检查通过。
- [x] README/README_ZH、CHANGELOG、PROGRESS、manifest 与运行时版本一致。
- [x] PowerShell 7 Pester、PSScriptAnalyzer、bash/zsh 回归、shell 语法、release metadata 和 `git diff --check` 全部通过；PowerShell 5.1 需在 Windows CI 复核。

## Out of Scope

- 持久化 hook trust store 与 `hook list/trust/revoke` 留在 v2.1.0 完整信任模型任务。
- 全部配置变更命令的统一原子写入和并发冲突检测留在 v2.1.0 持久化任务。
- 不在本任务中重写 Git 历史或迁移现有媒体资产。
