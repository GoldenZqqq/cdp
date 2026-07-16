# 修复 status 跨平台正确性

## Goal

让 `cdp status` 在 PowerShell、bash、zsh、WSL 路径和 Git worktree 场景中报告一致且真实的仓库状态。

## Requirements

- shell status/workspace 必须对 Windows `rootPath` 使用现有 WSL 路径转换。
- Git 仓库检测使用 Git 自身判断，不能只依赖 `.git` 目录，从而支持 worktree 和 `.git` 文件。
- dirty 与 untracked 同时存在时两类数量都不得丢失。
- behind-only 仓库必须计入 needs-attention 汇总，不得显示 All projects clean。
- `--fix` 只处理预览中确定的缺失项目；`--push` 只处理具有 upstream 且 ahead 的仓库。
- PowerShell 与 shell 输出语义一致。

## Acceptance Criteria

- [ ] Windows 路径配置在 WSL status/workspace 中正确解析。
- [ ] 常规仓库与 linked worktree 均识别为 Git 仓库。
- [ ] dirty、untracked、ahead、behind、detached、无 upstream、missing、non-git 均有回归测试。
- [ ] behind-only 汇总正确。
- [ ] 修复不引入 2.1.0 才计划的并发或缓存重构。
