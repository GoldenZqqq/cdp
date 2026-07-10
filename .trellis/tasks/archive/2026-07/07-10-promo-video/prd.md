# P3: HyperFrames 宣传视频重制

## Goal

使用 HyperFrames 重新制作 cdp 的宣传视频，展示 v2.0 的所有新功能，特别是 `cdp status` 仪表盘和 workspace 模式。

## Requirements

### 视频内容

1. 开场：展示多项目开发者的痛点（反复 cd、不知道哪个仓库有未提交代码）
2. `cdp status` 仪表盘演示：一条命令看所有仓库状态
3. `cdp <query>` 快速切换 + `cdp -Open codex` 启动 AI CLI
4. Workspace 模式：一键打开多个项目
5. macOS + Windows + WSL 全平台
6. 安装方式（30 秒以内）

### 技术规格

- 中英文双版本
- 1920x1080 30fps MP4
- 720x405 10fps GIF（README 内嵌用）
- 使用现有 HyperFrames composition 结构

## Dependencies

- 所有功能任务完成后才能制作
- 需要真实的终端录屏或 HyperFrames 模拟

## Acceptance Criteria

- [ ] 中文版 MP4 + GIF 制作完成
- [ ] 英文版 MP4 + GIF 制作完成
- [ ] 视频包含 cdp status 仪表盘演示
- [ ] 视频包含 workspace 模式演示
- [ ] HyperFrames validate 通过
- [ ] 资源文件放在 docs/assets/ 下
