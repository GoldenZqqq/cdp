# 拆分 bash zsh 模块边界

## Goal

降低 2,252 行 shell 单文件的修改风险，同时保持 `source cdp.sh` 与一键安装体验。

## Requirements

- 领域边界与 PowerShell 对齐，避免复制新的业务规则。
- 安装产物可由源文件生成或通过稳定加载器加载；离线安装可用。
- bash 3.2、现代 bash、zsh 兼容。

## Acceptance Criteria

- [ ] 核心 shell 文件满足项目文件上限或由生成验证解释例外。
- [ ] 安装后 `source`、completion 和全部命令行为不回归。
- [ ] bash/zsh syntax、ShellCheck 和 shell regression 通过。
