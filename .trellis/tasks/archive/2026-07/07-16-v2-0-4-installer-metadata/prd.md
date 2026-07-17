# 修复安装器与发布元数据一致性

## Goal

保证 PowerShell 5.1/7 都能从脚本安装后发现模块，并让发布元数据漂移在 CI 中立即失败。

## Background

- `Install.ps1:120-127` 通过目录是否存在猜测 PowerShell edition，PowerShell 7 与 Windows PowerShell 5.1 可能选到彼此的模块目录。
- `Install.ps1:157-161` 接受任意同名旧模块作为安装成功证据，没有核对本次目标目录与版本。
- `scoop/cdp.json:2-8` 仍固定为 1.8.0，并复制了一套与根安装器相同的目录猜测逻辑。
- `PROGRESS.md:21-23` 仍把 1.8.0 写成当前构建目标，不能代表当前发布状态。
- 2026-07-17 只读核验显示 GitHub Release 与 PowerShell Gallery 最新公开版本均为 2.0.3；2.0.4 是当前本地发布目标，实际 push/tag/发布属于后续 release 任务。

## Requirements

- CurrentUser/AllUsers 安装目录必须同时基于当前 `PSEdition` 与实际 `PSModulePath` 选择；缺少对应可发现路径时明确失败。
- 安装验证必须核对本次目标 `ModuleBase` 与 manifest version，而不是任意同名旧模块。
- Scoop 必须更新为 2.0.4，并调用根安装器，禁止继续复制目录选择逻辑；Scoop 已声明 `fzf` 依赖，不得触发嵌套依赖安装。
- `cdp.psd1` 是唯一 canonical version；建立 PowerShell 5.1/7 兼容脚本核对 manifest、ReleaseNotes、PowerShell/Bash 运行时头部、测试预期、Scoop、CHANGELOG 和 PROGRESS。
- 任一版本或 URL/extract directory 元数据不一致时，验证脚本必须非零退出；CI 的 Windows PowerShell 5.1 与 PowerShell 7 job 都直接运行该脚本。
- `PROGRESS.md` 必须区分“最新已核验公开版本 2.0.3”和“当前发布目标 2.0.4”，不得提前声称 2.0.4 已发布。
- 更新安装相关双语文档，说明 edition-aware 路径、精确验证和自动化参数。
- 所有测试使用隔离路径和构造对象，不覆盖真实用户模块，不运行包管理器，不读取或打印 Gallery API key。

## Technical Notes

- 新增纯函数脚本 `scripts/Cdp.Installation.ps1`，供根安装器和 Pester 共用路径/验证契约。
- `Install.ps1` 增加 `-Force` 与 `-SkipFzf`，供非交互自动化和 Scoop 使用；默认交互行为不变。
- 新增 `scripts/Test-ReleaseMetadata.ps1`，从 manifest 读取版本并逐项断言镜像元数据。
- 新增独立 Pester 文件，PowerShell 5.1/7 运行相同的 path matrix、精确 module selection 与 metadata negative case。

## Out of Scope

- push、tag、GitHub Release、PowerShell Gallery 发布和远程渠道最终核验；由 `07-16-v2-0-4-release` 处理。
- v2.0.4 tag 生成后的 Scoop archive hash 更新与远程安装验证；由 release 任务处理。
- WSL/Linux/macOS 安装流程或模块拆分。

## Acceptance Criteria

- [x] PowerShell 5.1 与 7 均通过 CurrentUser/AllUsers × Desktop/Core 的隔离路径矩阵。
- [x] 只有目标 `ModuleBase` 且版本匹配的 module candidate 能通过安装验证。
- [x] 当前仓库元数据验证通过；任一 Scoop/version fixture 漂移会使独立验证进程非零退出。
- [x] Scoop version/tag URL/extract directory 为 2.0.4，并复用 `Install.ps1 -Force -SkipFzf`。
- [x] PROGRESS 明确记录公开 2.0.3 与待发布 2.0.4，双语安装文档信息等价。
- [x] PowerShell 5.1/7 Pester、两端 metadata validator、PSScriptAnalyzer、Shell regression 与 syntax 全部通过。
- [x] 不打印或写入任何 Gallery API key。

## Verification Evidence

- PowerShell 7 与 Windows PowerShell 5.1：定向 installer tests `10/10`，full Pester `58/58`。
- `scripts/Test-ReleaseMetadata.ps1`：PowerShell 7 与 Windows PowerShell 5.1 均通过；篡改 Scoop fixture 的独立进程非零退出并报告 `scoop.version`。
- PSScriptAnalyzer：`Install.ps1`、`scripts/*.ps1` 与 `src/cdp.psm1` Severity Error `0`。
- Git Bash：CLI parser、status、shared shell v2 全部通过。
- WSL Arch：bash/zsh shared shell v2 与 bash/zsh syntax 全部通过。
- Workflow YAML 与 Scoop JSON 可解析；`git diff --check` 和最终 Trellis validation 均通过，仅有既有 line-ending 提示。
