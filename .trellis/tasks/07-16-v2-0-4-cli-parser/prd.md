# 修复 CLI 参数解析与组合选项

## Goal

让 PowerShell 与 bash/zsh 的短入口对同一组命令和选项产生一致、无歧义的解析结果。

## Background

- `Invoke-Cdp` 当前把 `Command`、`ConfigPath` 和 `RemainingArgs` 多次重新解释。
- `cdp status --dirty @work` 会把标签当配置路径；反向排列会忽略 dirty。
- `cdp workspace --add team api web --open codex` 识别 opener 后仍把相关 token 留在项目列表中。
- 多个管理子命令会丢弃尾随自定义配置路径。

## Requirements

- 将 token 解析与命令执行分离，解析函数必须只返回结构化结果，不产生文件或进程副作用。
- `status` 支持 dirty/fix/push、tag 与自定义配置路径的合法组合，冲突动作返回明确错误。
- `workspace` 必须消费 `--open/-o` token，不得把 option 当项目名。
- pin/alias/tag/clean/init/scan/doctor 等短命令必须按公开约定保留自定义配置路径。
- PowerShell 与 shell 使用同一组表驱动解析场景作为验收依据。
- 保持现有单参数调用兼容。

## Acceptance Criteria

- [ ] `cdp status --dirty @work <config>` 和合法排列产生相同结构化结果。
- [ ] `cdp workspace --add team api web --open codex` 的项目仅为 `api`、`web`。
- [ ] 缺少 option 值、未知 option、互斥动作返回可理解错误且无副作用。
- [ ] 管理命令的自定义 config 不再被丢弃。
- [ ] 新解析单元测试在 PowerShell 5.1/7 通过；shell 对等场景通过。
- [ ] README 中已有示例保持兼容。

## Out of Scope

- 本任务不改变 status 数据计算、workspace 启动布局或配置 schema。
