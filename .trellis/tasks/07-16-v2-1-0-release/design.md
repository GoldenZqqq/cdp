# v2.1.0 Release Design

## Release Identity

- Version: `2.1.0`; tag: `v2.1.0`.
- Canonical version: `cdp.psd1` `ModuleVersion`.
- Release commit: the final local release-preparation commit after all gates.
- Asset: `artifacts/release/cdp-2.1.0.tar.gz`, generated once by
  `scripts/New-ScoopPackage.sh` and not rebuilt between hash verification and
  GitHub upload.
- Scoop hash: exact SHA-256 of that asset.

## Preflight Audit

Verify each engineering child task has a completed archived `task.json`, a work
commit, and no missing documented acceptance. Verify the parent has only the
release child remaining.

Read-only remote checks compare `refs/heads/main` and `refs/tags/v2.1.0` without
changing local history. Any remote divergence stops before release preparation.

## Local Quality Matrix

1. PowerShell 7.5.2 unified quality gate; Windows PowerShell 5.1 remains hosted
   CI and runs the identical script.
2. Generated shell, syntax, ShellCheck, bash/zsh shared regressions, installer,
   persistence, safe mutations, CLI/status, and fixed Bash 3.2 container matrix.
3. Status benchmark with the fixed 50-repository fixture.
4. Documentation/media Node fixtures and current gates plus Chromium Playwright.
5. Deterministic package content/hash, release metadata, YAML/JSON, Trellis, and
   whitespace.

The generated release asset is retained for upload. Record its byte size,
SHA-256, and top-level content.

## Remote Release Sequence

After explicit authorization:

1. Confirm remote main still matches the audited remote SHA; rebase only if the
   user authorizes and remote changed.
2. Push local main and watch the exact main CI run to success.
3. Create annotated `v2.1.0` at the verified release commit, push it, and verify
   local/remote peeled tag SHAs.
4. Create a non-draft, non-prerelease GitHub Release from the verified tag and
   upload the retained archive.
5. Download the public asset and compare SHA-256 with Scoop.
6. Publish Gallery only when `PS_GALLERY_API_KEY` is present; verify with
   `Find-Module` and the exact package page.
7. Verify Scoop URL returns the same asset and run source/Scoop install smoke in
   isolated locations where the host supports it.

## Rollback

- Before tag/release: fix, recommit, rerun gates.
- After tag but before public Release/Gallery: move the annotated tag only after
  the fix commit is pushed and revalidated.
- After a public channel publishes: do not silently replace artifacts; publish
  a patch release when immutable channel contents are wrong.
- Missing push authorization or Gallery key is an external blocker, not a
  reason to weaken or falsely mark the release complete.
