# 增加多仓库 cdp exec

## Goal

支持按 tag、workspace 或显式项目集安全地执行同一命令并汇总结果。

## Requirements

- 语法支持选择器、`--` 命令边界、并发限制、dry-run、fail-fast/continue 和 JSON 输出。
- 不通过不可信字符串拼接 shell；明确记录每个工作目录和 argv。
- 默认只读提示；高影响命令遵循安全确认策略。
- 输出逐项目 stdout/stderr/exit code/elapsed，保持确定排序。

## Acceptance Criteria

- [ ] tag、workspace、显式项目和空选择器行为有测试。
- [ ] 路径/参数含空格和特殊字符时不发生注入或错分词。
- [ ] 部分失败、超时和取消得到准确汇总与退出码。
