# 补齐 bash zsh v2 回归测试

## Goal

把当前 CI 中的长内联 smoke 转换为仓库内可本地复用的 shell 回归测试。

## Requirements

- 测试 status、workspace、hook、completion、Windows 路径转换和参数组合。
- 测试脚本必须同时可由 Ubuntu bash 与 macOS zsh CI 调用。
- 外部命令通过临时 fake PATH 或 dry-run 隔离，不 push、不打开 tmux/GUI。
- CI 只负责安装依赖并调用仓库测试入口。

## Acceptance Criteria

- [ ] 新 shell 测试入口在 Ubuntu bash 通过。
- [ ] zsh 兼容 smoke 调用同一套共享场景并通过。
- [ ] jq/fzf/git 缺失和错误配置有确定断言。
- [ ] CI 中不再复制主要测试逻辑。
