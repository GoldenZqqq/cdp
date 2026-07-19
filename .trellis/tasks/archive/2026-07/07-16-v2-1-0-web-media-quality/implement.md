# Web and Media Quality Implementation

1. Add the isolated Playwright package, pinned pnpm metadata, local server, and
   Chromium smoke for language, tabs, copy, mobile navigation, keyboard focus,
   semantics, and reduced motion.
2. Add the repository-owned static/media validator plus Node negative fixtures
   for missing references, oversized new media, and unregistered duplicates.
3. Record exact current media budgets, legacy unreferenced files, duplicate
   groups, placement rules, and a non-destructive migration sequence.
4. Add a dedicated timed CI web job that installs pinned dependencies, runs
   static and browser gates, and uploads Playwright reports.
5. Synchronize frontend/backend quality specs, changelog, progress, and release
   notes without claiming asset removal.
6. Run Node tests, current media validation, Playwright Chromium, workflow/JSON
   parsing, existing shell/package gates, Trellis validation, and whitespace
   checks.

## Risk and Rollback Points

- Validate the static/media gate and its negative fixtures before wiring CI.
- Keep media baselines exact so the gate stops growth but permits debt
  reduction; do not silently raise ceilings to make a new asset pass.
- Keep Playwright state isolated per test so language/localStorage and viewport
  changes cannot leak.
- Never delete the migration candidates in this task.

## Completion Record

- [x] Added isolated pnpm/Playwright tooling, static server, and six Chromium
  interaction/accessibility scenarios.
- [x] Added repository-owned local-resource/media validation and six Node
  positive/negative fixtures.
- [x] Recorded exact budgets, historical exceptions, duplicate baseline, and a
  non-destructive migration plan.
- [x] Added a dedicated timed Web CI job with pinned tooling and report upload.
- [x] Synchronized frontend/backend specs, changelog, progress, release notes,
  and the deterministic Scoop package hash.
- [x] Passed Web, PowerShell, package, generated artifact, YAML/JSON, Trellis,
  and whitespace validation.
