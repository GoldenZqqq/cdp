# Technical Design

## Architecture

官网采用无构建步骤的多文件静态架构，部署根目录为 `docs/`：

- `docs/index.html`：语义 HTML、SEO、双语内容节点、无脚本回退。
- `docs/styles.css`：设计 token、响应式布局、状态样式和 reduced-motion。
- `docs/script.js`：语言、Command Rail、安装平台、复制、导航和渐进动画增强。
- `docs/.nojekyll`：确保 GitHub Pages 原样发布静态资源。
- `docs/assets/*`：复用现有 logo、favicon、视频和 GIF，不复制二进制资产。

GitHub Pages 发布目标为 `main` 分支 `/docs`。本任务不触碰 `.github/workflows/`，仓库所有者可在 Settings → Pages 中选择 Deploy from a branch。

## Page Narrative

1. **Hero / Route Lock**：先展示被浪费的路径输入和仓库上下文切换，再用 `cdp api -Open codex` 锁定目的地。
2. **Pain Compression**：用三条横向路由对照“以前的损耗”和“现在的一条命令”。
3. **Command Rail**：选择真实命令，终端面板显示输入、路由和结果。
4. **Live Proof**：播放现有 v2.0 演示视频，避免营销自证。
5. **Cross-platform Merge**：Windows、WSL / Linux、macOS 路线汇入同一项目列表。
6. **Install Gate**：平台切换、复制安装命令、链接到 README 和 PowerShell Gallery。
7. **Footer / Destination**：GitHub、文档、License 与语言入口。

## Data and State

页面不请求业务 API。脚本内维护三组只读配置：

- `translations`：`zh-CN` / `en` 文案字典，以 `data-i18n` 键映射文本和 ARIA 属性。
- `commandScenarios`：Command Rail 的命令、描述、终端输出和状态。
- `installCommands`：PowerShell、WSL / Linux、macOS 的命令和说明。

运行时状态仅包括当前语言、命令场景、安装平台、移动导航开关和复制反馈。语言偏好写入 `localStorage`；其余状态不持久化。存储访问使用 try/catch，失败不影响页面。

## Interaction Contracts

- Language toggle：更新 `document.documentElement.lang`、所有 `data-i18n` 节点、ARIA 标签和当前语言状态。
- Command Rail：使用 button + `role=tablist` / `role=tab` / `role=tabpanel`；支持方向键、Home、End 和 click。
- Install tabs：同样遵循 tabs 键盘模型；命令保留在可选择的 `code` 中。
- Copy：优先 `navigator.clipboard.writeText`，不可用时选中文本并给出手动复制提示，不执行不安全 DOM 命令。
- Mobile nav：原生 button 控制 `aria-expanded`，Escape 关闭；不创建焦点陷阱。
- Motion：内容初始可见，IntersectionObserver 只添加轻量增强类；reduced-motion 下禁用自动轮播、平移和路径绘制。

## Styling Boundaries

- 所有颜色、间距、圆角、字号和 easing 从 `:root` token 引用。
- 使用 OKLCH 作为 CSS 主色表达，并提供 hex fallback；`DESIGN.md` frontmatter 保持 hex 以兼容 Stitch。
- Flexbox 处理命令轨道、导航和平台切换，CSS Grid 只用于真正二维的 hero / proof 布局。
- 无装饰性 CSS 网格背景、无渐变文字、无玻璃拟态。
- 终端演示使用实体 Midnight Asphalt 表面，圆角不超过 14px，无宽柔阴影。

## Compatibility

- 目标浏览器：当前两代 Chrome、Edge、Firefox、Safari。
- CSS 使用渐进增强；不支持 `oklch()` 时由前置 hex token 保持正确颜色。
- `text-wrap: balance`、`color-mix()` 等增强必须提供可接受默认表现。
- JS 使用浏览器原生 API，不依赖 modules、bundler 或第三方库。
- 视频提供 `controls`、`preload=metadata`、poster / fallback 链接，不自动播放声音。

## SEO and Sharing

- canonical：`https://goldenzqqq.github.io/cdp/`
- Open Graph / Twitter 使用现有 `docs/assets/cdp_dark.png`。
- 结构包含 title、description、theme-color、favicon、manifest-independent icons。
- 页面主体默认中文，语言切换不改变 URL；README 继续承担完整双语文档。

## Risks and Mitigations

- **Pages 未启用**：代码可交付但 URL 不会在线；在 README 中写清 Settings → Pages 操作，不修改 CI。
- **外部字体在部分网络不可达**：提供系统字体链，正文和布局不依赖字体下载完成。
- **视频体积影响首屏**：视频放在首屏之后，使用 `preload=metadata` 和 poster，不自动下载完整内容。
- **双语文案漏翻**：集中字典并用脚本校验所有 `data-i18n` 键同时存在。
- **动画导致空白或不适**：HTML 默认可见，reveal 为非阻塞增强，reduced-motion 完全取消位移。
- **README 与官网漂移**：官网只承载高层价值和安装入口，详细命令始终链接 README。

## Rollback

删除新增的 `docs/index.html`、`docs/styles.css`、`docs/script.js`、`docs/.nojekyll`，还原 README 官网链接及 `PRODUCT.md` / `DESIGN.md` 即可；现有 `docs/assets` 和模块代码不受影响。
