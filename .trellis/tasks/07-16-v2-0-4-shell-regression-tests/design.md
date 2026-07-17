# bash/zsh v2 回归测试设计

## Scope

将跨 shell 的 v2 switch、workspace、hook、completion、依赖错误与路径行为收敛到一个仓库脚本。保留现有 parser/status 专项脚本，不在本任务内拆分 `src/cdp.sh`。

## Test Entry

```text
bash tests/cdp.Shell.V2.Tests.sh
zsh  tests/cdp.Shell.V2.Tests.sh
```

脚本通过 `$0` 解析 repo root，避免依赖 bash-only `BASH_SOURCE`。共享场景只使用两种 shell 都支持的函数、`[[ ]]`、local variables 与 command substitution；shell-specific completion setup 放在明确分支中。

## Scenario Groups

1. Dependency/config errors：jq、git、fzf 缺失，missing/invalid JSON config。
2. Core lifecycle：direct switch、recent、pin/unpin、clean、alias/tag、launcher dry-run、init/scan。
3. onEnter：object env + bash hook、legacy failure isolation。
4. workspace：add/list、包含空格路径、fake tmux launch、missing project skip。
5. completion：subcommand、enabled project、disabled exclusion、launcher。
6. path/arguments：Windows path conversion、explicit config、`--open` consumption。

## Isolation Contracts

- 所有 config/state/repo/workspace/fake executable 位于 `mktemp -d`。
- cleanup trap 只删除该已解析临时目录。
- fake `tmux` 只追加参数到日志并返回成功；不连接真实 session。
- launcher 使用 `CDP_OPEN_DRY_RUN=1`。
- dependency-negative 场景在子 shell 中覆盖 `PATH`，不会污染后续场景。
- hook 只执行 builtin `export` 或 `false`。

## Completion Adapter

- bash：设置 `COMP_WORDS`、`COMP_CWORD`，调用 `_cdp_completions`，断言 `COMPREPLY`。
- zsh：设置 `words`、`CURRENT`，用测试 `compadd` 捕获 completion function 提交的数组值。
- 两端共享同一临时 config 与期望名称。

## CI Shape

Ubuntu 调用共享入口的 bash 模式；macOS 调用同一入口的 zsh 模式。现有 syntax、CLI parser、status test steps 保留，但删除两段内联 smoke。

## Regression-Discovered Compatibility Fixes

- launcher metadata 使用 ASCII file separator，避免 shell `read` 折叠连续 tab 后把 label 读成 argument。
- workspace 与 scan 的项目流使用专用 fd 3，避免循环体内子进程消费后续输入。
- shell 层不绑定 zsh 特殊数组名 `path`，raw/config/resolved path 分别使用语义化变量名。
- zsh completion helper 在局部关闭 `KSH_ARRAYS`，保持 compsys 的 1-based `CURRENT` 语义；真实 wrapper 与测试 helper 分离。
- NUL 分隔目录迭代显式使用 `$'\0'`，由 bash 与 zsh 共用。

## Rollback

回退单一工作提交即可恢复旧 CI 内联 smoke。测试不迁移用户配置，也不产生远程副作用。
