# cdp Intro Video Script

## Goal

Create a short product video for GitHub README, social posts, and release notes.

The video should explain one idea clearly: in the Vibe Coding era, developers spend more time inside terminal AI tools, so switching between project roots should be instant, searchable, and visible.

## Audience

- Developers using Claude Code, Codex, Gemini CLI, Cursor, or VS Code
- Windows developers who also use WSL
- People who manage many local repositories

## Format

- Duration: 60-75 seconds
- Aspect ratio: 16:9 for README and release pages
- Style: dark terminal, crisp command motion, cyan/green accent, no decorative noise
- Voice: practical, fast, developer-to-developer
- Captions: always on, because README visitors often watch muted

## Narrative Arc

1. The old workflow is slow: repeated `cd`, long paths, broken focus.
2. AI CLI workflows made the terminal the control room again.
3. `cdp` turns project switching into one fuzzy search.
4. It works with Project Manager or a simple JSON file.
5. `cdp doctor` makes setup problems visible.
6. Windows and WSL can share the same project map.

## Voiceover

### Scene 1: The Pain

Developers are back in the terminal.

Claude Code, Codex, Gemini CLI, Cursor, VS Code.

But switching projects still feels like typing a mailing address by hand.

### Scene 2: The Command

cdp makes project switching one command.

Type `cdp`, search a few letters, press Enter.

You land in the project root, and the terminal tab shows where you are.

### Scene 3: Bring Your Own Project List

Already using Project Manager in VS Code or Cursor?

cdp reads it automatically.

Prefer a plain file?

Use `cdp-add` and keep everything in `~/.cdp/projects.json`.

### Scene 4: Diagnose Before You Guess

Setup problem?

Run `cdp doctor`.

It checks fzf, the active config file, JSON shape, duplicate names, and missing paths.

### Scene 5: Windows Plus WSL

Working across PowerShell and WSL?

cdp converts Windows paths for WSL and keeps the same project list usable on both sides.

### Scene 6: Close

Stop remembering paths.

Start switching projects.

`Install-Module cdp`, then run `cdp doctor`.

## Shot List

| Time | Visual | Text |
| --- | --- | --- |
| 0-8s | Terminal rapidly typing long `cd` paths, then freezing on a deep folder | Project switching should not break flow |
| 8-18s | AI CLI names appear as compact terminal tabs | Vibe Coding lives in the terminal |
| 18-30s | `cdp` opens a fuzzy menu, query narrows results, selected project opens | One command. Fuzzy search. Enter. |
| 30-42s | Split view: Project Manager JSON and `cdp-add` writing config | Use Project Manager or plain JSON |
| 42-55s | `cdp doctor` checklist animates from warning to clean state | Diagnose setup in seconds |
| 55-68s | PowerShell path transforms into WSL path | Windows and WSL share the map |
| 68-75s | Final command card | `Install-Module cdp` |

## On-Screen Commands

```powershell
Install-Module -Name cdp -Scope CurrentUser
winget install fzf
Import-Module cdp
cdp doctor
cdp
cdp-add
cdp -WSL
```

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/GoldenZqqq/cdp/main/install-wsl.sh) --auto
cdp doctor
cdp
```

## HyperFrames Production Notes

- Design spec: `docs/video/cdp-intro/frame.md`
- Expanded production prompt: `docs/video/cdp-intro/.hyperframes/expanded-prompt.md`
- Use one composition with six scenes and soft terminal wipes between scenes.
- Build all scene layouts in their final readable state before adding animation.
- Keep terminal text at 28px or larger for 1080p.
- Use a monospaced font for command lines and a clean sans font for captions.
- Prefer short command snippets over dense paragraphs.
- Every multi-scene cut should have a transition, not a jump cut.
- Captions should be short and centered near the lower third.

## Acceptance Checklist

- [ ] The first 10 seconds explain the pain without needing sound.
- [ ] `cdp`, `cdp-add`, `cdp doctor`, and `cdp -WSL` all appear.
- [ ] Installation is visible but does not dominate the video.
- [ ] The video shows the actual product behavior, not abstract marketing visuals.
- [ ] Captions remain readable on GitHub's dark and light page backgrounds.
