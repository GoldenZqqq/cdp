# 建立 onEnter hook 信任模型

## Goal

阻止自动发现或被修改的配置在目录切换时静默执行任意代码，同时保留显式可信的环境激活能力。

## Requirements

- 结构化 `env` 可安全应用；shell 命令默认不执行。
- 信任绑定配置规范化路径与内容/命令指纹，修改后自动失效。
- 提供 `hook list/trust/revoke`、单次确认和 `--no-hook`。
- 不把 secret 或完整敏感命令写入日志。

## Acceptance Criteria

- [ ] 未信任命令不会执行且提示下一步。
- [ ] 信任后 PowerShell/bash hook 正常执行，配置变更后需重新信任。
- [ ] `env` 键名验证、错误隔离、信任存储权限和跨平台测试通过。
