# 增加跨平台路径 profile

## Goal

让同一个项目配置在 Windows、WSL、Linux 和 macOS 上解析到正确本地路径。

## Requirements

- 保留现有 `rootPath` 兼容，同时支持显式平台路径映射。
- 定义确定的选择优先级、WSL 自动转换、环境 override 和错误诊断。
- add/scan/init/repair/status/workspace/exec 全部使用统一 path resolver。
- 提供无损迁移和旧版本降级说明。

## Acceptance Criteria

- [ ] 单一项目在四类环境 fixture 中选择正确路径。
- [ ] 旧配置无需迁移即可继续工作。
- [ ] 不可用 profile 不静默回退到错误目录。
