# 优化多仓库 status 性能

## Goal

在保持状态准确性的前提下把 50 项目 status 的典型执行时间恢复到 3 秒内。

## Requirements

- 优先使用 `git status --porcelain=v2 --branch` 合并信息获取，减少进程数。
- 使用可配置有限并发；PowerShell 5.1 有兼容回退。
- 可选短期缓存必须按 HEAD/index/worktree 或明确 TTL 失效，并提供 refresh。
- 建立固定规模、无网络依赖的基准脚本。

## Acceptance Criteria

- [ ] 每仓库 Git 进程数显著下降且结果与正确性 fixture 一致。
- [ ] 50 仓库基准在目标环境典型值小于 3 秒，记录硬件与统计方法。
- [ ] 并发上限、取消和异常仓库不会挂起整个扫描。
