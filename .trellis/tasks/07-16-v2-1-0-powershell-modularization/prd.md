# 拆分 PowerShell 模块边界

## Goal

把 4,643 行单文件模块拆为可独立理解和测试的领域文件，同时保持模块导入性能与公共命令兼容。

## Background

- `cdp.psd1` 以 `src/cdp.psm1` 为稳定入口。
- 当前模块包含 119 个函数以及别名、补全和导出注册。
- 源码安装、Gallery 打包和 Scoop 打包都递归复制 `src`，可安全携带子目录。

## Requirements

- 至少按 Config、State、Picker、Status、Workspace、Hooks、Commands、Completion 分层；共享基础设施、解析、健康检查、项目变更和扫描可使用独立支持文件。
- 公共导出、别名、帮助、PowerShell 5.1 兼容和 session 级缓存保持不变。
- 安装器与 Gallery 包必须包含全部新文件。
- 单文件和函数复杂度满足项目硬门禁，确需例外必须在 spec 记录原因。
- 领域文件不得互相 dot-source；仅 bootstrap 拥有确定性加载顺序。

## Out of Scope

- 不在本任务中改变命令语义、参数、输出结构或 JSON contract。
- 不同时重构函数内部算法；后续 status 性能任务单独处理。
- 不改变 manifest 的 `RootModule` 路径。

## Acceptance Criteria

- [x] `src/cdp.psm1` 仅承担受控加载与导出。
- [x] 无领域文件超过项目文件上限，无新增循环依赖。
- [x] 现有及新增 Pester、导入性能 smoke、manifest 验证通过。
- [x] PowerShell 5.1/7 公共命令列表完全一致。
