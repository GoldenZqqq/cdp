# cdp Intro Video Script

## Goal

Create a 28-second bilingual product video for the GitHub README, social posts, and v1.8.0 release notes.

The video should explain one idea clearly: `cdp` is now an AI CLI workspace launcher that can switch projects, start Codex/Claude/Gemini/editors, organize project metadata, and safely initialize or repair the shared project map.

## Audience

- Developers using Claude Code, Codex, Gemini CLI, Cursor, or VS Code
- Windows developers who also use WSL
- People who manage many local repositories

## Format

- Duration: 28 seconds
- Aspect ratio: 16:9 for README and release pages
- Style: dark terminal, crisp command motion, cyan/green accent, no decorative noise
- Voice: practical, fast, developer-to-developer
- Captions: always on, because README visitors often watch muted

## Narrative Arc

1. The old workflow is slow: repeated `cd`, long paths, broken focus.
2. `cdp api -Open codex` switches to the project and starts the AI CLI in one move.
3. Pinning, aliases, and tags turn the project list into an organized workspace map.
4. `cdp init`, `cdp doctor --fix`, and `cdp clean` cover setup and safe repair.
5. PowerShell and WSL share project metadata and launcher behavior.
6. Close on v1.8.0 and the line: Switch. Launch. Stay in flow.

## Voiceover

### Scene 1: The Pain

Developers are back in the terminal.

Claude Code, Codex, Gemini CLI, Cursor, VS Code.

But switching projects still feels like typing a mailing address by hand.

### Scene 2: Launch the Workspace

One command opens the whole workspace.

Run `cdp api -Open codex`.

cdp switches to the project root and starts Codex. The same launcher surface also supports Claude, Gemini, VS Code, Cursor, and custom PATH commands.

### Scene 3: Organize the Project Map

Pin frequent projects to the top.

Add a short alias for direct jumps.

Add tags for focused project queries.

The metadata remains plain JSON and stays compatible with the same project list.

### Scene 4: Initialize and Repair

Run `cdp init E:\Projects` for first-time setup and Git repository discovery.

Use `cdp doctor --fix` or `cdp clean` to remove duplicate paths, disable missing paths, and fill safe defaults.

### Scene 5: PowerShell Plus WSL

PowerShell uses `cdp api -Open codex`; WSL uses `cdp api --open codex`.

Both sides share the same project map and launch flow.

### Scene 6: Close

Switch. Launch. Stay in flow.

`Install-Module cdp`, run `cdp init`, then launch a workspace with `cdp api -Open codex`.

## Shot List

| Time | Visual | Text |
| --- | --- | --- |
| 0-4.7s | Terminal rapidly typing long `cd` paths | Project switching should not break flow |
| 4.7-9.5s | `cdp api -Open codex` types in; switch and launcher states resolve | Switch projects. Launch Codex. |
| 9.5-14.3s | Pin, alias, and tag commands build beside enriched JSON | Pin it. Name it. Tag it. |
| 14.3-19.3s | Init and repair checklist resolves into a healthy state | Initialize once. Repair safely. |
| 19.3-23.7s | PowerShell and WSL commands share one workspace map | Same project map. Same launch flow. |
| 23.7-28s | v1.8.0 logo and install/launch commands hold | Switch. Launch. Stay in flow. |

## On-Screen Commands

```powershell
Install-Module -Name cdp -Scope CurrentUser
winget install fzf
Import-Module cdp
cdp doctor
cdp
cdp-add
cdp -WSL
cdp api -Open codex
cdp pin api
cdp alias api backend
cdp tag api work
cdp init E:\Projects
cdp doctor --fix
cdp clean
```

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/GoldenZqqq/cdp/main/install-wsl.sh) --auto
cdp doctor
cdp
cdp api --open codex
```

## HyperFrames Production Notes

- Design spec: `docs/video/cdp-intro/frame.md`
- Expanded production prompt: `docs/video/cdp-intro/.hyperframes/expanded-prompt.md`
- Use one 28-second composition with six scenes and directional blur transitions.
- Build all scene layouts in their final readable state before adding animation.
- Keep terminal text at 28px or larger for 1080p.
- Use a monospaced font for command lines and a clean sans font for captions.
- Prefer short command snippets over dense paragraphs.
- Every multi-scene cut should have a transition, not a jump cut.
- Captions should be short and centered near the lower third.

## Acceptance Checklist

- [ ] The first 10 seconds explain the pain without needing sound.
- [ ] `cdp api -Open codex`, `cdp pin`, `cdp alias`, `cdp tag`, `cdp init`, and `cdp doctor --fix` all appear.
- [ ] Installation is visible but does not dominate the video.
- [ ] The video shows the actual product behavior, not abstract marketing visuals.
- [ ] Captions remain readable on GitHub's dark and light page backgrounds.
