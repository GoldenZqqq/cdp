# Frecency 智能排序技术设计

## 1. Shared ranking contract

Project identity uses exact configured `rootPath`. For each project, normalize one
recent record into integer metrics at a supplied UTC epoch:

```text
visits = clamp(valid integer visitCount, 1, 1000)
last = valid lastVisitedAt epoch, otherwise 0
ageDays = floor(max(0, now-last) / 86400)
score = last == 0 ? 0 : floor(visits * 1000000 / (ageDays + 1))
```

Sort by pin rank, score descending, last descending, visits descending, then
original config index. Projects without valid state all receive zero metrics, so
the current pinned/config order remains unchanged. Future timestamps clamp to
age zero. Duplicate state identities retain the record with the newest valid
timestamp, then the greater visit count.

## 2. Runtime boundaries

PowerShell adds `Frecency.ps1` between State and Picker. It owns state
normalization, scoring, and the extended `Sort-CdpProjectsForDisplay` contract.
`Switch-Project` and `Get-ProjectList` already share that sorter.

Shell adds `Frecency.sh` after State. It builds a bounded normalized recent map
with jq and returns sorted project JSON/names/rows. Config wrappers and the
multi-match query path reuse it; status, exec, and workspace keep their explicit
ordering contracts.

Both runtimes accept a fixed internal `now` input for fixtures. Public behavior
uses UTC now. `CDP_FRECENCY=0|false|off|no` disables only the score layer.

## 3. Reset lifecycle

`cdp recent reset` is a state mutation, not a project-config mutation. PowerShell
adds a `RecentReset` invocation field and a `Reset-CdpRecentProjects` ShouldProcess
command. Shell parses safety flags inside `cdp-recent`. Reset preserves unknown
top-level state fields, replaces only `recentProjects` with `[]`, uses the shared
atomic writer/fingerprint contract, and skips an already-empty state without a
backup or byte change. Invalid active state is read-only.

## 4. Compatibility and rollback

- No project or state schema version change is required.
- Existing recent entries with PowerShell `+00:00` or shell `Z` timestamps are
  parsed from the shared UTC `YYYY-MM-DDTHH:MM:SS` prefix.
- PowerShell 5.1 uses integer/DateTimeOffset operations; shell uses jq integer
  arithmetic and avoids GNU-only date parsing.
- Rollback removes the sorter layer and reset route without rewriting state.
