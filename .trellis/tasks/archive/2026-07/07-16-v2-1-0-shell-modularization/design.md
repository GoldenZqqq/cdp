# Shell Modularization Design

## Source and Artifact Model

`src/Shell/*.sh` is the canonical editable source. `src/cdp.sh` is a committed,
deterministically generated single-file distribution artifact. This preserves the
existing remote installer checksum and `source ~/.local/bin/cdp.sh` contract
without making runtime depend on sibling files.

`scripts/Build-ShellScript.sh` concatenates one explicit ordered fragment list.
Its `--check` mode generates to a temporary file and compares exact bytes with
`src/cdp.sh`; CI and tests use check mode.

## Domains

```text
Runtime.sh          shebang, version, zsh compatibility, colors, shared globals
Core.sh             safety results and atomic JSON persistence
Config.sh           config discovery, validation, and active choice
State.sh            recent-project state and listing
Picker.sh           brand, formatting, picker rows, and project matching
Hooks.sh            hook trust and on-enter behavior
Health.sh           about and doctor checks
Scan.sh             initialization and repository discovery/import
Status.sh           multi-repository status/fix/push
Workspace.sh        launcher and named workspaces
Commands.sh         main router and read-only list
Projects.sh         project add/remove/repair
ProjectMetadata.sh  pin, alias, and tag mutations
Completion.sh       bash exports and bash/zsh completion registration
```

Fragments contain no shebang except `Runtime.sh`, do not source peers, and stay
at or below 600 physical lines. `Completion.sh` is last so exported functions and
completion dependencies already exist when its top-level registration runs.

## Compatibility

- The generated header keeps `# Version: 2.1.0` and `CDP_VERSION="2.1.0"` for
  release metadata validation.
- Only Bash 3.2-compatible arrays, parameter expansion, and utilities are used in
  the generator.
- Function bodies are extracted unchanged. Definition order may change, but all
  calls occur after the generated file has defined every function; completion and
  export registration remain last.
- `install-wsl.sh` continues downloading one generated file and verifying its
  SHA-256. Local/offline install continues copying the same artifact.

## Validation

- `Build-ShellScript.sh --check` proves exact source/artifact synchronization.
- Each fragment and generated artifact passes bash syntax; generated artifact and
  applicable fragments pass zsh syntax.
- Existing bash/zsh/Bash 3.2 regressions source the generated artifact unchanged.
- ShellCheck runs at Error severity on all fragments and the generated artifact;
  zsh-specific completion remains under the established exclusion for SC2296.
- Installer digest, release metadata, and deterministic Scoop package hashes are
  regenerated after the artifact changes.

## Rollback

Restore the previous monolithic `src/cdp.sh`, remove `src/Shell` and the build
script, then restore its installer/package digests. No user configuration or
state migration is involved.
