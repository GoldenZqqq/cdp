# CLAUDE.md

Follow [`AGENTS.md`](./AGENTS.md) as the canonical repository instruction file.
It owns development workflow, safety rules, version/document synchronization,
release publishing, commit format, and cross-platform validation. This file is
intentionally short so agent-specific instructions cannot drift.

## Quick Architecture

- `cdp.psd1`: canonical PowerShell version and public exports.
- `src/cdp.psm1`: stable PowerShell bootstrap/export surface.
- `src/PowerShell/*.ps1`: bounded PowerShell implementation domains.
- `src/Shell/*.sh`: canonical bash/zsh sources.
- `src/cdp.sh`: generated shell distribution; never edit it directly.
- `scripts/`: repository-owned build, quality, package, documentation, and
  release gates.
- `tests/`: Pester, shell, Node, and Playwright regressions.
- `docs/`: static website and governed published media.

## Quick Validation

```powershell
.\scripts\Invoke-PowerShellQualityGate.ps1
```

```bash
bash ./scripts/Build-ShellScript.sh --check
bash ./scripts/Test-ScoopPackage.sh
node ./scripts/Test-Documentation.mjs
pnpm --dir tests/web test
```

Read the active Trellis task and `.trellis/spec/{backend,frontend}/index.md`
before implementation. Do not push, tag, publish, delete files, or rewrite Git
history unless the user explicitly authorizes the operation required by
`AGENTS.md`.
