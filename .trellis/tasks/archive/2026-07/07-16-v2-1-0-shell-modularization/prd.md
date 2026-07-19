# 拆分 bash zsh 模块边界

## Goal

降低 3,248 行 shell 单文件的修改风险，同时保持 `source cdp.sh` 与一键安装体验。

## Background

- `install-wsl.sh` 的远程路径只下载并校验一个 `src/cdp.sh`。
- 现有 bash、zsh 与 Bash 3.2 测试都直接 source 该文件。
- PowerShell 已完成领域拆分；shell 需要相同所有权边界，但不能破坏单文件发布契约。

## Requirements

- 领域边界与 PowerShell 对齐，避免复制新的业务规则。
- `src/Shell/*.sh` 为领域源码，`src/cdp.sh` 为确定性生成且提交的单文件安装产物。
- 生成器提供 `--check`，CI 必须拒绝分片与单文件漂移；离线安装继续可用。
- bash 3.2、现代 bash、zsh 兼容。
- 领域分片不互相 source，单个分片不超过 600 行。

## Out of Scope

- 不改变命令参数、输出、持久化、安全或 completion 语义。
- 不在拆分过程中重写 status 算法；性能优化由后续任务负责。
- 不把远程安装改成多文件网络下载。

## Acceptance Criteria

- [x] 核心 shell 文件满足项目文件上限或由生成验证解释例外。
- [x] 安装后 `source`、completion 和全部命令行为不回归。
- [x] bash/zsh syntax、ShellCheck 和 shell regression 通过。
