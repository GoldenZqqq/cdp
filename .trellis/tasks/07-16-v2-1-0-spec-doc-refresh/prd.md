# 刷新项目规范与用户文档

## Goal

使 Trellis 规范、代理指南、架构说明、贡献指南和双语用户文档准确反映当前 v2.1.0 双运行时实现，并用自动化门禁阻止再次漂移。

## Background

- PowerShell 已由 `src/cdp.psm1` 稳定 bootstrap 加载 15 个 `src/PowerShell/*.ps1` domain；shell canonical 源位于 `src/Shell/*.sh` 并生成 `src/cdp.sh`。
- README 双语主体结构当前对齐且已覆盖多数 v2 功能，但 Development/CI/Contributing 仍引用旧 Pester 5.5 与四 job 基线，未明确 workspace/state/trust 文件关系。
- `AGENTS.md` 与 `CLAUDE.md` 的架构前言仍描述早期单文件/双导出模块，并保留与当前 Conventional Commits 冲突的 `Add:/Fix:` 示例。
- backend/frontend 除 quality 外共有 9 份模板 spec 含 `To fill` / `To be filled` 占位内容。

## Requirements

- 依据当前 PowerShell、shell、静态网站、测试和发布脚本，重写所有 backend/frontend 占位 spec；不适用的数据库/React hook 概念改写为本项目实际 JSON persistence / DOM lifecycle 契约。
- 更新 spec index 描述与状态，保留现有文件路径以避免链接迁移。
- README English canonical 与 README_ZH 保持相同 H2/H3 层级、代码块语言序列和命令覆盖。
- 在双语 README 中补充 config/state/workspace/hook-trust/lock/backup 关系及当前开发/CI 门禁。
- 更新 CONTRIBUTING、AGENTS 架构和提交规范；CLAUDE.md 只保留指向 canonical AGENTS.md 的简洁入口，消除重复规则。
- 新增仓库文档 gate 与负向 fixture，自动检查 manifest 导出、关键 v2 术语、双语结构、spec 占位符和过时指导。

## Acceptance Criteria

- [x] `.trellis/spec/backend` 与 `.trellis/spec/frontend` 不再含模板占位符，13 份规范及索引全部描述实际项目边界。
- [x] AGENTS/CONTRIBUTING/README 记录真实模块、生成物、状态文件关系、Conventional Commits 和完整验证命令。
- [x] documentation Node fixture `5/5` 与当前仓库 gate 通过，并故意拒绝结构漂移、缺失导出文档、spec 占位符和过时指导。
- [x] README 双语 H2/H3 结构、代码块语言序列及 39 个 manifest 函数/alias 覆盖自动一致。
- [x] 未改变 CLI、持久化或网站运行时行为。

## Verification Notes

- Documentation gate: 39 exports and 13 backend/frontend specs validated.
- Node fixtures: documentation `5/5`, media `6/6`; Playwright Chromium `6/6`.
- PowerShell quality: Pester `98/98`, coverage `2097/3105` (`67.54%`),
  PSScriptAnalyzer and release metadata passed.
- Scoop package: `07e2b39dfdc77361b6abd0fe67f1bf2ad923deb7e81ce5a081b62755f71bb74c`.
- Generated shell, workflow YAML, JSON, placeholders, Trellis, and whitespace
  checks passed.

## Out of Scope

- 新增或修改 cdp 命令行为。
- 删除/重命名 Trellis spec 文件。
- 发布 v2.1.0 或执行远程 push。
