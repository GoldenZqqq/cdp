# v2.1.0 Release Implementation

1. Audit the nine archived engineering tasks and their work commits.
2. Verify local/remote branch and tag identity without mutating Git history.
3. Run the full local release matrix, including benchmark and fixed Bash 3.2.
4. Generate one retained release archive, verify contents/hash, and create
   release notes from the v2.1.0 changelog.
5. Update release readiness records and create the local release-preparation
   commit.
6. Stop at the external boundary if push authorization or Gallery key is absent.
7. When authorized, push, watch main CI, tag, create GitHub Release/upload asset,
   publish Gallery, verify public channels, then complete/archive the task.

## Evidence to Record

- Nine work commit SHAs and archived task paths.
- Local release commit SHA and remote main SHA.
- Pester count/coverage, shell matrices, Web counts, benchmark numbers.
- Asset path, byte size, SHA-256, and public download SHA-256.
- CI run id/conclusion, tag peeled SHA, Release URL, Gallery version/URL.

## Stop Conditions

- Dirty or unrecognized worktree changes.
- Remote main divergence without rebase authorization.
- Any local/hosted gate failure.
- Missing explicit authorization for write operations.
- Missing `PS_GALLERY_API_KEY` at the Gallery step.

## Local Completion Record

- [x] Audited nine archived child tasks and work commits.
- [x] Verified tracked/remote main identity and absent v2.1.0 tag read-only.
- [x] Passed full PowerShell, bash, zsh, Bash 3.2, Web, package, metadata,
  documentation, installer, generated artifact, and static-format gates.
- [x] Reran 50-repository Bash jobs=4/jobs=8 and PowerShell workers=4 benchmarks.
- [x] Generated one retained release asset and matching release notes.
- [x] Recorded local release evidence and readiness in `PROGRESS.md`.
- [x] Create release-preparation commit.
- [x] Obtain external authorization and push the release candidate.
- [x] Diagnose hosted CI fresh-checkout CRLF parsing and runner-umask archive
  mode drift; add regressions without changing the retained package digest.
- [ ] Push the repair, pass CI, tag, create the Release, publish Gallery if the
  environment key is available, and verify public channels.
