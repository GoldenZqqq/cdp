# 增加跨平台路径 profile

## Goal

让同一份项目配置在 Windows、WSL、Linux 和 macOS 上稳定解析到当前
运行环境的本地路径，同时保持现有 Project Manager `rootPath` 配置和旧版
cdp 的读取能力。

## Background

- 当前 PowerShell 文件系统、Git、picker、workspace 和 status 路径大多直接
  使用 `rootPath`；shell 仅通过 `convert_windows_to_wsl` 做 Windows 到 WSL
  的单向转换。
- v2.2.0 status JSON 已区分 `rawPath` 与 `resolvedPath`，但 PowerShell 当前
  两者仍相同，shell 只反映旧的 WSL 转换。
- 配置仍必须是 Project Manager 兼容的顶层数组，cdp 只能为项目对象增加
  可被旧消费者忽略的可选字段。

## Requirements

### R1. 配置契约与兼容性

- `rootPath` 继续作为必填、稳定的原始配置身份和旧版本 fallback。
- 可选 `paths` 对象支持 `windows`、`wsl`、`linux`、`macos` 四个键；已声明
  的键必须是非空字符串。
- 未配置 `paths` 的旧项目保持原行为，无需迁移。
- 未知项目字段和未知 `paths` 键必须无损保留，便于向前兼容。

### R2. 环境识别与 override

- 默认运行环境按 Windows、WSL、Linux、macOS 确定；Git Bash/MSYS/Cygwin
  shell 归入 `windows`。
- `CDP_PATH_PROFILE` 可显式覆盖检测结果，允许值仅为
  `windows|wsl|linux|macos`，大小写不敏感。
- 非法 override 是命令级错误，不得静默回到自动检测。

### R3. 解析优先级

1. 使用显式 `paths.<当前 profile>`（存在时优先级最高）。
2. 当前 profile 为 WSL 且未显式配置时，将 Windows `rootPath` 转换为
   `/mnt/<drive>/...`；非 Windows 路径保持原值。
3. 其他环境未显式配置时直接使用 `rootPath`。

- 如果当前 profile 已显式声明但值无效或目标目录不存在，必须报告该显式
  路径的问题，不得回退到 `rootPath` 或其他平台路径。
- 缺少当前 profile 映射仍允许使用 `rootPath` fallback，以维持旧配置兼容。

### R4. 统一消费边界

- switch、picker/list、doctor、repair、status/fix/push、workspace、hooks 的
  工作目录，以及后续 multi-repo exec 都必须复用同一 resolver 契约。
- 配置身份、recent 状态、hook fingerprint 和破坏性 mutation 匹配继续使用
  raw `rootPath`；文件系统、Git、launcher 和 tmux 使用 resolved path。
- PowerShell `-WSL` 显式按 `wsl` profile 解析，不受宿主 Windows profile
  限制。

### R5. add/scan/init 与安全修复

- add/scan/init 新增项目时同时写入本地绝对 `rootPath` 和
  `paths.<当前 profile>`；旧版 cdp 仍可读取 `rootPath`。
- 读取、repair 和其他 mutation 不得删除或重写已有 `paths` / 未知字段。
- repair/status fix 对旧式 fallback 缺失路径保留既有行为；显式 profile
  路径缺失只报告并保留项目，避免在共享配置中破坏其他平台有效项目。
- 显式 profile 结构无效时 repair 必须失败且不写配置。

### R6. 诊断与机器输出

- 人类输出应包含项目名、当前 profile 和 resolved path，且错误可操作。
- status JSON schema version 1 保持 `rawPath=rootPath`，`resolvedPath` 为统一
  resolver 结果。
- 显式 profile 结构错误使用稳定的 `path_profile_invalid` status/reason；
  显式路径不存在仍使用 `path_missing`，并保留实际 resolved path。
- 非法 `CDP_PATH_PROFILE` 在 JSON 模式使用 fatal exit code 3 和 stderr；单项目
  profile 问题不阻止其他项目扫描。

## Out of Scope

- 自动猜测 Linux/macOS 与 Windows 路径之间的任意映射。
- 自动迁移或重写所有旧项目配置。
- 为本任务新增 CLI 子命令来编辑单个 profile；用户可直接编辑 JSON，后续
  可单独增加管理命令。
- 本任务不实现 multi-repo exec，只保证 resolver 可直接复用。

## Acceptance Criteria

- [x] 共享 fixture 在 `windows`、`wsl`、`linux`、`macos` 四个 profile 下由
  PowerShell 与 bash/zsh 选择相同的预期路径。
- [x] `CDP_PATH_PROFILE` 自动检测/覆盖、大小写和非法值均有回归测试。
- [x] 旧配置无需迁移，WSL Windows 路径转换保持兼容。
- [x] 显式当前 profile 缺失目录时不回退到 `rootPath`，status JSON 保留正确
  raw/resolved path，switch/workspace 不进入错误目录。
- [x] add/scan/init 写入 `rootPath` 与当前 `paths` 映射；repair、status fix 和
  元数据 mutation 无损保留已有映射及未知字段。
- [x] PowerShell 7、bash/zsh/Bash 3.2、analyzer、生成 shell、双语文档与
  release metadata 本地门禁通过；PowerShell 5.1 兼容语法保留并纳入最终
  hosted release matrix。
