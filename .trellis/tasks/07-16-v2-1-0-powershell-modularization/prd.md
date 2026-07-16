# 拆分 PowerShell 模块边界

## Goal

把 3,487 行单文件模块拆为可独立理解和测试的领域文件，同时保持模块导入性能与公共命令兼容。

## Requirements

- 按 Config、State、Picker、Status、Workspace、Hooks、Commands、Completion 分层。
- 公共导出、别名、帮助、PowerShell 5.1 兼容和 session 级缓存保持不变。
- 安装器与 Gallery 包必须包含全部新文件。
- 单文件和函数复杂度满足项目硬门禁，确需例外必须在 spec 记录原因。

## Acceptance Criteria

- [ ] `src/cdp.psm1` 仅承担受控加载与导出。
- [ ] 无领域文件超过项目文件上限，无新增循环依赖。
- [ ] 现有及新增 Pester、导入性能 smoke、manifest 验证通过。
- [ ] PowerShell 5.1/7 公共命令列表完全一致。
