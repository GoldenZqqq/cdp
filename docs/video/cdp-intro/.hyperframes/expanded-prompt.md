# Expanded Prompt: cdp Intro Video

## Title + Style Block

Create a 60-75 second 16:9 HyperFrames product video for `cdp`, a fast project directory switcher for Vibe Coding CLI workflows.

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

Rhythm: `hook-fast -> demo-hold -> config-build -> doctor-pulse -> WSL-transform -> CTA-hold`.

The video starts with friction, opens into one clean command, builds trust with config and diagnostics, then closes on install and verification.

## Global Rules

- Every scene has background texture: grid drift, ghost paths, scan lines, terminal coordinates, or radial glow.
- Every scene has at least two focal points: command terminal plus title/status/diagram.
- Use terminal windows as real product surfaces, not decorative cards.
- Use directional blur crossfades between scenes, 0.45s, `power2.inOut`.
- Use one accent terminal scan wipe, 0.35s, `power3.inOut`, before the `cdp doctor` scene.
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

## Scene 2: The Command

**Concept:** The clutter collapses into one command: `cdp`. The viewer sees the whole product promise in one crisp terminal interaction.

**Mood direction:** Clean command demo, confident and readable.

**Depth layers:**

- BG: radial accent glow in `#15945F` at 18% opacity.
- BG: ghost project names floating in muted foreground.
- MG: centered terminal picker with `Select project: api`.
- MG: highlighted selected row `my-api`.
- FG: caption `One command. Fuzzy search. Enter.`
- FG: small status row `2-5 sec switch`.

**Animation choreography:**

- `cdp` TYPES ON.
- fzf picker EXPANDS from the prompt line.
- Matching letters FILL in `#2FFFA0`.
- Selected row LOCKS IN with a subtle scale pulse.

**Transition out:** Directional blur crossfade, 0.45s, `power2.inOut`.

## Scene 3: Bring Your Own Project List

**Concept:** cdp is not another database. It reads the project map developers already have, or creates a plain JSON map with `cdp-add`.

**Mood direction:** Toolchain compatibility, tidy and practical.

**Depth layers:**

- BG: thin rules and coordinates, `CONFIG/SOURCES`.
- MG left: Project Manager path stack, Cursor and VS Code.
- MG right: JSON snippet with `name`, `rootPath`, `enabled`.
- FG: command `cdp-add`.
- FG: connector line from Project Manager to cdp.

**Animation choreography:**

- Config sources SLIDE in from left.
- JSON object DRAWS line by line.
- `cdp-add` STAMPS into the command prompt.
- Connector line GROWS toward the cdp label.

**Transition out:** Terminal scan wipe, 0.35s, `power3.inOut`, accent `#2FFFA0`.

## Scene 4: Diagnose Before You Guess

**Concept:** The trust beat. Instead of guessing why setup fails, `cdp doctor` turns environment state into a readable checklist.

**Mood direction:** Calm incident response. No panic, just checks becoming visible.

**Depth layers:**

- BG: dark panel with subtle scan bands.
- MG: command line `cdp doctor`.
- MG: checklist rows for `fzf`, `config file`, `JSON`, `duplicate names`, `project paths`.
- FG: warning row in `#F2C14E` for missing paths, then clean summary.
- FG: small label `trust the setup`.

**Animation choreography:**

- Command TYPES ON.
- Checklist rows CASCADE downward.
- OK states CLICK from muted to `#2FFFA0`.
- Warning row PULSES once in `#F2C14E`.

**Transition out:** Directional blur crossfade, 0.45s, `power2.inOut`.

## Scene 5: Windows Plus WSL

**Concept:** Two terminals share one project map. A Windows path transforms into a WSL path in a clear, inspectable way.

**Mood direction:** Systems bridge, precise and satisfying.

**Depth layers:**

- BG: split frame, PowerShell left, WSL right.
- MG left: `C:\Learn\cdp`.
- MG right: `/mnt/c/Learn/cdp`.
- FG: transform arrow and shared config file `~/.cdp/projects.json`.
- FG: small badge `same map`.

**Animation choreography:**

- PowerShell path TYPES ON.
- Drive letter and slashes MORPH into WSL form.
- Shared config file FLOATS between the terminals.
- Badge LOCKS IN after the transform.

**Transition out:** Soft blur crossfade, 0.55s, `sine.inOut`.

## Scene 6: CTA

**Concept:** The viewer leaves with the shortest installation path and a clear first verification command.

**Mood direction:** Quiet confidence. The product has already proven itself; the CTA should not shout.

**Depth layers:**

- BG: stable grid and dim ghost command history.
- MG: install command block.
- MG: `cdp doctor` verification command.
- FG: project logo text `cdp`.
- FG: final line `Stop remembering paths. Start switching projects.`

**Animation choreography:**

- Logo DRAWS in with a terminal cursor.
- Install command SLIDES up into place.
- `cdp doctor` CLICKS into accent.
- Final line BREATHES once, then holds.

**Final exit:** Fade to `#07130F` over 0.4s.

## Recurring Motifs

- Blinking terminal cursor.
- Accent highlight `#2FFFA0` for the active command or selected result.
- Warning `#F2C14E` only for diagnostic friction.
- Muted ghost paths and project names as background texture.
- Rules and terminal coordinates to keep the frame engineered rather than decorative.

## Negative Prompt

Do not create a generic SaaS landing video. Do not use purple-blue gradients, abstract blobs, tiny code, oversized hero cards, or fake UI that does not resemble terminal behavior. Do not add new product claims beyond the commands and behavior in the repository.
