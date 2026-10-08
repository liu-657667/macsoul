# Performance Budget

## Accepted finite v0.1.0 observation

The accepted RC five-minute Live observation is **CPU PASS**, original **RSS REVIEW**, and **RSS REVIEW ACCEPTED by Owner for this finite v0.1.0 RC observation.** See [Day 7 evidence](../reports/day-7-release-closeout-2026-10-07.md) and [current release boundaries](RELEASE.md). No measurement is rerun by this documentation change.

| Metric | Actual observation |
|---|---|
| CPU avg / p95 / max | 0.012488% / 0.039502% / 0.063822% |
| RSS start / end / avg / max, decimal MB | 100.483 / 79.479 / 88.107 / 100.483 |
| RSS first / middle / final-third means, decimal MB | 93.502 / 89.300 / 81.833 |

Start/peak slightly exceed the unchanged 100 MB target; average/end are below it and all observations below the unchanged 150 MB investigation threshold. This finite run did not show obvious sustained RSS/thread growth; the owned Codex child remained one with stable PID and no defined further-investigation trigger was observed. This is not all-run RSS <100 MB or proof of no memory leak. Time Profiler/Allocations/Energy and active stress/specialized scenarios are not blanket PASS; see the dated reports for actual executed scope, with unexecuted work retaining NOT_RUN. Browser first opening, Live and prior local Mock smoke are distinct evidence.

## Product promise
A system monitor must not become the workload it monitors.

## Budgets
Window closed / menu-bar-only steady state:
- average CPU target < 0.5%
- sustained >1% requires investigation before release
- memory target <100 MB; >150 MB is a further-investigation threshold, not the first point requiring review. Exceeding the 100 MB target still requires a recorded decision.
- no continuous disk traversal
- no per-second shell subprocess loops

## Original measurement plan — Historical / not an all-PASS claim
The original Day 5 / Day 7 plan proposed Xcode Instruments where available; it does not establish that every tool/scenario below ran:
- Time Profiler
- Allocations
- Energy/Power diagnostics available in the current Xcode toolchain

Planned scenarios:
1. idle/menu bar only
2. main window Overview open
3. System page open with fast sampling
4. Cleaner scan
5. sleep/wake or network change if reproducible

## Optimization order
1. duplicate monitor loops
2. high-frequency subprocesses
3. uncancelled Tasks/timers
4. excessive UI invalidation
5. unbounded history/logs
6. expensive storage/network work
