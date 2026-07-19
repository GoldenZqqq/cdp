# 跨平台路径 profile 技术设计

## 1. 配置模型

项目对象保持 Project Manager 兼容：

```json
{
  "name": "api",
  "rootPath": "C:/Work/api",
  "enabled": true,
  "paths": {
    "windows": "C:/Work/api",
    "wsl": "/home/me/work/api",
    "linux": "/srv/work/api",
    "macos": "/Users/me/work/api"
  }
}
```

`rootPath` 是 raw identity 与旧版 fallback；`paths` 是可选增强字段。读取和
mutation 使用原对象，禁止重建白名单对象导致未知字段丢失。

## 2. Resolver 契约

新增窄领域文件：

- `src/PowerShell/Paths.ps1`
- `src/Shell/Paths.sh`

PowerShell `Resolve-CdpProjectPath` 返回：

```text
RawPath, ResolvedPath, Profile, Source, IsExplicit, ErrorCode, ErrorMessage
```

shell 提供同语义的 profile 检测与 project JSON 解析函数；普通调用输出
resolved path，调用者可读取全局/结构化字段取得 raw/source/error。两个实现
共享 `tests/fixtures/path-profiles.json` 作为行为契约。

### 2.1 Profile 检测

1. 若 `CDP_PATH_PROFILE` 非空，规范化为小写并验证允许值。
2. PowerShell：兼容 5.1 地检测 Windows；Linux 上先识别 WSL，再区分 Linux；
   Darwin 为 macOS。
3. shell：`uname -s/-r` 与 WSL 环境变量识别；MINGW/MSYS/CYGWIN 为 Windows。

非法 override 抛出/返回失败，命令不得继续使用 fallback。

### 2.2 路径选择

```text
project + requested/detected profile
  -> validate rootPath
  -> validate optional paths object
  -> explicit paths[profile] exists?
       yes: select it, never fallback
       no + profile=wsl: convert Windows rootPath
       no: select rootPath
```

resolver 本身不要求目录存在；存在性属于 filesystem consumer。这样 status
可以把选择结果完整投影到 JSON，也允许 `-WSL` 把 Linux-only 路径传给 WSL，
而不被 Windows 宿主的 `Test-Path` 误判。

## 3. 数据流与身份边界

```text
projects.json object
  -> resolver(raw rootPath + optional paths)
  -> resolved local path
  -> picker / Test-Path / Set-Location / git -C / tmux / launcher

raw rootPath
  -> recent identity / hook fingerprint / duplicate identity / mutation match
```

status normalized info 同时携带 `RootPath`（raw）和 `ResolvedPath`。缓存 key
包含项目 identity、profile 与 resolved path，避免切换 override 后复用错误结果。

## 4. 各领域集成

### 4.1 Switch、picker 与 list

- picker 行与 preview 显示 resolved path；选择仍通过项目名/raw identity 回查。
- 普通切换解析当前 profile 后再校验目录并 `Set-Location`。
- PowerShell `-WSL` 强制解析 `wsl`，不使用宿主 `Test-Path`；`wsl --cd` 的
  native exit code 决定成功与否。
- direct query 同时搜索 `rootPath` 与所有字符串 `paths` 值。

### 4.2 Status

- collector 接收已解析或可自行解析的项目对象，Git 始终使用 resolved path。
- `RawPath` 保持 `rootPath`；`ResolvedPath`、`PathProfile`、`PathSource` 进入
  normalized info。
- invalid explicit mapping 不运行 Git，状态为 `path profile invalid`；JSON
  status/reason 为 `path_profile_invalid`。
- `--push` 使用 resolved path。
- `--fix` 只删除非显式 fallback 的 missing entry；显式 missing entry 输出
  skipped 诊断并保留。

### 4.3 Workspace、health 与 repair

- workspace 计划阶段先解析所有项目，后续 launcher/WT/tmux 只接收 resolved
  path；单项目失败不阻止其他安全项目。
- doctor 分开报告 schema-invalid profile 和当前 profile missing path。
- repair 用 resolver 检查 enabled 项目；invalid mapping 中止且不写入；显式
  missing 仅统计并保留，legacy fallback missing 维持禁用行为。

### 4.4 Add、scan 与 init

- 当前目录解析为物理绝对路径。
- 新项目保持 `rootPath=<absolute>`，并新增
  `paths: { <currentProfile>: <absolute> }`。
- duplicate raw identity 规则保持不变；已有项目不被自动补写或迁移。
- init 继续委托 scan，因此只维护一个新增项目写入边界。

## 5. Shell 兼容设计

- `Paths.sh` 放在 `Config.sh` 之后、`State.sh/Picker.sh` 之前；生成脚本只能通过
  `scripts/Build-ShellScript.sh` 更新。
- 不使用关联数组、`${var,,}`、`local -n`、`mapfile` 等 Bash 4+ 特性。
- project 对象通过 `jq -c` 一行一个传递；不使用可能破坏路径内容的手写 JSON。
- 不声明名为 `path` 的 zsh special variable。

## 6. 兼容、迁移与回滚

- 旧版 cdp 与 Project Manager 忽略 `paths`，继续读取 `rootPath`。
- 新版对旧配置使用原 fallback，WSL 转换保持兼容。
- 不执行批量迁移；用户可逐步添加平台映射。
- 回滚代码只需移除 resolver 集成；配置中的 `paths` 不影响旧版读取，无需
  数据回滚。

## 7. 风险与控制

- **跨平台误删**：显式 profile missing 不参与 fix/repair 破坏性 mutation。
- **raw/resolved 混淆**：normalized info 明确双字段，mutation 仅匹配 raw。
- **worker 丢失 helper**：PowerShell status runspace helper 注入 resolver 所需
  函数，或在进入 worker 前把解析结果附加到副本。
- **shell 漂移**：共享 fixture、bash/zsh/Bash 3.2 与生成产物检查共同约束。
- **非法 override 污染所有命令**：入口早失败；JSON fatal 使用 stderr/code 3。
