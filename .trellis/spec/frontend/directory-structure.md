# Frontend Directory Structure

## Production Site

```text
docs/index.html                 semantic content and initial no-JS state
docs/styles.css                 tokens, reset, navigation, hero, shared controls
docs/styles-sections.css        section-specific layouts and components
docs/styles-responsive.css      breakpoints, keyframes, reduced motion
docs/script.js                  translations, state transitions, DOM bindings
docs/assets/                    referenced website-ready media only
docs/media-policy.json          executable media baseline and budgets
docs/MEDIA_POLICY.md            storage and migration policy
```

Keep production framework-free. A new visual section normally adds semantic
markup to `index.html`, uses existing tokens/components, and places scoped rules
in `styles-sections.css`; responsive and motion overrides belong in
`styles-responsive.css`.

## Test Tooling

```text
tests/web/package.json          pinned pnpm and Playwright dependency
tests/web/playwright.config.mjs Chromium/server/report configuration
tests/web/server.mjs            localhost-only static server
tests/web/specs/*.spec.mjs      user-visible browser behavior
tests/cdp.WebAssets.Tests.mjs   media/resource negative fixtures
scripts/Test-WebAssets.mjs      repository asset gate
scripts/Test-Documentation.mjs  documentation/spec synchronization gate
```

Browser dependencies stay test-only and must not enter the PowerShell/Scoop
release archive.

## Media Ownership

- `docs/assets`: final, referenced runtime assets.
- `videos/<campaign>`: storyboards, source frames, render configuration, and
  reproducible output sources.
- Existing legacy exceptions are listed in `docs/media-policy.json`; do not add
  a new exception merely to pass CI.

## Naming

- CSS uses descriptive kebab-case classes and existing `data-*` hooks.
- JavaScript state/action helpers use verb-based camelCase (`setLanguage`,
  `setCommand`, `updateNav`).
- Playwright files use `.spec.mjs`; dependency-free Node fixtures use
  `*.Tests.mjs` at the repository test root.

Do not create a second page controller, inline large scripts/styles, add an
unreferenced asset, or edit generated video renders as source.
