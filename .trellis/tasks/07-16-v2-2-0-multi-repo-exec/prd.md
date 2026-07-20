# 增加多仓库 cdp exec

## Goal

支持按 tag、workspace、显式项目集或显式 `--all`，在多个项目的本机解析路径中
安全执行同一原生命令，并为人类和自动化提供确定、有边界的结果汇总。

## Background

- path profiles 已区分 raw `rootPath` 身份与 resolved local path。
- workspace lifecycle 已提供稳定引用、legacy/renamed/missing 诊断和确定顺序。
- status 已提供 1-16 并发限制、超时、JSON stdout/stderr 分离与稳定退出码模式。
- PowerShell 5.1 与 bash 3.2 仍是最低兼容边界；不能依赖
  `ProcessStartInfo.ArgumentList`、`wait -n`、关联数组或 GNU-only `timeout`。

## Requirements

### R1. CLI 与选择器

- 语法：
  `cdp exec [projects...|@tag|--workspace <name>|--all] [options] -- <command> [args...]`。
- `--` 是强制命令边界；边界后的所有 token 都是原始 argv，不再解析为 cdp option。
- 显式项目可有多个；显式项目、单个 tag、单个 workspace 与 `--all` 四类选择器互斥。
- 空选择器报错，不隐式选择全部项目；全量执行必须显式写 `--all`。
- 支持 `--config`、`--jobs 1-16`、`--timeout 1-3600`、`--fail-fast`、
  `--continue`、`--json`、`--dry-run`、`--yes`。
- 默认 jobs 为最多 4，timeout 为 300 秒；允许
  `CDP_EXEC_CONCURRENCY` 与 `CDP_EXEC_TIMEOUT_SECONDS` 提供同范围默认值。

### R2. 选择与路径

- 只执行 enabled 项目；显式项目按输入顺序，workspace 按引用顺序，tag/`--all`
  按配置顺序，按 exact raw identity 去重并保留首次出现。
- 显式项目名 exact 匹配；tag 沿用当前 tag 的大小写不敏感语义。
- workspace 复用稳定引用 resolver：`legacy` / `renamed` 可执行，missing、ambiguous、
  disabled、invalid path profile 等记录为项目级失败，不能按同名回退。
- 所有目标在执行前解析 raw/resolved path；不可用目标不启动命令，但 continue 模式仍执行后续安全目标。

### R3. 安全执行

- cdp 不判断任意命令是否“只读”；所有真实 exec 都视为高影响并要求 `--yes`
  或 PowerShell `-Confirm:$false`，`--dry-run` / `-WhatIf` 只输出计划。
- 命令必须解析为原生可执行文件；cdp 使用 executable + argv 调用，不拼接、不 eval、
  不隐式调用 shell。需要管道/重定向时，用户必须显式传入 `sh -c` / `pwsh -Command`。
- 每个项目使用 resolved path 作为独立工作目录，stdout/stderr 分离捕获；不支持交互 stdin。
- 默认 continue：失败不阻止后续批次。`--fail-fast` 在首个失败/超时后停止调度新项目，
  已运行项目完成，剩余项目标记 `canceled`。

### R4. 输出与退出码

- 人类输出按选择顺序分组，包含项目、raw/resolved path、状态、exit code、elapsed、
  stdout 和 stderr；并发完成顺序不得改变最终顺序。
- JSON stdout 只写一个 schema version 1 文档，包含 selector、command argv、options、
  summary 和 ordered results；进度与致命诊断写 stderr。
- 结果状态：`planned`、`succeeded`、`failed`、`timed_out`、`canceled`、
  `missing_project`、`ambiguous_project`、`disabled_project`、`path_profile_invalid`、`path_missing`。
- 退出码：0 全部成功或有效 dry-run；1 continue 模式存在项目失败/超时/不可用；
  2 fail-fast 触发并产生 canceled；3 解析、依赖、配置、选择器或序列化致命失败。

### R5. 补全与文档

- PowerShell/bash/zsh 补全 `exec`、项目、tag/workspace selector、jobs/fail policy/JSON/safety option。
- README.md 先更新英文，再同步 README_ZH.md；更新 spec、CHANGELOG、PROGRESS、
  ReleaseNotes、生成 shell、installer hash、Scoop draft/hash 与 CI。

## Out of Scope

- 远程执行、SSH、容器编排、命令白名单或自动判断命令风险等级。
- 交互式 stdin、实时交错日志、输出截断/持久化策略、shell DSL 或隐式管道解析。
- 按 Git dirty/ahead 状态选择；可在后续版本基于 status JSON 组合。

## Acceptance Criteria

- [x] tag、workspace、显式项目、`--all` 与空选择器行为在 PowerShell/bash/zsh/Bash 3.2 有测试。
- [x] `--` 后路径、参数、空格、引号和元字符保持 argv，不发生注入、option 泄漏或错分词。
- [x] dry-run/确认、continue/fail-fast、并发上限、超时和取消无副作用且汇总准确。
- [x] 人类/JSON 输出顺序确定，stdout/stderr/exit code/elapsed/status 与退出码 0-3 一致。
- [x] workspace 稳定引用、path profiles、补全、双语文档、版本/包元数据和完整门禁通过。
