# CI Quality Gate Implementation

1. Add a pure coverage-threshold validator and focused positive/negative tests.
2. Add the PowerShell quality-gate orchestrator with pinned Pester-compatible
   configuration, reports, coverage threshold, analyzer, and metadata stages.
3. Add deterministic Scoop package content/hash validation and a deliberate
   hash-drift regression.
4. Replace workflow inline business assertions with repository script calls;
   pin tool versions, add job timeouts, and upload PowerShell 7 reports.
5. Update CI/spec/release documentation and record the measured coverage
   baseline and negative-gate evidence.
6. Run PowerShell 7 locally, shell/Bash 3.2 matrices, YAML/JSON, package,
   metadata, Trellis, and whitespace checks. Leave Windows PowerShell 5.1 to
   the hosted matrix while preserving compatible syntax.

## Completion Record

- [x] Added repository-owned PowerShell quality gate with pinned Pester 5.7.1,
  PSScriptAnalyzer 1.24.0, NUnit/JaCoCo reports, and 60% coverage threshold.
- [x] Added pure coverage validation and deliberate threshold failure tests.
- [x] Added deterministic Scoop package content/hash gate and deliberate hash
  failure test.
- [x] Replaced duplicated workflow assertions with script calls; added job
  timeouts, pinned Bash 3.2 digest, and PowerShell report artifacts.
- [x] Updated spec, changelog, progress, manifest release notes, package hash,
  and task validation context.
- [x] PowerShell 7.5.2 quality gate, shell matrices, ShellCheck, YAML/JSON,
  Trellis, and whitespace checks passed locally; PS5.1 is hosted-only.

## Rollback Points

- Validate coverage helper before replacing either Windows job.
- Validate the package script against two independently generated archives
  before removing inline archive assertions.
- Keep each workflow stage separately named so a failing layer is obvious.
