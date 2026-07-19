# Frontend Runtime Contracts

The production site is plain JavaScript, so data attributes, translation keys,
and JSON policy fields act as its type system.

## Translation Keys

`translations.en` and `translations['zh-CN']` must contain the same keys. Markup
`data-i18n` and `data-i18n-aria-label` values must resolve in both languages.
`text(key)` may fall back for resilience, but tests/document review must not rely
on fallback to hide a missing translation.

## Data Attributes

- `[data-language]` values must be translation map keys.
- `[data-command]` values must be `commandScenarios` keys.
- `[data-platform]` values must be `installOptions` keys.
- `[data-copy-target]` must name an existing element id.
- Tab ids, `aria-controls`, panels, and `aria-labelledby` must form a valid pair.

Validate a key before assigning state. Renderers return without mutation for an
unknown key or missing required panel.

## Policy JSON

`docs/media-policy.json` version 1 owns roots, reference files, extensions,
per-extension/default budgets, exact legacy exceptions, total ceilings,
unreferenced baselines, and duplicate groups. `scripts/Test-WebAssets.mjs`
normalizes paths and rejects missing/escaping references or invalid growth.

## Documentation Contract

`cdp.psd1` is the command inventory. Documentation validation parses its export
arrays rather than copying function/alias names into another config.

## Syntax and Compatibility

- Production JavaScript must pass `node --check docs/script.js`.
- Test/tooling code uses ESM `.mjs` and Node built-ins unless the isolated web
  package explicitly pins a dependency.
- Do not use TypeScript-style casts, implicit HTML string injection, or
  unchecked user-controlled selectors. Render command text with `textContent`.

Browser and Node contract tests live in `tests/web/specs/site.spec.mjs` and
`tests/cdp.WebAssets.Tests.mjs`.
