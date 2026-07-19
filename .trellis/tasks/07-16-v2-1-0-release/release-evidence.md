# v2.1.0 Release Evidence

## Engineering Children

| Task | Work commit | Archived status |
|------|-------------|-----------------|
| Atomic JSON persistence | `904f538` | completed 2026-07-19 |
| Project hook trust | `c9dcacc` | completed 2026-07-19 |
| Safe mutations | `1f9e13d` | completed 2026-07-19 |
| PowerShell modularization | `1434353` | completed 2026-07-19 |
| Shell modularization | `156551f` | completed 2026-07-19 |
| Status performance | `89fed0b` | completed 2026-07-19 |
| CI quality gates | `a076ce3` | completed 2026-07-19 |
| Web/media quality | `64a0632` | completed 2026-07-19 |
| Spec/documentation refresh | `1f1a284` | completed 2026-07-19 |

All nine archived task documents report `status=completed`; every work commit
resolves as a commit object.

## Git Preflight

- Audited remote main: `85d798216a7561dcd6c1cae1ef29e47af2651f00`.
- Local `origin/main` matches GitHub `refs/heads/main` exactly.
- Audited remote main is an ancestor of local HEAD; no remote divergence.
- `v2.1.0` is absent locally and remotely.
- GitHub CLI account `GoldenZqqq` is authenticated with `repo` and `workflow`.
- `PS_GALLERY_API_KEY` is missing from the local environment.

## Hosted CI Repair

- Pushed release candidate `f4b7c183f6f696e56f7734a7744fb9334eb28421`
  to `main`; CI run `29702793941` matched that exact head SHA.
- Ubuntu exposed a fresh-checkout-only failure in the Scoop quality fixture:
  `.gitattributes` materialized `cdp.psd1` as CRLF while shell version parsing
  required an LF line ending. macOS and the pre-existing local worktree passed.
- Release scripts now strip the trailing carriage return before extracting
  `ModuleVersion`, and the quality fixture exercises an isolated CRLF checkout.
- The repaired local package remains byte-identical to the retained asset and
  Scoop manifest: `07e2b39dfdc77361b6abd0fe67f1bf2ad923deb7e81ce5a081b62755f71bb74c`.

## Local Quality Matrix

- PowerShell 7.5.2: Pester `98/98`, coverage `2097/3105` (`67.54%`),
  PSScriptAnalyzer Error severity clear, release metadata consistent.
- bash: modularization, CLI, status, performance regression, quality fixtures,
  safe mutations, v2 behavior, persistence, and installer tests passed.
- zsh: v2 behavior and persistence tests passed.
- Bash 3.2 fixed digest matrix passed modularization, CLI, status, safe
  mutations, v2 behavior, and persistence.
- Web: Node fixtures `11/11`; Playwright Chromium `6/6`; media baseline and
  documentation gates passed.
- Generated shell, bash syntax, ShellCheck, Scoop contents/hash, YAML/JSON,
  Trellis, spec placeholders, and whitespace passed.

## Status Benchmarks

| Runtime | Workers | Min | Median | P95 |
|---------|---------|-----|--------|-----|
| Bash 5.2.21 | 4 | 1.401s | 1.443s | 1.575s |
| Bash 5.2.21 | 8 | 1.324s | 1.370s | 1.505s |
| PowerShell 7.5.2 | 4 | 0.630s | 0.732s | 1.012s |

Each benchmark used 50 committed repositories, five runs, and cache TTL 0.

## Release Candidate Asset

- Path: `artifacts/release/cdp-2.1.0.tar.gz` (ignored retained artifact).
- Size: `91,067` bytes.
- SHA-256: `07e2b39dfdc77361b6abd0fe67f1bf2ad923deb7e81ce5a081b62755f71bb74c`.
- Scoop manifest hash matches exactly.
- Contents include manifest, installers, stable bootstrap, all PowerShell and
  Shell domains, and generated `src/cdp.sh`; repository-only files are absent.
- Release notes: `artifacts/release/v2.1.0-notes.md`.

## External Steps Pending

1. Commit and push the hosted CI repair, then watch its exact main CI run.
2. Create/push annotated `v2.1.0`, then GitHub Release and upload retained asset.
3. Set `PS_GALLERY_API_KEY`, publish Gallery, and verify exact v2.1.0.
4. Verify public GitHub/Scoop asset SHA and installation channels.
