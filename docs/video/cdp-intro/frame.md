# cdp Intro Video Frame Spec

## Brand Mood

Terminal control room for Vibe Coding. Fast, focused, practical, and slightly cinematic. The viewer should feel that `cdp` is a calm command center, not a flashy marketing layer.

## Palette

- Background: `#07130F`
- Panel: `#0E1F19`
- Panel raised: `#142A22`
- Foreground: `#F3F7ED`
- Muted foreground: `#A6B7AE`
- Accent: `#2FFFA0`
- Accent dark: `#15945F`
- Warning: `#F2C14E`
- Error: `#FF5C7A`
- Rule: `#214139`

## Typography

- Narration and headings: `Aptos Display`, fallback `Segoe UI`
- Terminal and command text: `Cascadia Mono`, fallback `Consolas`
- Headline weight: 800
- Body weight: 350
- Terminal weight: 500

## Shape

- Terminal windows: 18px radius
- Command chips: 999px radius only for compact status pills
- Panels: 14px radius
- Lines: 2px minimum for video visibility

## Motion

- Rhythm: hook-fast, demo-hold, config-build, doctor-pulse, WSL-transform, CTA-hold
- Primary transition: directional blur crossfade, 0.45s, `power2.inOut`
- Accent transition: terminal scan wipe, 0.35s, `power3.inOut`
- Ambient motion: slow grid drift, glow breathing, cursor pulse

## Do

- Show actual commands and project names.
- Keep command lines large and readable.
- Use `cdp doctor` as the trust-building beat.
- Make PowerShell and WSL feel like two terminals sharing one map.

## Avoid

- Purple/blue gradient hero styling.
- Abstract blob backgrounds.
- Tiny terminal text.
- Generic productivity claims without showing commands.
