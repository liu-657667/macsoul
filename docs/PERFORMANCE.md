# Performance Budget

## Product promise
A system monitor must not become the workload it monitors.

## Budgets
Window closed / menu-bar-only steady state:
- average CPU target < 0.5%
- sustained >1% requires investigation before release
- memory target <100 MB; review >150 MB
- no continuous disk traversal
- no per-second shell subprocess loops

## Measurement gates
At Day 5 and Day 7 use Xcode Instruments where available:
- Time Profiler
- Allocations
- Energy/Power diagnostics available in the current Xcode toolchain

Run at least:
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
