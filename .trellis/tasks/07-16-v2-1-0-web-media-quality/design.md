# Web and Media Quality Design

## Boundaries

- `tests/web/` owns browser tooling, the local static server, Playwright config,
  and user-visible interaction smoke tests.
- `scripts/Test-WebAssets.mjs` owns repository-local static-resource and media
  policy assertions without external packages.
- `docs/media-policy.json` is the machine-readable budget and baseline; the
  companion Markdown explains storage and migration policy.
- GitHub Actions installs the pinned browser toolchain and calls repository
  scripts. It must not duplicate product assertions in YAML.

## Browser Contract

The isolated test package pins `@playwright/test` and pnpm. A Node static server
serves `docs/` on localhost so clipboard and navigation behavior execute in a
real secure-context-compatible origin. Chromium smoke covers:

- English/Chinese language state, translated metadata, `lang`, pressed state,
  and local-storage persistence.
- Command and install tabs through click and arrow/Home/End keyboard routing,
  including selected/focus state and panel labelling.
- Clipboard copy text and live-region feedback.
- Mobile navigation open/close, Escape focus return, and link-close behavior.
- Skip-link/landmark/tab/status semantics and visible keyboard focus.
- `prefers-reduced-motion: reduce` media state and effective animation limits.

## Static and Media Contract

The Node gate scans `docs/index.html`, the maintained READMEs, and local CSS for
relative resource references. Every local reference must resolve inside the
repository. `node --check` remains the JavaScript syntax boundary.

The media policy distinguishes:

- strict extension-based limits for new files;
- exact or bounded legacy exceptions for already committed oversized files;
- total published and repository-media ceilings at the recorded baseline;
- explicitly acknowledged unreferenced published assets;
- explicitly acknowledged duplicate-content groups.

Any new unreferenced, duplicate, oversized, or total-growth asset fails. Reducing
or removing historical debt remains allowed. Negative Node tests build isolated
temporary fixtures and prove each failure path without modifying repository
assets.

## CI and Reports

A dedicated Ubuntu `web` job uses Node plus pnpm, installs only Chromium, runs
the static/media tests and Playwright smoke, and uploads the HTML report with
`if: always()`. The job has the same explicit 20-minute timeout as existing
quality jobs.

## Compatibility and Rollback

- Production HTML/CSS/JS remain framework-free and need no build step.
- Browser dependencies are test-only and cannot enter release archives.
- If browser provisioning is temporarily unavailable, the static/media gate
  remains independently runnable; CI can retry the isolated web job without
  weakening other platform gates.
- No media deletion or history rewrite occurs in this task.
