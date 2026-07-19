# Static Component Guidelines

The site uses semantic HTML components rather than framework components. Each
interactive surface has markup, ARIA state, `data-*` hooks, and one JavaScript
state transition.

## Page Regions

- One skip link targets `main#main`.
- Header navigation uses `<nav>` with a translated accessible name.
- Major sections use labelled headings and remain readable without JavaScript.
- Real commands use `<code>`/`<pre>`; status changes use live regions where
  feedback is not otherwise announced.

## Tabs

Command and install selectors follow one shared contract:

- container `role="tablist"` with accessible label;
- buttons `role="tab"`, stable `id`, `aria-controls`, `aria-selected`, and roving
  `tabindex`;
- one `role="tabpanel"` whose `aria-labelledby` tracks the selected tab;
- ArrowLeft/Right/Up/Down plus Home/End routing through `bindTabList`.

Add a new tab by extending the markup and the matching data map in
`docs/script.js`; do not add bespoke click-only behavior.

## Mobile Navigation

The native button owns `aria-expanded` and `aria-controls`. `updateNav` is the
only state renderer. Escape closes the panel and returns focus to the toggle;
following a navigation link also closes it.

## Copy Feedback

The copy button points at a code element by `data-copy-target`. Success/fallback
text goes to the existing `role="status"` live region. Clipboard failure selects
the text and gives a manual-copy instruction; never fail silently.

## Visual Rules

Reuse tokens and established Warp Lane components from `DESIGN.md`. Preserve
44-48px targets, visible `:focus-visible`, state text in addition to color, and
the `prefers-reduced-motion` override.

Browser contract: `tests/web/specs/site.spec.mjs`.
