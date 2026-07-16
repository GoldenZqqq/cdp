# CLI 参数解析设计

## Scope

本任务只负责把入口 token 解释为结构化 invocation，并修复为传递解析结果所必需的轻量参数流。status 数据采集、workspace 布局、配置写入安全和模块拆分属于后续任务。

## Current Problems

PowerShell 参数绑定先把第二个 token 放入 `ConfigPath`，随后 `Invoke-Cdp` 又按子命令重新解释它；`ConvertFrom-CdpInvokeArguments` 只寻找 `--open`，不消费 token。结果是 flag、tag、项目名和 config path 依赖排列顺序。

bash/zsh 的顶层先分派子命令，`cdp-status` 已能循环解析多个参数，但 `cdp-workspace` 仍把 `--open` 当项目名且只能使用默认 config。

## Architecture

### PowerShell

1. `Invoke-Cdp` 把 PowerShell 已绑定的 `Command`、`ConfigPath`、`RemainingArgs` 和显式 named parameters 交给纯解析函数。
2. 纯解析函数按子命令委派到短小 parser，返回统一对象：
   - `Kind`
   - `ConfigPath`
   - `Query`
   - `Open`
   - `Options` / `Arguments`
3. parser 消费每个 token；未知、缺值、重复或冲突选项抛出可读异常。
4. 路由层只读取结构化对象并调用现有公开函数。
5. `Get-CdpWorkspacesPath` / `Invoke-CdpWorkspace` 增加可选 `ConfigPath`，只为正确传递解析结果。

### bash/zsh

1. 顶层继续把原始参数交给子命令函数。
2. `cdp-workspace` 使用循环消费 `--open/-o`、`--config` 和 action 参数。
3. `cdp-status` 保持循环模型，补冲突和未知 option 校验。
4. 管理命令继续支持现有位置参数；新增显式 `--config` 时优先使用显式值。

## CLI Contract

### status

- 可组合：`--dirty/-d`、一个 `@tag`、一个 config path。
- 动作：`--fix` 或 `--push`，两者互斥。
- `--dirty` 与动作互斥，避免“过滤展示”与“批量动作”语义混合。
- 未知 `-` 开头 token、重复 tag/config 和缺少 option 值均报错。

### workspace

- `workspace --list [--config path]`
- `workspace --add name project... [--open launcher] [--config path]`
- `workspace name [--open launcher] [--config path]`
- `--open/-o` 与 `--config` 的 token 必须被完全消费。

### management

- pin/unpin：项目名 + 可选 config。
- alias/unalias/tag/untag：项目名 + value + 可选 config。
- clean/doctor --fix：可选 config。
- init/scan：保持现有 root 参数并传递可选 config/depth；不改变底层扫描规则。

## Compatibility

- `cdp`、`cdp api`、`cdp api config.json`、`cdp api -Open codex` 保持不变。
- PowerShell named `-ConfigPath/-Query/-Open/-WSL` 优先于位置推断。
- 现有公开函数签名只添加可选参数，不删除或重排已有参数。

## Rollback

解析与路由修改集中在入口 helper、`Invoke-Cdp`、workspace 参数流和对应测试。若出现回归，可整体回退本任务提交，不涉及配置迁移或持久化格式变化。
