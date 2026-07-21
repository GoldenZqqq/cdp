# 增加 frecency 智能排序

## Goal

在保留 pin 最高优先级和无历史时现有配置顺序的前提下，让常用且最近访问的项目更快出现在选择器与项目列表前部。

## Background

- PowerShell `Sort-CdpProjectsForDisplay` 与 shell `sorted_enabled_project_*`
  当前都按 pinned 分组后保留配置索引顺序，不是字母排序。
- recent state 已独立保存 exact raw `rootPath`、`lastVisitedAt` 和 `visitCount`，
  正常写入最多保留 20 项，但读取端仍需安全处理损坏或异常大的历史。
- PowerShell 5.1、bash 3.2 与 zsh 必须对同一固定时间 fixture 产生完全一致的顺序；
  不能依赖浮点衰减、GNU-only date 参数或 jq 对时区后缀的隐式差异。

## Requirements

- 排名按 exact raw `rootPath` 关联项目与 recent state；同名或大小写相近路径不能串用历史。
- pinned 始终形成最高优先级分组；组内再按 frecency 排名。
- 对有效历史使用整数公式：
  `score = floor(clamp(visitCount,1,1000) * 1000000 / (ageDays + 1))`；
  `ageDays = floor(max(0, nowEpoch-lastVisitedEpoch)/86400)`。
- 排序键固定为：pin rank 升序、score 降序、lastVisited epoch 降序、
  visitCount 降序、原配置 index 升序。
- 缺失/损坏 state、无匹配历史、无效时间、非数值/负访问次数均视为 score 0，
  因而保持现有 pin + 配置顺序；未来时间按 age 0 处理。
- `CDP_FRECENCY=0|false|off|no` 关闭智能分值但保留现有 pin + 配置顺序。
- `cdp recent reset` 清空 recentProjects；PowerShell 支持 `-WhatIf` / `-Confirm`，
  shell 支持 `--dry-run` / `--yes`，损坏 state 不得被静默覆盖。
- PowerShell 与 shell 对同一固定时间 fixture 排序一致。
- 精确 query、模糊 query 与 tag filter 的匹配集合保持不变；只有多候选显示顺序变化。
- picker、`cdp-ls` / `Get-ProjectList` 与多匹配 query 使用同一排序边界；
  status、exec、workspace 引用顺序不受 frecency 影响。

## Out of Scope

- 云同步、跨机器合并、按 Git dirty/ahead 状态加权、用户可编辑权重 DSL。
- 把 frecency 分数写回 Project Manager `projects.json`。
- 扩大 recent state 的默认 20 项写入上限。

## Acceptance Criteria

- [ ] 排名公式、边界和 tie-breaker 文档化。
- [ ] 固定时间 fixture 在各平台结果一致。
- [ ] state 损坏、未来时间和大量历史记录安全处理。
- [ ] 无 state / 关闭 frecency 时保持 pin + 配置顺序。
- [ ] reset 的 preview/approval/invalid-state/no-op 行为无数据破坏。
- [ ] query/tag 匹配集合、status/exec/workspace 顺序不回归。
