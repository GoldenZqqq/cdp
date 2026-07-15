# Design: English-Only Git History

## Architecture

The migration has four layers:

1. **Policy source**: `scripts/Test-CommitMessages.ps1` owns the executable printable-ASCII contract.
2. **Early local feedback**: `.githooks/commit-msg` invokes the policy source before a local commit is created.
3. **Repository verification**: `.github/workflows/commit-message-policy.yml` validates all commits reachable from the workflow SHA.
4. **Remote enforcement**: CI validates every pushed branch, while a GitHub ruleset requires pull requests and the English-only status check before the default branch can advance.

Repository guidance in `AGENTS.md`, `CLAUDE.md`, and `CONTRIBUTING.md` documents the same rule and setup command.

GitHub rejected the native `commit_message_pattern` rule type for this repository with HTTP 422, including a minimal disabled probe. The protected-branch design is therefore the strongest available server-side enforcement: a commit cannot enter canonical history unless the policy workflow passes on its pull request.

## Message Contract

Valid commit messages contain only:

- horizontal tab (`0x09`)
- line feed (`0x0A`)
- carriage return (`0x0D`)
- printable ASCII (`0x20` through `0x7E`)

This provides an objective enforcement boundary. It rejects CJK characters, emoji, typographic dashes, curly quotes, and other non-ASCII text. Semantic English quality remains a review responsibility.

## History Rewrite

- Audit every reachable commit message and freeze an explicit old-SHA-to-English-message map.
- Use a temporary raw Git object rewriter rather than changing repository dependencies.
- Process commits parent-first and reuse the exact original object whenever neither its message nor parent IDs change.
- Rebuild only affected commit objects, preserving tree, author, committer, timestamps, parent order, and all safe extra headers byte-for-byte.
- Reject any affected signed commit or signed tag instead of silently dropping an invalidated signature.
- Preserve annotated tag names and metadata while normalizing the single audited non-ASCII tag message.
- Test the mapping in a disposable mirror clone before touching the working clone.
- Capture the generated commit map and compare old/new trees, identities, timestamps, topology, extra headers, signatures, and refs.
- Apply the verified raw-object rewrite to the working clone, then force-push branches and tags with explicit refspecs.

## GitHub Releases

Releases are retained by tag name. After rewritten tags are pushed, verify every existing release remains public and resolves to its original tag name. Release assets and notes are not modified.

## Rollback

- Create a full `git bundle create <path> --all` backup before policy commits and another pre-rewrite bundle after the policy commit.
- Verify each bundle with `git bundle verify`.
- Keep old and new SHA maps outside the repository.
- If the remote rewrite fails partway, restore all branch and tag refs from the verified pre-rewrite bundle and force-push them back.

## Trade-offs

- Old commit URLs and downstream clone histories become stale; this is inherent to rewriting commit messages.
- ASCII-only is stricter than natural-language English but is deterministic and enforceable across local hooks, CI, and GitHub rulesets.
- GitHub cannot hard-reject a non-English commit on an unprotected feature branch for this repository because commit metadata rules are unavailable. CI still marks that branch as failed, and the default-branch ruleset prevents the commit from entering canonical history.
