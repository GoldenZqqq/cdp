# Shell Modularization Implementation

1. Add fragment/build structural tests for the 600-line limit, explicit ordered
   assembly, generated-byte equality, syntax, and single-file installation.
2. Extract globals and every function into the documented domain fragments
   without changing function bodies.
3. Add the Bash 3.2-compatible generator and regenerate `src/cdp.sh`.
4. Run existing CLI, status, safe-mutation, persistence, installer, bash/zsh v2,
   Bash 3.2, syntax, and ShellCheck gates; fix only assembly defects.
5. Update CI, release notes, changelog, progress, spec, shell installer digest,
   and Scoop archive hash.
6. Run release metadata, YAML/JSON, Trellis validation, and `git diff --check`.

## Validation Commands

```bash
bash ./scripts/Build-ShellScript.sh --check
bash -n ./src/cdp.sh ./src/Shell/*.sh ./install-wsl.sh
zsh -n ./src/cdp.sh
bash ./tests/cdp.Shell.Modularization.Tests.sh
bash ./tests/cdp.Shell.V2.Tests.sh
zsh ./tests/cdp.Shell.V2.Tests.sh
```

## Rollback Points

- Before digest updates, restore the original monolith if any function inventory
  or behavioral regression differs.
- Keep generated-artifact and installer digest changes in the same work commit.

## Completion Evidence

- [x] Fourteen canonical `src/Shell` fragments contain the complete 82-function
  inventory; the largest fragment is 403 lines.
- [x] `scripts/Build-ShellScript.sh --check` proves the committed 3,328-line
  single-file artifact is byte-for-byte synchronized and starts with a shebang.
- [x] Isolated offline installation copies exact artifact bytes and the installed
  file exposes the public functions after source.
- [x] bash and zsh syntax, ShellCheck Error severity (excluding established mixed
  zsh `SC2296`), CLI, status, safe-mutation, v2, persistence, installer, and
  modularization suites passed.
- [x] Bash 3.2 Alpine with `jq`, `fzf`, and `git` passed modularization, CLI,
  status, safe-mutation, and persistence suites.
- [x] PowerShell Pester remained `88/88`; release metadata, package digest,
  YAML/JSON, Trellis validation, and `git diff --check` passed.
- [x] Generated script SHA-256 is
  `50b4c4b416b48c0cbf0b6f22ccc690bfc130e16784d375d6535b3acc1ad6f06c`;
  deterministic Scoop archive SHA-256 is
  `d5867b220317c81c6606f1de6bb174de0c32392a2afe943751a3f93abd9341d9`.
