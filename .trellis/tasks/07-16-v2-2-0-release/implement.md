# v2.2.0 Release Implementation

1. Audit the five archived automation tasks, their work commits and completion evidence.
2. Verify local/remote branch identity, absent v2.2.0 tag/Release and synchronized version/migration/public documentation metadata.
3. Run the full local release matrix, including the fixed Bash 3.2 image, Web/Playwright, benchmark, installer, package and metadata gates.
4. Generate one retained release archive plus a second temporary determinism check; record contents, byte size and SHA-256.
5. Update `PROGRESS.md` and release evidence with final local/hosted results, then create and push the final release commit.
6. Watch the exact `main` CI run for the final commit and stop on any failure.
7. Create and verify annotated tag `v2.2.0`, create the GitHub Release and upload the retained asset.
8. Verify public GitHub/Scoop bytes and isolated install paths; publish and verify Gallery only when the API key exists.
9. Record final evidence, archive the release and completed parent tasks, commit/push the archival state and verify the resulting CI.

## Validation Commands

```bash
pwsh -NoLogo -NoProfile -File ./scripts/Invoke-PowerShellQualityGate.ps1 -ReportDirectory ./artifacts/powershell-7
bash ./scripts/Build-ShellScript.sh --check
shellcheck --severity=error --exclude=SC2296 ./src/cdp.sh ./src/Shell/*.sh ./install-wsl.sh ./scripts/*.sh ./tests/*.Tests.sh
bash ./tests/cdp.Shell.Modularization.Tests.sh
bash ./tests/cdp.Cli.Tests.sh
bash ./tests/cdp.Status.Tests.sh
bash ./tests/cdp.Status.Json.Tests.sh
bash ./tests/cdp.PathProfiles.Tests.sh
bash ./tests/cdp.Frecency.Tests.sh
bash ./tests/cdp.Workspace.Lifecycle.Tests.sh
bash ./tests/cdp.Exec.Tests.sh
bash ./tests/cdp.Status.Performance.Tests.sh
bash ./tests/cdp.QualityGates.Tests.sh
bash ./tests/cdp.SafeMutations.Tests.sh
bash ./tests/cdp.Shell.V2.Tests.sh
bash ./tests/cdp.Persistence.Tests.sh
zsh ./tests/cdp.Shell.V2.Tests.sh
zsh ./tests/cdp.Persistence.Tests.sh
bash ./tests/cdp.Installer.Tests.sh
bash ./scripts/Test-ScoopPackage.sh
node ./scripts/Test-Documentation.mjs
pnpm --dir tests/web install --frozen-lockfile
pnpm --dir tests/web test
git diff --check
```

The pinned Bash 3.2 command and any additional repository-owned validation are taken from `.github/workflows/test.yml` and existing release guidance to avoid command drift.

## Evidence To Record

- Five work commit SHAs and archived task paths.
- Local/final release commit SHA and remote `main` SHA.
- Pester count/coverage, analyzer result, shell matrices, Web counts and benchmark result.
- Asset path, byte size, SHA-256, archive entries and public download SHA-256.
- CI run id/conclusion, tag peeled SHA, GitHub Release URL and Gallery version/URL or exact credential blocker.

## Stop Conditions

- Dirty or unrecognized worktree changes.
- Remote `main` divergence that cannot be cleanly rebased.
- Any local or hosted release gate failure.
- Existing remote `v2.2.0` identity that does not match the planned release commit.
- Missing `PS_GALLERY_API_KEY` at the Gallery step; record it without printing or soliciting the secret.

## Completion Checklist

- [x] Audit prerequisites and release metadata.
- [x] Pass the full local release matrix.
- [x] Generate and verify the retained deterministic asset.
- [ ] Push the final release commit and pass exact hosted CI.
- [ ] Publish and verify tag, GitHub Release, asset and Scoop.
- [ ] Publish/verify Gallery or record the sole external credential blocker.
- [ ] Archive release, automation and roadmap tasks with final evidence.

## Local Completion Record

- Five archived child-task commit pairs and reachability from `main` verified.
- Local shell, zsh, fixed Bash 3.2, Web/Chromium, documentation, installer,
  performance, package, and metadata gates passed.
- ARM64 PowerShell 7.5.0 container passed Pester `156/156`, coverage
  `3795/5130` (`73.98%`), PSScriptAnalyzer, and release metadata.
- Candidate archive is `141,245` bytes with SHA-256
  `87130587dd8028666e84f0e0beb9726374c2767c43f65222bf787323430c5e9a`;
  an independent second build matched byte-for-byte.
