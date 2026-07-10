# P1: 双语 README 重写 - 重新定位为项目工作台

## Goal

重写 README.md 和 README_EN.md，将 cdp 的定位从"项目目录切换器"升级为"终端里的项目工作台"。突出 cdp status 仪表盘、workspace 模式等新功能，让读者第一眼就感受到与 zoxide 的差异。

## Requirements

### 定位调整

- 标题/副标题改为强调"项目工作台"而非"目录切换器"
- 开头的 pain point 场景扩展：不只是 cd 慢，还有"不知道哪个仓库有未提交的代码"
- 与竞品对比表更新：加入 `cdp status` 作为核心差异列

### 新内容

- `cdp status` 的截图和使用场景
- macOS 安装指南
- Tab 补全的说明
- Workspace 模式的使用示例
- onEnter hook 的配置示例
- 更新功能列表和命令表

### 质量

- 中英文内容结构完全一致
- 截图/GIF 更新为包含新功能的版本
- 确保所有新命令在命令列表表格中

## Dependencies

- 依赖 cdp-status-dashboard、macos-support、tab-completion 等功能任务先完成
- 可以在功能开发过程中逐步更新

## Acceptance Criteria

- [ ] README.md（中文）完整更新
- [ ] README_EN.md（English）完整更新
- [ ] 两个版本结构和内容一致
- [ ] 所有新功能有使用示例
- [ ] 竞品对比表更新
- [ ] macOS 安装说明
- [ ] 新功能截图/GIF
