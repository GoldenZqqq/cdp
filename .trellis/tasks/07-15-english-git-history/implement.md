# Implementation Plan

## 1. Freeze Baseline

- Record local and remote branches, tags, releases, rulesets, and all commit metadata.
- Create and verify a complete baseline Git bundle outside the repository.

## 2. Add English-Only Policy

- Add `scripts/Test-CommitMessages.ps1` with file and revision validation modes.
- Add `.githooks/commit-msg` as the local adapter.
- Add `.github/workflows/commit-message-policy.yml` for all pushes and pull requests.
- Update `AGENTS.md`, `CLAUDE.md`, and `CONTRIBUTING.md` with English-only rules and hook setup.
- Add focused validator tests and run PowerShell parser, Pester, ScriptAnalyzer, and shell syntax checks.
- Commit the policy with an English Conventional Commit message.

## 3. Build and Test Rewrite

- Create the exact 25-entry SHA-to-message mapping outside the repository.
- Build a temporary raw Git object rewriter that reuses unaffected objects and rejects signed affected objects.
- Rewrite a disposable mirror and validate message policy, ref counts, release tag names, trees, metadata, topology, extra headers, and signatures.
- Create and verify a second bundle containing the policy commit immediately before the real rewrite.

## 4. Rewrite and Publish

- Apply the tested raw-object rewriter to the working clone.
- Verify the working clone produces the same rewritten refs as the mirror.
- Force-push both branches and all tags using explicit refspecs.
- Create an active GitHub ruleset that requires pull requests and the `English-only commit messages` check on the default branch.
- Configure `core.hooksPath=.githooks` in the working clone.

## 5. Final Verification

- Confirm all reachable local and remote commit messages pass the validator.
- Confirm branch/tag counts and rewritten SHAs match the expected map.
- Confirm all GitHub Releases remain public and tag-associated.
- Wait for CI and Pages success.
- Confirm commit-message CI runs on all branches and the protected default branch requires the policy check.
- Verify the website, README, and media assets remain available.
- Archive the Trellis task and report backup paths, old/new HEADs, ruleset ID, and workflow URLs.
