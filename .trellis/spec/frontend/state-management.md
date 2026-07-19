# Frontend State Management

`docs/script.js` owns one small in-memory state object:

```text
language, command, platform, navOpen, copyTimer
```

## Sources of Truth

- `language`: `localStorage['cdp-language']` when valid, otherwise English.
- `command`: selected command scenario key, default `switch`.
- `platform`: selected install option, default `powershell`.
- `navOpen`: boolean controlled by toggle/link/Escape.
- `copyTimer`: transient timer handle only.

DOM attributes/classes render state; they are not a second source of truth.
Always mutate state first, then call the owning renderer.

## Persistence

Only the language preference persists in the browser. Handle localStorage read
and write exceptions so privacy modes do not break the page. Command/platform/nav
selection resets on reload by design.

## Translation Coupling

Changing language must update:

- `<html lang>`, title, description, and Open Graph metadata;
- all `data-i18n` text and translated ARIA labels;
- language pressed state;
- command/install content and mobile-nav label;
- English/Chinese documentation links.

## Test Isolation

Playwright creates a fresh context per test. Tests that modify viewport,
permissions, localStorage, or media preferences keep those changes local. Do not
make browser tests depend on execution order.

Do not introduce a state library, global variables outside the controller, or
persist transient UI state without a product requirement.
