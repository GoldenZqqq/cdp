# v2.2.0 Release Evidence

## Audit

- Baseline before release preparation: `main` and `origin/main` at
  `9bc3b11b7747346723e26796a21d1f29a3b698eb`.
- Release design commit pushed as `bf7bed8e299b1c3fe2ef58c1fa461488efaf5737`.
- Five child-task implementation/archive commit pairs are reachable from the
  release branch:
  - status JSON: `a0a7c396082b222c4fb9b9ed0dceb8dd99dd5a39`,
    `5dfa68db9fe751fcc7dadb04c02b4094d5f6d4fd`.
  - path profiles: `03f7af48e5823f3ee8ddefb2133d5726c936a1a4`,
    `11329579f53fee0d27f760933de17430da9d4a7e`.
  - workspace lifecycle: `52596c5e1e93382273c9de6cd59aed5e22946eab`,
    `b60f339c37a6ee5744d0de4e211204c0ac494bf7`.
  - multi-repository exec: `11b5435aaf213c7facb20773ae5a567a736e02b1`,
    `7e9debedbda217eaa796836a7bc82c4d2c07df61`.
  - frecency ranking: `99655214d90103bb2eef939e278028a4f7285bb6`,
    `4c87850bd6aa4099e7d1e69c7d488a5fb1a959e1`.
- Remote `v2.2.0` tag and Release were absent during the preflight audit.

## Quality Gates

- Hosted baseline CI `29799179690`: all five jobs passed, including Windows
  PowerShell 5.1 and PowerShell 7.
- Final release CI `29800666822` for commit
  `b2a1e7beb44d13fa07079f77812233ec60df854c`: all five jobs passed.
- ARM64 PowerShell 7.5.0 container: Pester `156/156`, coverage `3795/5130`
  (`73.98%`), no PSScriptAnalyzer Error findings, release metadata passed.
- Bash/zsh and fixed Bash 3.2 contract, persistence, safe-mutation, status,
  status JSON, path profile, workspace, exec, frecency, modularization,
  performance, installer, ShellCheck, and syntax gates passed.
- Documentation gate: 40 exported commands and 14 specs. Web asset/media gate:
  12 published and 13 repository media files, `67,433,719/69,115,162` bytes.
  Playwright Chromium smoke passed `6/6` and Node fixtures passed `11/11`.
- Status benchmark, 50 repositories and 5 runs: jobs=4 min/median/p95
  `2.967/3.076/3.536s`; jobs=8 `2.852/2.994/3.486s`.

## Candidate Asset

- Path: `artifacts/release/cdp-2.2.0.tar.gz`.
- Size: `141,245` bytes; entries: `54`.
- SHA-256: `87130587dd8028666e84f0e0beb9726374c2767c43f65222bf787323430c5e9a`.
- `scoop/cdp.json` declares the same hash, version, URL and extract directory.
- Independent second build matched the retained archive byte-for-byte.
- Public GitHub Release and Scoop downloads were both `141,245` bytes and
  matched the retained archive byte-for-byte.

## Installation Smoke

- Temporary HOME shell install copied `src/cdp.sh`, matched the declared
  installer digest, and `cdp --version` reported v2.2.0.
- Isolated ARM64 PowerShell package install from the candidate archive reported
  module version `2.2.0` at the expected CurrentUser module path.

## Publication Result

- Release commit: `b2a1e7beb44d13fa07079f77812233ec60df854c`.
- Annotated tag `v2.2.0` peels to the release commit locally and remotely.
- GitHub Release: https://github.com/GoldenZqqq/cdp/releases/tag/v2.2.0;
  public, latest, non-draft, and non-prerelease.
- Tag-pinned public shell installation downloaded the expected `cdp.sh` hash
  and reported v2.2.0.
- PowerShell Gallery remains at v2.0.4. Neither the local environment nor
  repository Actions secrets contains `PS_GALLERY_API_KEY`. The Gallery package
  endpoint redirected a v2.2.0 request to `cdp.2.0.4.nupkg`, so its final HTTP
  200 was not accepted as exact-version evidence.
