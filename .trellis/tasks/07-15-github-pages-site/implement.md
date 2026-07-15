# Implementation Plan

## 1. Brand and Content Foundation

- [x] 依据 `PRODUCT.md` / `DESIGN.md` 固化首屏主张、痛点短句和双语文案键。
- [x] 确认现有 logo、favicon、视频和 GIF 的相对路径及 alt / fallback 文案。
- [x] 在 `.impeccable/design.json` 中记录颜色 metadata、motion、breakpoints 和代表性组件。

## 2. Static Page Structure

- [x] 新建 `docs/index.html`，完成 landmarks、SEO、Open Graph、导航和全部叙事区块。
- [x] 使用真实命令构建 hero、痛点路线、Command Rail、演示视频、跨平台和安装区。
- [x] 添加 `docs/.nojekyll`，不修改 GitHub Actions。

## 3. Visual System

- [x] 新建 `docs/styles.css`，实现设计 token、字体回退、色块与跃迁路线视觉。
- [x] 完成 360px、768px、1024px、1440px 响应式布局。
- [x] 实现可见焦点、状态语义、hover / active 和 reduced-motion。
- [x] 审查并移除渐变文字、玻璃卡片、同构卡片墙和 ghost-card 等禁用模式。

## 4. Progressive Enhancement

- [x] 新建 `docs/script.js`，实现中英文切换与语言偏好持久化。
- [x] 实现 Command Rail 和安装平台 tabs 的鼠标与键盘操作。
- [x] 实现 Clipboard API 与手动复制回退。
- [x] 实现移动导航、轻量路线动画和无 JS 回退。

## 5. Documentation Sync

- [x] 在 `README.md` 增加中文官网入口与 Pages 启用说明。
- [x] 在 `README_EN.md` 增加等价英文内容，保持结构同步。

## 6. Validation and Review

- [x] 运行 `node --check docs/script.js`。
- [x] 使用本地静态服务器验证资源、链接、视频和控制台无错误。
- [x] 校验所有 `data-i18n` 键在中英文词典中完整存在。
- [x] 检查 HTML landmarks、heading 顺序、alt、ARIA、tab 键盘模型和焦点状态。
- [x] 截图检查 360px、768px、1024px、1440px，修复溢出与视觉层级问题。
- [x] 检查 normal / reduced-motion 两种偏好。
- [x] 运行 Impeccable detector / audit、`git diff --check` 和定向 review。

## Validation Evidence

- Lighthouse mobile navigation：Accessibility 100、Best Practices 100、SEO 100、Agentic Browsing 100。
- Chrome performance trace：LCP 510ms、CLS 0.00；控制台无消息，所有页面资源返回 200 / 304。
- 360px、768px、1024px、1440px：`scrollWidth === clientWidth`，所有 `h1`–`h3` 无溢出，所有 i18n 节点无 fallback key。
- 浏览器交互实测：中英文切换、Command Rail、安装平台 tabs、Clipboard 成功反馈、移动菜单及 Escape 关闭均正常。
- Impeccable detector：`[]`，无设计反模式或 token 漂移。
- Pester：24 passed、0 failed。
- `node --check docs/script.js`、JSON 解析、README 对称检查、HTTP smoke、`git diff --check` 均通过。

## Risky Files and Rollback Points

- `docs/index.html`、`docs/styles.css`、`docs/script.js` 共同构成站点契约，任何 DOM key 改动必须同步 CSS 与 JS。
- `README.md` / `README_EN.md` 必须成对修改。
- 不改 `.github/workflows/`、`src/cdp.psm1`、`src/cdp.sh` 或 `cdp.psd1`。
- 每完成结构、样式、交互三个阶段分别运行一次 `git diff --check`，便于局部回滚。

## Start Gate

- [x] 用户已授权创建 Trellis 任务并进入规划、实现。
- [x] PRD 包含可测试验收标准并完成收敛整理。
- [x] 技术设计明确静态边界、数据契约、兼容与回滚。
- [x] 实施清单覆盖代码、文档、可访问性、视觉审查和验证。
