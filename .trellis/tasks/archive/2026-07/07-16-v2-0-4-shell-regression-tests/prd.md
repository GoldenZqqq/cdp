# 补齐 bash zsh v2 回归测试

## Goal

把当前 CI 中的长内联 smoke 转换为仓库内可本地复用的 shell 回归测试。

## Background

- `tests/cdp.Cli.Tests.sh` 与 `tests/cdp.Status.Tests.sh` 已提供 bash 专项回归，但未覆盖完整 v2 switch/hook/completion 生命周期。
- Ubuntu 与 macOS CI 仍各自维护一段长内联 smoke，场景已开始漂移：Ubuntu 覆盖 launcher/init/scan，zsh 只覆盖其中一部分。
- 新共享入口必须可由 `bash <script>` 与 `zsh <script>` 直接执行，不依赖调用者预先 source helper。

## Requirements

- 测试 status、workspace、hook、completion、Windows 路径转换和参数组合。
- 测试脚本必须同时可由 Ubuntu bash 与 macOS zsh CI 调用。
- 外部命令通过临时 fake PATH 或 dry-run 隔离，不 push、不打开 tmux/GUI。
- CI 只负责安装依赖并调用仓库测试入口。

## Technical Notes

- 新增 `tests/cdp.Shell.V2.Tests.sh`，只使用 bash/zsh 共同支持的 shell 结构；completion 断言按当前 shell 适配器分支执行。
- jq/fzf/git 缺失通过子 shell 的临时空 `PATH` 和受控 function shim 验证，不修改系统安装。
- workspace 使用临时 fake `tmux` 记录参数；project launcher 使用 `CDP_OPEN_DRY_RUN=1`。
- hook 只运行 builtin `export` 或预期失败的 `false`，不执行外部命令。
- Windows path 使用现有转换函数与临时映射验证，不要求 CI 真实挂载 Windows drive。

## Out of Scope

- onEnter 信任/确认模型；由 v2.1.0 hook task 处理。
- shell 模块拆分；由 v2.1.0 modularization task 处理。
- 替换现有 CLI/status 专项脚本；本任务只移除 CI 内联复制并补共享入口。

## Acceptance Criteria

- [x] 新共享入口由 bash 直接执行并通过。
- [x] 同一共享入口由 zsh 直接执行并通过。
- [x] status、workspace、hook、completion、Windows path 与参数组合均有确定断言。
- [x] jq/fzf/git 缺失和 missing/invalid config 有确定断言。
- [x] CI 中不再复制主要 shell smoke 逻辑。

## Verification Evidence

- PowerShell 7：Pester `48/48`。
- Windows PowerShell 5.1：Pester `48/48`。
- PSScriptAnalyzer：Severity Error `0`。
- Git Bash：CLI parser、status、共享 shell v2 回归全部通过。
- WSL Arch：bash 与 zsh 共享 shell v2 回归全部通过；bash/zsh syntax 全部通过。
- CI：Ubuntu/macOS 的内联 smoke 已替换为同一仓库测试入口。
- Workflow YAML：本地解析通过。
- `git diff --check`：通过，仅保留既有 line-ending 提示。
- Trellis：`task.py validate` 通过，implement/check context 均有效。
