# Frontend Quality Guidelines

## Scenario: Protect the Static Website and Its Media Budget

### 1. Scope / Trigger

Apply whenever `docs/index.html`, website CSS/JavaScript, published media,
README media references, browser tooling, or the CI web job changes. The site
remains framework-free, but user-visible behavior still requires a real browser
contract and repository growth requires a machine-readable budget.

### 2. Signatures

```text
pnpm --dir tests/web run test:assets
pnpm --dir tests/web run test:browser
pnpm --dir tests/web test
node scripts/Test-WebAssets.mjs
node scripts/Test-Documentation.mjs
node --check docs/script.js
```

The media policy boundary is `docs/media-policy.json`:

```text
publishedRoots, sourceRoots, referenceFiles, mediaExtensions
defaultMaxBytes, legacyFileMaxBytes
maxPublishedBytes, maxRepositoryMediaBytes
allowedUnreferencedPublished, allowedDuplicateGroups
```

### 3. Contracts

- Production remains static HTML/CSS/JavaScript with no browser runtime
  dependency or build step.
- `tests/web` owns the exact pnpm and `@playwright/test` versions plus its
  lockfile; browser dependencies never enter the cdp release archive.
- Chromium smoke covers language persistence, metadata translation, command and
  install tabs, clipboard/status feedback, mobile navigation, Escape focus
  return, landmarks, keyboard focus, and reduced motion.
- Every local HTML, Markdown, or CSS resource reference resolves inside the
  repository and exists.
- New media uses extension budgets. Existing oversized, unreferenced, or
  duplicate assets pass only through explicit path-based baseline entries.
- Published and repository media totals never exceed the recorded byte
  ceilings. Debt reduction is allowed; silent budget increases are forbidden.
- Editable sources and render inputs live under `videos/<campaign>`; only
  referenced website-ready files belong in `docs/assets`.

### 4. Validation & Error Matrix

- Missing local resource -> asset gate names source and reference; nonzero exit.
- Relative reference escapes repository -> reject before filesystem access.
- New file exceeds extension limit -> report path, actual bytes, and maximum.
- New unreferenced published media -> report every unexpected path.
- Duplicate hash group not listed exactly -> report the full path group.
- Published or repository total grows above baseline -> report actual/maximum.
- Browser interaction, semantic, or focus contract drifts -> Playwright fails
  the named scenario and retains trace/screenshot/report artifacts.
- Chromium provisioning failure -> only the isolated web job fails; platform
  CLI jobs remain independently diagnosable.

### 5. Good / Base / Bad Cases

- Good: replace a legacy 16 MiB demo with a referenced 2 MiB preview and lower
  the recorded baseline after validation.
- Base: edit translations or CSS and keep all six Chromium scenarios green.
- Bad: add an 8 MiB MP4, list it as a legacy exception, and raise both totals
  merely to bypass the gate.

### 6. Tests Required

- Node fixtures deliberately reject a missing resource, oversized new media,
  and an unregistered duplicate group.
- Current repository assets pass with exact published/repository byte counts.
- Playwright runs one Chromium worker in CI and isolates language, viewport,
  clipboard permissions, and emulated media state per test.
- CI pins Node, pnpm, and Playwright, has a 20-minute timeout, and uploads the
  HTML report with `if: always()`.
- Final review parses workflow/policy/package JSON, runs JavaScript syntax,
  existing package gates, Trellis validation, and `git diff --check`.

### 7. Wrong vs Correct

Wrong:

```text
workflow YAML contains copied DOM assertions
new-video.mp4 -> raise maxRepositoryMediaBytes until CI is green
docs/assets/raw-source.png -> leave unreferenced without policy entry
```

Correct:

```text
workflow -> pnpm repository scripts -> named Playwright/Node failures
reduce/replace media -> validate -> lower or preserve byte ceiling
videos/campaign source -> reproducible render -> referenced docs/assets output
```
