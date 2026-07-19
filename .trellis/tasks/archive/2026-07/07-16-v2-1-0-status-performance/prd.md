# 优化多仓库 status 性能

## Goal

在保持状态准确性的前提下把 50 项目 status 的典型执行时间恢复到 3 秒内。

## Baseline

- 固定 50 个本地单提交仓库、无 remote、无网络访问。
- Linux arm64 当前 shell 三次为 `3.98s / 4.07s / 4.19s`。
- PowerShell 7.5.2 arm64 三次为 `2.258s / 1.914s / 1.838s`。
- 当前每个 Git 仓库最多启动 7 个 Git 进程。

## Requirements

- 优先使用 `git status --porcelain=v2 --branch` 合并信息获取，减少进程数。
- 使用 `CDP_STATUS_CONCURRENCY` / `--jobs` 可配置有限并发；PowerShell 5.1 使用 runspace pool 兼容实现。
- 可选短期缓存默认关闭，仅在 `CDP_STATUS_CACHE_TTL` 为正数时启用；提供 `--refresh` / `-Refresh`，fix/push 强制刷新。
- 单仓库扫描超时由 `CDP_STATUS_TIMEOUT_SECONDS` 限制；超时或异常返回可见失败状态而非挂起。
- 建立固定规模、无网络依赖的基准脚本。

## Out of Scope

- 不执行 fetch，不以网络远端作为性能或正确性前提。
- 不改变 status 表格字段、变更确认或 push/fix 目标规则。
- 不在本任务中增加 JSON 输出；机器接口由 v2.2.0 任务负责。

## Acceptance Criteria

- [x] 每仓库 Git 进程从最多 7 次降至最多 2 次，porcelain-v2、进程计数和现有正确性 fixture 通过。
- [x] Linux arm64 50 仓库、5 次运行、无 remote：jobs=4 median `2.083s`，jobs=8 median `2.082s`；PowerShell 7.5.2 单 worker median `2.209s`。
- [x] 并发限制为 1-16；单仓库/单 worker 超时、异常结果、Bash/zsh 默认并发和缓存刷新均有回归覆盖，不会无限等待。

## Verification Notes

- Bash jobs=4: min `2.007s`, median `2.083s`, p95 `2.246s`.
- Bash jobs=8: min `1.912s`, median `2.082s`, p95 `2.198s`.
- PowerShell 7.5.2 workers=1: min `1.941s`, median `2.209s`, p95 `2.917s`.
- 本机未安装 PowerShell；使用官方 PowerShell 7.5.2 arm64 隔离运行时完成 Pester `95/95` 与 PSScriptAnalyzer 验证。Windows PowerShell 5.1 由仓库 hosted CI 门禁确认。
