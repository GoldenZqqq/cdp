---
name: cdp — The Warp Lane
description: A directional, high-velocity brand system for the terminal project workbench.
colors:
  warp-blue: "#2156FF"
  route-cyan: "#20D9D2"
  signal-yellow: "#F6D53B"
  midnight-asphalt: "#07101F"
  deep-route: "#0D2DAA"
  clear-white: "#FFFFFF"
  cold-paper: "#F7F8FC"
  slate-copy: "#52647D"
  clean-green: "#59D18C"
  attention-red: "#FF5B69"
typography:
  display:
    fontFamily: "Barlow Condensed, Bahnschrift, Arial Narrow, sans-serif"
    fontSize: "clamp(3.6rem, 10vw, 6rem)"
    fontWeight: 700
    lineHeight: 0.9
    letterSpacing: "-0.025em"
  headline:
    fontFamily: "Barlow Condensed, Bahnschrift, Arial Narrow, sans-serif"
    fontSize: "clamp(2.4rem, 6vw, 4.5rem)"
    fontWeight: 650
    lineHeight: 0.95
    letterSpacing: "-0.02em"
  body:
    fontFamily: "Manrope, Segoe UI Variable, Noto Sans SC, sans-serif"
    fontSize: "clamp(1rem, 1.4vw, 1.125rem)"
    fontWeight: 450
    lineHeight: 1.7
  label:
    fontFamily: "Cascadia Code, JetBrains Mono, SFMono-Regular, monospace"
    fontSize: "0.8125rem"
    fontWeight: 600
    lineHeight: 1.4
    letterSpacing: "0.02em"
rounded:
  control: "10px"
  surface: "14px"
  pill: "999px"
spacing:
  xs: "6px"
  sm: "12px"
  md: "20px"
  lg: "32px"
  xl: "56px"
  section: "clamp(88px, 12vw, 168px)"
components:
  button-primary:
    backgroundColor: "{colors.signal-yellow}"
    textColor: "{colors.midnight-asphalt}"
    rounded: "{rounded.control}"
    padding: "14px 20px"
  button-primary-hover:
    backgroundColor: "{colors.clear-white}"
    textColor: "{colors.midnight-asphalt}"
    rounded: "{rounded.control}"
    padding: "14px 20px"
  button-secondary:
    backgroundColor: "{colors.midnight-asphalt}"
    textColor: "{colors.clear-white}"
    rounded: "{rounded.control}"
    padding: "14px 20px"
---

# Design System: cdp — The Warp Lane

## 1. Overview

**Creative North Star: "The Warp Lane / 跃迁车道"**

cdp 的视觉系统来自高速路标、机场出发板和铁路调度图，而不是常见开发者工具官网。每个命令是一条路线，每个项目是一个目的地，每次上下文切换都是一次明确、快速、可验证的到达。

整体以大面积 Warp Blue 和高对比 Signal Yellow 建立记忆点，以 Midnight Asphalt 承载真实终端内容。布局允许方向线、切角和不对称分栏穿越区块，但信息层级必须像路标一样一眼可读。动效表现“路由”和“到达”，不表现故障、噪点或黑客电影。

系统明确拒绝 PRODUCT.md 中的“泛用深色 SaaS 模板”“廉价赛博朋克”“终端角色扮演”和“文档复制站”。

**Key Characteristics:**

- 高速导向而非霓虹炫技
- 大字、短句、真实命令
- 平面色块与结构性线条
- 有节制的路线动画
- 移动端与无 JavaScript 场景同样完整

## 2. Colors

颜色像夜间道路标识：大面积蓝色负责识别，黄色负责行动，青色负责路径，深色只承载终端和高密度状态。

### Primary

- **Warp Blue:** 品牌主表面、hero 与大区块的主色，承担约 30–50% 的首屏视觉面积。
- **Deep Route:** Warp Blue 上的深层结构色，用于切角、方向线阴影和按压状态。

### Secondary

- **Route Cyan:** 路径、连接、活动状态和 logo 连续性的强调色；不用于大段正文。
- **Signal Yellow:** 唯一高优先级行动色，用于主要 CTA、复制成功和重要路标。

### Tertiary

- **Clean Green:** 仅表达 clean、ready、success 等真实状态。
- **Attention Red:** 仅表达 dirty、error、attention 等真实状态。

### Neutral

- **Midnight Asphalt:** 终端、页脚和高密度状态区的背景。
- **Cold Paper:** 大段阅读区的中性背景，避免米色或纸张拟物。
- **Clear White:** 深色和蓝色表面上的主要文本。
- **Slate Copy:** Cold Paper 上的辅助正文和说明文字。

**The Signal Rule.** Signal Yellow 只用于下一步行动；如果同一视口出现三个以上黄色焦点，层级已经失控。

**The Asphalt Rule.** Midnight Asphalt 不是全站默认背景，只在真实终端、状态和收尾区出现；禁止把整个页面做成泛用深色 SaaS。

## 3. Typography

**Display Font:** Barlow Condensed（Bahnschrift / Arial Narrow 回退）  
**Body Font:** Manrope（Segoe UI Variable / Noto Sans SC 回退）  
**Label/Mono Font:** Cascadia Code（JetBrains Mono / SFMono-Regular 回退）

**Character:** 窄体 display 像交通标识和设备铭牌，适合高冲击短句；宽松的人文 sans 保证中英文长文可读；mono 仅用于真实命令、路径和状态，不作为“技术感”装饰。

### Hierarchy

- **Display**（700，fluid 3.6–6rem，0.9）：首屏唯一主张，最多三行，字距不低于 -0.025em。
- **Headline**（650，fluid 2.4–4.5rem，0.95）：区块转折与核心痛点，不重复 hero 的语气。
- **Title**（650，1.25–1.5rem，1.2）：功能名称和交互面板标题。
- **Body**（450，1–1.125rem，1.7）：解释和叙事，最大行宽 70ch。
- **Label**（600，0.8125rem，0.02em）：命令、状态和控件标签；只对极短英文标签使用 uppercase。

**The Real Mono Rule.** Mono 字体只出现在访客可以复制、执行或核验的内容上；无意义的伪代码和装饰字符一律禁止。

## 4. Elevation

系统默认平面，通过色块、遮挡顺序、轨迹线和边界对比建立层次。阴影只在浮动导航、复制反馈或悬停状态中作为短暂响应，不与 1px 装饰边框组成 ghost-card。

### Shadow Vocabulary

- **Nav Float** (`0 6px 8px rgba(7, 16, 31, 0.16)`): 仅用于滚动后的顶部导航。
- **Action Lift** (`0 4px 8px rgba(7, 16, 31, 0.20)`): 仅用于主要按钮 hover，元素离开状态后立即归零。

**The Flat-At-Rest Rule.** 静止表面必须平坦；阴影是交互反馈，不是卡片装饰。

## 5. Components

### Buttons

- **Shape:** 设备控制键式圆角（10px），不用大药丸包裹长文案。
- **Primary:** Signal Yellow 配 Midnight Asphalt，最小高度 48px，文案以动作开头。
- **Hover / Focus:** 上移 2px 并出现 Action Lift；focus-visible 使用 3px Clear White / Warp Blue 双层焦点环。
- **Secondary:** 深色实底或透明文本按钮；禁止半透明玻璃按钮。

### Chips

- **Style:** 仅用于平台、状态或真实过滤条件；短文本、全圆角、颜色与状态语义一致。
- **State:** 选中状态用实色，不选中状态用文本和低对比底色；不得仅靠颜色区分。

### Cards / Containers

- **Corner Style:** 紧致圆角（14px）或切角终端窗口，不超过 16px。
- **Background:** 通过 Warp Blue、Cold Paper、Midnight Asphalt 三种实体表面分层。
- **Shadow Strategy:** 默认无阴影，遵循 Elevation 章节。
- **Border:** 只用于结构边界；不与宽柔阴影同时出现。
- **Internal Padding:** 20–32px，演示窗口可扩展到 56px。

### Inputs / Fields

- **Style:** 10px 圆角、实体背景、清晰标签，最小高度 48px。
- **Focus:** 颜色切换和 3px 可见焦点环，不依赖 glow。
- **Error / Disabled:** 同时提供图标或文本说明，不能只变红或降透明度。

### Navigation

桌面导航保持轻量并悬浮在 hero 上方；滚动后转为实体 Midnight Asphalt。移动端使用原生按钮展开垂直菜单，支持 Escape 关闭、焦点可见和 44px 触控目标。

### Command Rail

命令轨道是签名组件：左侧选择真实 `cdp` 命令，右侧终端同步展示输入、路由和结果。激活项由 Signal Yellow 导向标和 `aria-selected` 双重表达，键盘方向键可切换。

## 6. Do's and Don'ts

### Do:

- **Do** 用真实命令、真实项目状态和演示视频证明价值。
- **Do** 让 Warp Blue 占据明确表面，并让 Signal Yellow 保持稀缺。
- **Do** 将动画设计成路径绘制、目的地锁定和状态到达。
- **Do** 保证 360px 到 1440px 视口内标题不溢出、正文不超过 70ch。
- **Do** 为所有动画提供 reduced-motion 路径，为所有交互提供键盘和焦点状态。

### Don't:

- **Don't** 使用“泛用深色 SaaS 模板”：渐变 hero、玻璃卡片和同构功能卡墙。
- **Don't** 使用“廉价赛博朋克”：满屏霓虹、故障闪烁和不可读装饰字符。
- **Don't** 使用“终端角色扮演”：无意义代码、装饰网格背景或全站 mono。
- **Don't** 做“文档复制站”，不能把 README 按章节原样搬上页面。
- **Don't** 使用渐变文字、彩色侧边粗条、超过 16px 的卡片圆角或 ghost-card 阴影组合。
- **Don't** 让任何状态只依赖颜色表达，或让 JavaScript 决定核心内容是否可见。
