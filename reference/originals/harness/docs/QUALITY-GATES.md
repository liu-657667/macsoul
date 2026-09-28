# Quality Gates

## Daily minimum gate
- project builds
- tests for changed domain logic pass
- no obvious main-thread blocking introduced
- unavailable/error states visible rather than fabricated
- STATUS/report updated

## Day 5 integration gate
- Menu Bar displays live shared snapshots
- System live telemetry works
- Soul state transitions work without spam
- Network basic state works
- Dev runtimes/ports work
- Codex quota works if account/app-server supports it
- Claude displays real quota or honest unavailable
- no duplicate sensor loops

## Day 6 release-candidate gate
- full build/tests pass
- reviewer subagent audit has no unresolved critical/high finding
- idle/menu bar performance measured
- offline/provider failure tested
- process termination confirmation verified
- privacy/log review complete

## Day 7 release gate
- no known crash/data-loss bug
- no invented quota/network data
- README/install/limitations accurate
- screenshots current
- version/changelog/license present
- clean release build
