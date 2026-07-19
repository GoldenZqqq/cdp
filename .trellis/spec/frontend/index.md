# Frontend Development Guidelines

The frontend is the dependency-free static GitHub Pages site under `docs/` plus
its Node/Playwright quality tooling. Production has no bundler or component
framework; semantic HTML, layered CSS, and one DOM controller are the runtime.

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | Static page, CSS layers, media, source renders, and browser tests | Active |
| [Component Guidelines](./component-guidelines.md) | Semantic page regions, data-attribute contracts, tabs, navigation, and status UI | Active |
| [DOM Lifecycle](./hook-guidelines.md) | Event binding, initialization order, keyboard handling, and cleanup assumptions | Active |
| [State Management](./state-management.md) | Language, selected tabs, mobile navigation, clipboard timer, and localStorage | Active |
| [Quality Guidelines](./quality-guidelines.md) | Chromium smoke, accessibility, resources, and media budgets | Active |
| [Runtime Contracts](./type-safety.md) | Translation keys, data attributes, policy JSON, null checks, and validation | Active |

## Pre-Development Checklist

1. Read `PRODUCT.md` and `DESIGN.md` before changing the public site.
2. Read directory/component/state/lifecycle guidance for HTML/CSS/JS edits.
3. Read runtime contracts before adding translation keys or data attributes.
4. Read quality guidance before adding media or browser behavior.
5. Preserve no-JavaScript readability and reduced-motion behavior.

## Quality Check

```bash
pnpm --dir tests/web install --frozen-lockfile
pnpm --dir tests/web test
node scripts/Test-WebAssets.mjs
node scripts/Test-Documentation.mjs
```

Also parse workflow/policy JSON/YAML and run `git diff --check`.
