# Hook Trust Implementation

1. Add PowerShell trust-path, normalization, fingerprint, store, permission,
   lookup, trust, list, and revoke helpers using atomic persistence.
2. Extend the PowerShell parser and dispatcher for `hook` commands and
   `--no-hook`, then apply the documented switch precedence.
3. Add equivalent bash/zsh trust helpers, permission handling, command parser,
   and switch precedence without Bash 4-only syntax.
4. Add PowerShell and shared shell tests for redacted untrusted hints,
   one-switch authorization, persistent trust, command/config invalidation,
   revoke/list, no-hook, invalid env keys, failure isolation, invalid store,
   and file permissions.
5. Synchronize English/Chinese docs, release notes, completion, and CI entries;
   regenerate installer and Scoop digests after final source changes.
6. Run full Pester, PSScriptAnalyzer, bash/zsh/Bash 3.2 suites, ShellCheck,
   release metadata, deterministic package, YAML/JSON, Trellis, and diff gates.

## Rollback

Revert command routing and trust helpers together. An unused fingerprint-only
trust store may remain safely; rollback never executes or reconstructs commands
from it.
