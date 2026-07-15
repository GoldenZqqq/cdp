# 设计并实现 cdp GitHub Pages 官网

## Goal

构建直击多仓库与 AI CLI 工作流痛点、具有独特高速路标视觉语言的官方静态官网，让访客在十秒内理解 cdp 的核心价值，并在一分钟内完成平台选择与安装决策。

## Background

- cdp 已从模糊目录切换器扩展为终端项目工作台，包含多仓库 Git 状态、AI CLI / 编辑器启动、workspace、doctor、Tab 补全和跨平台支持。
- 当前 `README.md` / `README_EN.md` 信息完整但密度较高，不适合作为第一印象和品牌入口。
- 仓库已有蓝青色 logo、演示 MP4 / GIF、真实 TUI 视觉和中英文文档，可直接复用。
- GitHub Pages 可从 `main` 分支的 `/docs` 目录发布；本次不修改 CI 或仓库 Pages 设置。
- 用户已确认品牌方向为“迅疾、可靠、锋利”，接受 WCAG AA、响应式、reduced-motion，以及避开玻璃卡片、廉价赛博朋克和模板化卡片墙。

## Requirements

- R1：在 `docs/` 下实现无构建步骤的静态站点，复用现有 logo、图标和演示视频。
- R2：首屏必须先呈现长路径导航、多仓库 Git 状态遗忘和 AI CLI 上下文重载三个真实痛点，再给出“一条命令进入工作”的核心主张。
- R3：采用 “The Warp Lane / 跃迁车道” 视觉系统，以高速路标、出发板和调度轨迹为结构来源，不复制常见开发者工具官网模板。
- R4：包含真实可执行的命令演示、交互式 Command Rail、跨平台路线、演示视频、安装选择和 GitHub / 文档入口。
- R5：提供完整中文和英文内容，语言切换同步 `html[lang]`、按钮可访问名称和持久化偏好。
- R6：安装区支持 Windows PowerShell、WSL / Linux、macOS 三类命令切换与一键复制；禁用 JavaScript 时仍显示可复制的默认安装路径。
- R7：响应式覆盖 360px、768px、1024px 和 1440px 典型视口，标题不溢出、触控目标不小于 44px。
- R8：满足 WCAG 2.2 AA 基线，包括语义结构、跳过导航、键盘访问、可见焦点、状态非颜色单一表达、视频控制和 reduced-motion。
- R9：使用渐进增强；静态 HTML 默认可读，JavaScript 仅增强语言切换、命令切换、复制和有节制的路线动画。
- R10：同步更新 `README.md` 和 `README_EN.md`，加入官网入口和 GitHub Pages 启用说明或链接。
- R11：页面必须包含 SEO 基础元数据、Open Graph、favicon、canonical URL 和描述性标题。
- R12：不修改 PowerShell / bash 模块逻辑、不提升模块版本、不修改 CI，不引入构建工具、前端框架或运行时依赖。

## Acceptance Criteria

- [x] AC1：打开 `docs/index.html` 即可完整浏览所有核心区块，未加载 JavaScript 时首屏、功能、安装和链接仍可用。
- [x] AC2：首屏出现明确痛点文案、真实 `cdp` 命令和主要安装 / GitHub CTA，不依赖抽象营销口号。
- [x] AC3：Command Rail 至少覆盖 `cdp`、`cdp status`、`cdp api -Open codex`、`cdp workspace`、`cdp doctor`，鼠标和键盘均可操作。
- [x] AC4：中文与英文切换覆盖导航、核心文案、交互标签和复制反馈，刷新后保持选择。
- [x] AC5：安装平台切换与复制功能可用；复制失败时提供可理解的回退反馈。
- [x] AC6：页面使用现有 `docs/assets/cdp-v2-promo.mp4` 展示真实产品，并提供 poster / fallback 链接。
- [x] AC7：360px、768px、1024px、1440px 截图不存在水平溢出、遮挡、不可读文字或断裂布局。
- [x] AC8：键盘可到达所有交互元素，焦点清晰；`prefers-reduced-motion: reduce` 下没有自动位移动画。
- [x] AC9：颜色对比、语义标题、landmark、alt 文本、按钮名称和 ARIA 状态通过定向检查。
- [x] AC10：`git diff --check`、HTML 结构检查、JavaScript 语法检查和本地静态服务器 smoke test 通过。
- [x] AC11：`README.md` 与 `README_EN.md` 对官网信息保持对等。

## Out of Scope

- 自动修改 GitHub 仓库 Pages 设置。
- 新增或修改 GitHub Actions / CI 工作流。
- 接入分析、Cookie、后台服务、CMS、评论或表单提交。
- 改动 cdp 命令行为、模块版本、Gallery 发布或 release 流程。
- 构建完整文档站、博客或多页面路由系统。

## Constraints

- 所有网站源文件保持静态、可直接由 GitHub Pages 托管。
- 优先复用现有品牌资产，不生成与 logo 冲突的新图形标识。
- 遵循根 `AGENTS.md`、`PRODUCT.md` 与 `DESIGN.md`。
- 不使用渐变文字、玻璃拟态、装饰网格、重复同构卡片墙或超过 16px 的卡片圆角。
- 外部字体加载失败时必须有可靠系统字体回退。
