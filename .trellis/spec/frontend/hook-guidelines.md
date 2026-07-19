# DOM Event and Lifecycle Guidelines

This project does not use React hooks. The equivalent lifecycle boundary is the
single deferred `docs/script.js` controller.

## Initialization Order

The controller executes once after HTML parsing:

```text
applyTranslations -> setLanguage -> bindInteractions -> bindHeader
```

`setLanguage` deliberately re-renders translations plus selected command,
platform, and navigation labels. Preserve this order so localized accessible
names and state content agree on first paint.

## Event Ownership

- `bindTabList` owns click and keyboard behavior for both tab systems.
- `bindInteractions` owns language, copy, mobile nav, nav-link close, and Escape.
- `bindHeader` owns the passive scroll listener and scrolled class.
- State renderer functions (`setLanguage`, `setCommand`, `setPlatform`,
  `updateNav`) update DOM; event handlers should call them rather than duplicate
  attributes/classes.

## Defensive DOM Access

Production content remains readable if JavaScript is incomplete. Optional
elements use null checks/optional chaining, while required panel content may
return early at the renderer boundary. Do not throw during initialization for a
decorative element.

## Timers and Permissions

Only one copy-label reset timer exists in state. Clear it before scheduling a
new one. Clipboard access must retain the insecure-context/error fallback.

## Keyboard and Motion

New interactive controls require keyboard behavior in the same binding function
and a Playwright assertion. New transitions/animations require an effective
reduced-motion path in `styles-responsive.css`.

Avoid per-element anonymous implementations of the same behavior, click-only
controls, multiple global controllers, or initialization that hides core content.
