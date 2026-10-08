# Quality Gates

## Current maintenance and accepted release scope

[v0.1.0](RELEASE.md) is publicly released as UNSIGNED / UNNOTARIZED. Original Day 5–7 gates below are retained as historical planning, with scoped decisions/evidence in [FINAL](../reports/FINAL.md); they are not instructions to rerun every check for a document edit. Owner Live PASS, CPU PASS, Package privacy PASS and original RSS REVIEW / finite RSS REVIEW ACCEPTED remain distinct from unexecuted checks. Required checks for new work follow its authorized scope and actual repository rules.

Dev supports copying port, PID and a stop command; the App does not execute process termination. Do not run a copied command to satisfy an old gate. Claude real quota, signing/notarization, stress and App Store privacy validation remain NOT_RUN; signed/installed Login Item is Deferred. CI unit PASS without exposed counts must not be labelled a new 365/0/0 run.

## Daily minimum gate
- project builds
- tests for changed domain logic pass
- no obvious main-thread blocking introduced
- unavailable/error states visible rather than fabricated
- STATUS/report updated

## Day 5 integration gate — Historical plan
- Menu Bar displays live shared snapshots
- System live telemetry works
- Soul state transitions work without spam
- Network basic state works
- Dev runtimes/ports work
- Codex quota works if account/app-server supports it
- Claude: fallback UI and verified live retrieval are separate checks; unsupported live retrieval remains BLOCKED with owner-visible release decision
- no duplicate sensor loops

## Day 6 release-candidate gate — Historical plan
- full build/tests pass
- reviewer subagent audit has no unresolved critical/high finding
- idle/menu bar performance measured
- offline/provider failure tested
- process termination confirmation verified (historical planned operation; current implementation copies commands only, no execution acceptance claimed)
- privacy/log review complete

## Day 7 release gate — Historical plan
- no known crash/data-loss bug
- no invented quota/network data
- README/install/limitations accurate
- screenshots current
- version/changelog/license present
- clean release build

## Evidence required
Bundle integrity checks do not count as App build/unit/UI/performance validation. No unexecuted validation may be marked PASS. Initial Phase A required fixed commands and real evidence; retained increment verifying entries do not reopen the accepted seven-day release scope.
