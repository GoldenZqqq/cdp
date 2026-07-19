# Website Media Policy

This repository ships a PowerShell and shell utility, so website media must not
grow without an explicit replacement or release-hosting plan. The executable
policy lives in `docs/media-policy.json` and is enforced by
`scripts/Test-WebAssets.mjs`.

## Placement Rules

- Put only website-ready, referenced assets in `docs/assets/`.
- Keep editable source material, frame compositions, and reproducible render
  inputs under `videos/<campaign>/`.
- Prefer MP4/WebM for motion. GIF is allowed only when a README preview requires
  it and must stay within the default budget.
- New PNG/JPEG/WebP/AVIF files must stay at or below 1 MiB; SVG at or below 256
  KiB; GIF at or below 2 MiB; MP4/WebM at or below 4 MiB.
- Do not raise a limit to make a new asset pass. Reduce, replace, or host the
  release artifact outside the Git history instead.

## Current Baseline

- Published `docs/assets/`: `67,433,719` bytes.
- All governed repository media: `69,115,162` bytes.
- Four legacy `cdp-demo-short-{en,zh}.{gif,mp4}` files are individually exempt
  at their current size but are not allowed to grow.
- `cdp-logo-source.png` and the four old demos are acknowledged unreferenced
  published assets. Any new unreferenced file fails the gate.
- The website promo MP4 and its `videos/` render are one acknowledged duplicate
  pair. Any new unregistered duplicate group fails the gate.

The total ceilings remain at the current byte counts. Reducing existing debt
creates room; adding assets without an equivalent reduction fails CI.

## Non-Destructive Migration Plan

1. Confirm whether the four old language demos are still needed for an external
   release, post, or documentation link not visible in this repository.
2. If they are needed, publish them as GitHub Release assets and update external
   references before removing repository copies.
3. If they are obsolete, remove all four together in a separately approved
   cleanup commit; do not rewrite history as part of routine development.
4. Move `cdp-logo-source.png` to a source-design area only after confirming no
   external raw URL depends on its current path.
5. Keep one reproducible promo render source and one published website copy until
   the release pipeline can publish directly from the render output.

No migration or deletion is performed by the quality gate itself.
