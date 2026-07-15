# Rewrite Git History in English

## Goal

Make every reachable Git commit message English-only and prevent future non-English commit messages from entering the repository.

## Background

- The repository has 82 commits reachable from all local refs.
- 25 complete commit messages contain Chinese text or non-ASCII punctuation.
- The remote has two branches, 13 tags, 13 GitHub Releases, and no existing rulesets.
- The user explicitly approved rewriting history and force-pushing rewritten branches and tags.

## Requirements

- Translate each non-ASCII commit subject and body into faithful English while preserving the original intent.
- Preserve file trees, authors, author dates, committers, committer dates, parent topology, merge topology, branch names, tag names, and GitHub Release records.
- Rewrite all affected local and remote branches and tags, including the default branch and release tags.
- Create and verify a complete Git bundle before rewriting any history.
- Enforce printable ASCII-only commit messages through a versioned validator, a local commit hook, CI on every pushed branch, and a protected default branch that requires both a pull request and the English-only check.
- Update repository contributor and agent guidance so English commit messages are the documented standard.
- Keep the repository default documentation language English.
- Do not change source behavior or release contents as part of the migration.

## Acceptance Criteria

- [x] A verified bundle can restore every pre-rewrite branch and tag.
- [x] Every reachable commit message matches printable ASCII plus tab/newline characters.
- [x] Exactly 25 audited messages receive intentional English replacements; already compliant messages remain unchanged.
- [x] Rewritten commits preserve tree IDs and commit metadata, with only messages and derived parent/commit IDs changing.
- [x] Unaffected signed commits retain their original SHA and signature headers.
- [x] Both remote branches and all 13 tags resolve successfully after the force push.
- [x] All 13 GitHub Releases remain published and associated with their original tag names.
- [x] The default branch contains a reusable validator, local hook, CI workflow, and English policy documentation.
- [x] CI validates every pushed branch and pull request with the same ASCII-only message contract.
- [x] The GitHub ruleset protects the default branch by requiring a pull request and the `English-only commit messages` status check.
- [x] CI and GitHub Pages complete successfully after the rewrite.
- [x] The working tree is clean and `main` matches `origin/main` at completion.
