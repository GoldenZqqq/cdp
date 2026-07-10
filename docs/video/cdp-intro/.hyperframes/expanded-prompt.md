# Expanded Prompt: cdp Intro Video

## Title + Style Block

Create a 28-second 16:9 HyperFrames product video for `cdp` v1.8.0, an AI CLI workspace launcher for Vibe Coding workflows.

Use the frame spec exactly:

- Background `#07130F`
- Panel `#0E1F19`
- Panel raised `#142A22`
- Foreground `#F3F7ED`
- Muted foreground `#A6B7AE`
- Accent `#2FFFA0`
- Accent dark `#15945F`
- Warning `#F2C14E`
- Error `#FF5C7A`
- Rule `#214139`
- Headings: `Aptos Display`, fallback `Segoe UI`
- Terminal text: `Cascadia Mono`, fallback `Consolas`

The world is a terminal control room: calm, precise, focused, and useful. Avoid purple/blue gradient hero styling, abstract blob backgrounds, and tiny terminal text.

## Rhythm Declaration

Rhythm: `hook-fast -> launcher-hold -> metadata-build -> repair-pulse -> platform-bridge -> CTA-hold`.

The video starts with navigation friction, reveals `cdp api -Open codex`, organizes the shared project map, builds trust with init/repair commands, then closes on the v1.8.0 launch path.

## Global Rules

- Every scene has background texture: grid drift, ghost paths, scan lines, terminal coordinates, or radial glow.
- Every scene has at least two focal points: command terminal plus title/status/diagram.
- Use terminal windows as real product surfaces, not decorative cards.
- Use directional blur crossfades between scenes, 0.45s, `power2.inOut`.
- Use one accent terminal scan wipe, 0.35s, `power3.inOut`, before the initialize-and-repair scene.
- All command text should be 34px or larger at 1920x1080.
- Captions should be 34-42px, short, and positioned in the lower third.
- Use no exit animations before scene transitions; transitions handle the handoff.

## Scene 1: The Pain

**Concept:** The viewer is trapped inside a terminal full of long paths. The frame feels crowded by repeated `cd` commands, but controlled enough that the pain is legible.

**Mood direction:** Precise developer frustration, not comedy. Think a terminal log filling too fast while a cursor waits for relief.

**Depth layers:**

- BG: dark `#07130F`, giant ghost text `..\..\..` drifting at 10% opacity.
- BG: faint grid lines in `#214139`, slowly sliding left.
- MG: large terminal window in `#0E1F19` with long `cd` commands.
- MG: side counter showing `paths typed today`.
- FG: warning pill in `#F2C14E` saying `flow interrupted`.
- FG: blinking cursor at the last prompt.

**Animation choreography:**

- Long paths TYPE ON in staggered bursts.
- Ghost `..\..\..` DRIFTS behind the terminal.
- Warning pill SNAPS into place.
- Cursor PULSES while the terminal holds.

**Transition out:** Directional blur crossfade upward, 0.45s, `power2.inOut`.

## Scene 2: Launch the Workspace

**Concept:** The clutter collapses into one workspace command: `cdp api -Open codex`. The viewer sees the project switch and AI CLI launch resolve as one terminal interaction.

**Mood direction:** Clean command demo, confident and readable.

**Depth layers:**

- BG: radial accent glow in `#15945F` at 18% opacity.
- BG: ghost project names floating in muted foreground.
- MG: terminal command line typing `cdp api -Open codex`.
- MG: status rows `Switched to project: my-api` and `Opening with Codex...`.
- FG: launcher presets for Codex, Claude, Gemini, VS Code, and Cursor.
- FG: caption `Switch projects. Launch Codex.`

**Animation choreography:**

- The launch command TYPES ON.
- Switch and launch status rows CASCADE in.
- Launcher presets SETTLE in as one compact group.
- The full terminal interaction HOLDS long enough to read.

**Transition out:** Directional blur crossfade, 0.45s, `power2.inOut`.

## Scene 3: Organize the Project Map

**Concept:** cdp enriches the plain project map with pinning, aliases, and tags without replacing the JSON format.

**Mood direction:** Toolchain compatibility, tidy and practical.

**Depth layers:**

- BG: thin rules and coordinates, `CONFIG/SOURCES`.
- MG left: `cdp pin api`, `cdp alias api backend`, and `cdp tag api work`.
- MG right: JSON with `pinned`, `aliases`, and `tags`.
- FG: direct-jump examples `cdp backend` and `cdp '@work'`.

**Animation choreography:**

- Metadata commands SLIDE in from left.
- JSON fields DRAW line by line.
- Command/result pairs SETTLE with a restrained stagger.

**Transition out:** Terminal scan wipe, 0.35s, `power3.inOut`, accent `#2FFFA0`.

## Scene 4: Initialize and Repair

**Concept:** The trust beat. `cdp init`, `cdp doctor --fix`, and `cdp clean` cover first-run setup, diagnosis, and safe repair.

**Mood direction:** Calm incident response. No panic, just checks becoming visible.

**Depth layers:**

- BG: dark panel with subtle scan bands.
- MG: command line `cdp init E:\Projects`.
- MG: checklist rows for config creation, Git scan, duplicate paths, missing paths, and healthy status.
- FG: compact command rail for `init`, `doctor --fix`, and `clean`.
- FG: small label `start clean, stay healthy`.

**Animation choreography:**

- Setup command TYPES ON.
- Checklist rows CASCADE downward.
- FIX and OK states CLICK from muted to `#2FFFA0`.
- The final healthy state HOLDS.

**Transition out:** Directional blur crossfade, 0.45s, `power2.inOut`.

## Scene 5: PowerShell Plus WSL

**Concept:** Two terminals share one project map and one launcher flow. PowerShell and WSL show equivalent Codex launch commands.

**Mood direction:** Systems bridge, precise and satisfying.

**Depth layers:**

- BG: split frame, PowerShell left, WSL right.
- MG left: `cdp api -Open codex` above `C:\Learn\cdp`.
- MG right: `cdp api --open codex` above `/mnt/c/Learn/cdp`.
- FG: shared workspace-map badge.

**Animation choreography:**

- PowerShell and WSL panels ENTER from opposite sides.
- Commands RESOLVE in parallel.
- Workspace-map badge LOCKS IN after both panels settle.

**Transition out:** Soft blur crossfade, 0.55s, `sine.inOut`.

## Scene 6: CTA

**Concept:** The viewer leaves with the shortest install, setup, and AI CLI launch path for v1.8.0.

**Mood direction:** Quiet confidence. The product has already proven itself; the CTA should not shout.

**Depth layers:**

- BG: stable grid and dim ghost command history.
- MG: install command block.
- MG: `cdp init E:\Projects` and `cdp api -Open codex`.
- FG: project logo text `cdp`.
- FG: version badge `v1.8.0` and final line `Switch. Launch. Stay in flow.`

**Animation choreography:**

- Logo DRAWS in with a terminal cursor.
- Install command SLIDES up into place.
- `cdp api -Open codex` CLICKS into accent.
- Version badge and final line SETTLE, then hold.

**Final exit:** Fade to `#07130F` over 0.4s.

## Recurring Motifs

- Blinking terminal cursor.
- Accent highlight `#2FFFA0` for the active command or selected result.
- Warning `#F2C14E` only for diagnostic friction.
- Muted ghost paths and project names as background texture.
- Rules and terminal coordinates to keep the frame engineered rather than decorative.

## Negative Prompt

Do not create a generic SaaS landing video. Do not use purple-blue gradients, abstract blobs, tiny code, oversized hero cards, or fake UI that does not resemble terminal behavior. Do not add new product claims beyond the commands and behavior in the repository.
