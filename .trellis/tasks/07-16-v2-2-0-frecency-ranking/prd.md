# 增加 frecency 智能排序

## Goal

在保留 pin 最高优先级的前提下，让常用且最近访问的项目更快出现在选择器前部。

## Requirements

- 排名融合 pinned、lastVisitedAt、visitCount 和时间衰减，算法确定且可测试。
- 提供关闭/重置选项；无 state 时保持当前字母排序。
- PowerShell 与 shell 对同一 fixture 排序一致。
- 不改变精确 query 和 tag filter 的匹配语义。

## Acceptance Criteria

- [ ] 排名公式、边界和 tie-breaker 文档化。
- [ ] 固定时间 fixture 在各平台结果一致。
- [ ] state 损坏、未来时间和大量历史记录安全处理。
