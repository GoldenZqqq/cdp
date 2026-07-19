# Spec and Documentation Refresh Design

## Canonical Sources

- `AGENTS.md` is the repository instruction source. `CLAUDE.md` links to it
  rather than maintaining a second copy.
- `cdp.psd1` owns exported PowerShell functions/aliases and the release version.
- `src/cdp.psm1` owns the ordered PowerShell domain list;
  `scripts/Build-ShellScript.sh` owns the shell generated artifact.
- `README.md` is the canonical public language; `README_ZH.md` mirrors its
  structure and command coverage.
- `.trellis/spec/{backend,frontend}` own implementation contracts for future
  development agents.

## Spec Mapping

Existing filenames remain stable, but template concepts are mapped to the real
repository:

- backend database -> JSON persistence and state ownership;
- backend logging -> user output, action results, redaction, and CI diagnostics;
- frontend hooks -> DOM event binding and page lifecycle, not React hooks;
- frontend type safety -> data attributes, translation keys, policy JSON, and
  runtime validation in framework-free JavaScript.

Every file cites representative source/test paths, lists local anti-patterns,
and provides a specific verification boundary. No template headings remain.

## Documentation Gate

`scripts/Test-Documentation.mjs` is dependency-free and exports a validator for
Node fixtures. It verifies:

1. English/Chinese H2/H3 level sequences and fenced-code language sequences.
2. Every `FunctionsToExport` and `AliasesToExport` entry from `cdp.psd1` appears
   in both maintained READMEs.
3. Required v2 command, state-file, safety, performance, and quality-gate terms
   appear in both languages.
4. Backend/frontend specs contain no template placeholders and their index links
   resolve.
5. README/CONTRIBUTING/AGENTS/CLAUDE contain no known stale architecture,
   Pester-version, line-reference, or commit-format patterns.

Negative tests use a temporary miniature repository and mutate one contract at
a time. The web package's `test:assets` script calls this gate so existing Web CI
owns documentation checks without another dependency job.

## Public Documentation Changes

Both READMEs receive matching sections for:

- project config, saved selection, recent state, workspace definitions, hook
  trust, locks, and backups;
- repository-owned PowerShell, shell, package, documentation, and browser test
  commands;
- the current five CI jobs and Conventional Commits examples.

No user-visible command semantics change, so examples describe the existing
v2.1.0 contract only.

## Rollback

- The documentation gate can be removed from `test:assets` without affecting
  production runtime if its parser proves too strict.
- Spec and prose changes are independent of module/shell execution.
- Do not loosen a required-term or export check solely to accept undocumented
  behavior; update both READMEs or the canonical manifest instead.
