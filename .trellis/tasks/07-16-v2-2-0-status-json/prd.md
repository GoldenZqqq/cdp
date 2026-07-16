# 增加机器可读 status 输出

## Goal

让 `cdp status` 可被脚本、CI 和 AI Agent 稳定消费，而不解析彩色终端文本。

## Requirements

- 支持 `--json`、`--no-color` 和稳定 schema version。
- JSON 包含项目身份、解析路径、Git 状态、attention reasons、错误和扫描时间。
- stdout 只输出数据，诊断走 stderr；退出码区分成功、需关注、部分失败和致命失败。
- PowerShell 对象与 shell JSON 字段语义一致。

## Acceptance Criteria

- [ ] contract fixture 在 PowerShell/bash/zsh 产生等价 JSON。
- [ ] 输出可被 `ConvertFrom-Json` 与 jq 解析，关闭颜色后无 ANSI。
- [ ] schema/退出码写入双语文档并有兼容测试。
