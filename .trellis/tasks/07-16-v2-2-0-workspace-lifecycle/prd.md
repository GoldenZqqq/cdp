# 完善 workspace 生命周期

## Goal

把只能 add/list/launch 的 workspace 扩展为可维护、可验证、可迁移的长期配置。

## Requirements

- 增加 show、edit、remove、validate、dry-run 和补全。
- workspace 使用稳定项目引用并能诊断重命名、删除和缺失路径。
- launcher、每项目 override 和布局配置有明确 schema。
- Windows Terminal 与 tmux 行为保持对等可解释。

## Acceptance Criteria

- [ ] 完整 CRUD、验证、补全和 dry-run 跨平台通过。
- [ ] 项目重命名/删除不会静默启动错误目录。
- [ ] 旧 workspaces.json 自动兼容或提供迁移。
