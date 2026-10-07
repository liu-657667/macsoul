# Day 5 — Performance / Lifecycle Hardening

## Scope

Owner-requested filename retained; execution date: **2026-10-07 Asia/Shanghai**. Branch feature/performance-hardening, base fbefa971e38eab780e1d6ac63244c41fdaa6d77c. Only D5-03–06; previous accepted scope and original baseline retained. No commit/push/PR or Day 6/7 work.

## Sampling Matrix Before

Inventory read from actual SensorHub, DetailCadence, DevMonitor, NetworkMonitor, AIQuotaMonitor, CodexQuotaProvider, Cleaner sessions, AppStore and AppShell before product edits.

| Source | Relevant main page | Main visible, other page | Menu-bar-only | Preview | Sleep / wake |
|---|---|---|---|---|---|
| CPU / memory numeric | System 1s | 5s | 5s | no live collector | stop / fresh native baseline; first CPU delta unknown |
| Memory pressure | native events | same | same | mock | stop / unknown until native event |
| Disk | initial + 60s | same | same | mock | stop / initial read |
| Battery | initial + events; 60s if registration fails | same | same | mock | stop notifications / fresh initial read |
| Developer processes | System ~3s | ~15s | ~15s | mock | stop / new CPU baseline |
| Runtimes | 300s cache + manual refresh | same | same | mock | stop tasks / fresh cycle with existing cache contract |
| Ports | Dev 10s | 60s | 60s; monitor loop still wakes every 5s | mock | cancel owned lsof / new cycle |
| NWPath | events | same | same | stopped | cancel / new path baseline |
| Public IP | 300s TTL + path debounce/manual | same | same | no HTTP | cancel / fresh scheduling |
| Local proxy/tunnel | initial + 60s + path/manual | same | same | mock | cancel / new read |
| Connectivity | 60s success; 60/120/300/600/900s failure; OFF disabled | same | same | no probes | cancel / baseline reset respecting OFF |
| Codex quota | event + serialized 240s verification; capped reconnect | same | same | stop/reap owned child, restore Mock | stop/reap / fresh initial read |
| Display clock | 60s UI time only | same | same | same | existing timer remains; no provider calls |
| Cleaner summary / Preview / Docker | explicit Scan / View contents only | same | same | fixtures; cancel real work | cancel scan, close Preview / no auto restart |

Live runs one shared instance of each monitor. Views influence policy through AppStore; MenuBar does not register a main window. Initial AppShell visibility uses onAppear/onDisappear; actual window close/minimize/hide fidelity needs hardening/verification. Normal termination currently awaits only AI quota teardown, while termination notification cancels Cleaner but does not await all monitors.

## D5-03 Adaptive Sampling

AUTOMATED PASS; Owner acceptance pending. One AppStore resolves `foregroundRelevant`, `foregroundBackground`, `menuBarOnly` for existing shared monitors. Views do not create collectors. Actual WindowGroup NSWindow visibility/minimize/application hide notifications replace view-appearance ownership; MenuBarExtra never registers a main window. Repeated window reports replace old relevant-page membership. Native window behavior still needs unlocked-desktop observation.

| Source | Relevant page visible | Main visible, other page | Menu-bar-only | Change |
|---|---:|---:|---:|---|
| CPU / memory numeric | System ~1s | ~5s | ~10s | menu tier 5 → 10s |
| Developer processes | System ~3s | ~15s | ~30s | menu tier 15 → 30s |
| Ports | Dev ~10s | ~60s | ~60s | loop now sleeps to next port/runtime deadline instead of fixed 5s wake |
| Runtime cache | 300s + manual | same | same | cache/resolution unchanged |
| Disk | initial + ~60s | same | same | unchanged |
| Memory pressure | native events | same | same | unchanged |
| Battery | initial + native notifications | same | same | 60s fallback only if notification registration fails; unchanged |
| NWPath | native events | same | same | unchanged |
| Public IP | 300s TTL; debounce/manual | same | same | unchanged |
| Proxy / tunnel facts | ~60s + path/manual | same | same | unchanged |
| Connectivity | ~60s success, existing capped failure backoff | same | same | OFF/cancellation unchanged |
| Codex | event-first + serialized 240s read | same | same | no page-driven acceleration |
| Display clock | 60s time-only | same | same | no provider work or Snapshot reassignment |
| Cleaner / content Preview / Docker | explicit actions only | same | same | no automatic scan |

Intervals are scheduling targets. Native event delivery, task completion and OS suspension can affect timing. Runtime/port policy changes cancel only the pending delay; the collector instance remains shared. Performance benefit is not inferred from these constants.

## Lifecycle Matrix

| Transition | System / Dev | Network | Quota / owned Codex | Cleaner / content Preview |
|---|---|---|---|---|
| Preview | stopped; Mock restored | stopped; no probes | stop/reap; Mock restored | cancel/invalidate; close Preview |
| Preview → Live | one collector; fresh CPU/process baseline; fresh Dev cycle | one fresh path lifecycle | one initial read lifecycle | Not Run; no auto scan |
| Live → Preview → Live | prior teardown awaited before next loop | old generation rejected | prior child teardown awaited; old updates rejected | old generation rejected |
| Sleep | stop/cancel pending loops/tasks | stop path/requests | stop/reap; transient alerts cleared | cancel scan, invalidate generation, close Preview |
| Wake in Live | restart exactly once | fresh path lifecycle | fresh initial cycle, old sample not labeled fresh | never restart scan |
| Wake in Preview | no live collector | no requests | no child/read | no scan |
| Network path event | no restart | existing invalidation/debounce/scheduling only | no restart | no scan |
| Normal termination | stop and await both monitors | stop and await | stop and await owned child | cancel/invalidate and await scan/Preview |

Termination also cancels the display timer and lifecycle subscriptions. Repeated termination and wake calls are idempotent. Late Store callbacks and new Cleaner Preview opens are rejected after termination. No user Terminal, IDE, ChatGPT or independent Codex process is targeted.

## D5-04 Sleep/Wake/Network Review

AUTOMATED PASS using injected sources and existing simulated clocks. Cleaner suspend previously only cancelled the task; a late cancelled-cycle update could still arrive under its generation. Suspend now invalidates that generation, records cancellation, and keeps teardown awaitable. A gated fixture asserts no post-suspend completion callback and no automatic restart.

REAL SLEEP/WAKE = NOT_RUN. No `pmset sleepnow`, Wi-Fi/VPN/proxy/DNS/route changes or artificial network outage. Owner-assisted checklist: choose Live, note all shared surfaces; sleep manually, wake, confirm fresh CPU baseline/pressure semantics and quota initial read; verify one owned child, Cleaner remains idle, then repeat in Preview and confirm no Live collectors. Owner must supply confirmation before these items are accepted.

## Automated Integration Tests

331 prior tests retained; **13 new tests, 344 total / 0 failures** on local Xcode 27.

New integration coverage in `AIQuotaLifecycleTests.swift` and `CleanerTests.swift`:

- System fast/background/menu policies, 10 repeated open/close policy cycles; collector starts stay one.
- Multiple main windows; hidden-window selection cannot promote the policy; repeated same-window report replaces old section.
- Dev fast/background/menu ports; AI remains event/240s regardless of selected page.
- Three Preview/Live round trips, serialized source lifecycles, maximum injected active System source <= 1, zero Cleaner scans.
- Simulated sleep stops all sources; duplicate wake starts one new cycle; Preview wake starts none.
- Network path event affects Network only; retired path/quota callbacks cannot enter a new lifecycle.
- Repeated termination stops and awaits all sources and prevents resurrection.
- Display clock changes do not alter quota Snapshot or restart providers.
- Shared unavailable sensor/disk, absent battery, runtime/no-listener/lsof-timeout and offline/unavailable provider facts remain distinct.
- Menu process 30s and disk 60s cadence; Dev deadline sleep respects port and runtime TTL.
- Cleaner gated traversal after suspend cannot publish old generation or restart automatically.

These are injected integration assertions, not proof of real NSWindow notification delivery or physical sleep/wake. Existing real child-pipe teardown tests still pass. Compile/assertion failures during test development were repaired; their logs remain in ignored performance artifacts, not counted as passing runs.

## Performance Methodology

Prepared unsigned Release `-O`, no debugger; project/scheme MacSoul, native macOS destination, separate `.artifacts/perf/DerivedData`. Debug scripts remain the functional regression gate.

Environment: Mac14,9; 12 logical CPUs; 16 GiB RAM; macOS 27.0.1 / 26A434; Xcode 27.0 / 27A266a. Execution date 2026-10-07 Asia/Shanghai. CLI template/help inspection was actually executed. Time Profiler available; Energy Log not listed. Power Profiler is a different template and is not reported as Energy PASS.

Prepared native read-only `proc_pid_rusage` sampler, with 20s warm-up, 2s sample interval, A–E >=60s and F >=300s. CPU is delta cumulative user+system ns / monotonic elapsed seconds ×100; one logical CPU = 100%. Peak/p95 are interval averages, not instantaneous peaks. RSS uses decimal MB = bytes / 1,000,000. Discover only descendants of the known App PID via PID/PPID/executable basename; do not persist full arguments. Report MacSoul and owned Codex separately. Measure CPU/RSS separately from Instruments to avoid its recording overhead, then use Time Profiler for hot-stack review. No Cleaner Scan, stress or quota consumption.

Preparation artifacts (ignored): `release-build.log`, `xctrace-templates.txt`, `xctrace-record-help.txt`, `xctrace-export-help.txt`, `measure.py`, `availability-hot-stacks.json` under `.artifacts/perf/`.

## Performance Results

Initial checkpoint: NOT_RUN. Current checkpoint: **A–F steady-state measurements remain NOT_RUN**. Desktop is locked; CUA explicitly reports it cannot operate UI. Owner has been asked to unlock manually. No alternate control path or automatic unlocking is attempted.

| Scenario | Required duration after warm-up | MacSoul avg/peak/p95 CPU / RSS | Owned Codex CPU / RSS / count | Status |
|---|---:|---|---|---|
| A Preview idle, main visible | >=60s | UNKNOWN | UNKNOWN | NOT_RUN |
| B Live Overview | >=60s | UNKNOWN | UNKNOWN | NOT_RUN |
| C Live System | >=60s | UNKNOWN | UNKNOWN | NOT_RUN |
| D Live Dev | >=60s | UNKNOWN | UNKNOWN | NOT_RUN |
| E Live AI Coding | >=60s | UNKNOWN | UNKNOWN | NOT_RUN |
| F Live menu-bar-only, main closed | >=300s | UNKNOWN | UNKNOWN | NOT_RUN |

Background CPU <0.5%, RSS <100 MB and >150 MB review threshold are **UNVERIFIED**. Combined App/helper cost, duplicate real collectors, thread growth and periodic steady-state spikes have not been measured. The locked-desktop profiling pilot is not substituted for F. D5-05 remains doing.

## Instruments Findings

A real **15s Time Profiler availability pilot** attached to the unsigned Release App; command exit 0, export exit 0. Only 10 CPU samples were captured while desktop locked. Sampled paths include AppKit/CoreFoundation run-loop/status-bar work and Objective-C/Swift runtime functions. This tiny locked-desktop sample does not establish steady-state hotspots, CPU targets, UI redraw cost or lack of leaks.

Raw capture was removed after discovery that Instruments automatically embeds process environment. Only sanitized function-weight summary, sanitized table schema/TOC and command exit logs remain. Future scenario recordings must avoid persisting sensitive inherited process environment and must never dump a full trace TOC to output.

Energy Log = NOT_RUN / template unavailable. Xcode 26.6 CI = NOT_RUN on this uncommitted branch.

## Fixes / Re-measurement

Authorized cadence/lifecycle changes above are backed by policy/cancellation tests. No performance-target claim or measurement-driven optimization is made before A–F are measured. No broad refactor, new provider, endpoint/backoff/parser or quota semantic change.

Display clock review: `advanceDisplayClock` only publishes `displayNow`; integration tests verify no Snapshot/Provider mutation. Views observing AppStore can still invalidate from published clock or shared snapshots. Whether this causes a material rendering hotspot requires the pending real profile; no speculative invalidation rewrite was performed.

## Failure-state Checklist

| Area / case | Automated evidence (current suite) | This round real/Owner evidence |
|---|---|---|
| System unknown sensor, unavailable disk, no battery | AUTOMATED PASS: new shared failure test + existing SystemSoul/SystemDetails tests | NOT_OBSERVED; no machine mutation |
| Memory pressure unknown/normal/warning/critical separation | AUTOMATED PASS: existing mapping and Soul tests | prior natural Warning Owner acceptance preserved; Critical NOT_OBSERVED |
| Dev missing runtime / empty listeners / lsof error or timeout | AUTOMATED PASS: DevEnvironmentTests + injected shared failure test | NOT_OBSERVED; no toolchain removal |
| Network unsatisfied, IP timeout/failure, probe failure/OFF | AUTOMATED PASS: NetworkTests and lifecycle integration | prior Owner OFF/ON/failure presentation acceptance preserved; new outage NOT_RUN |
| Malformed proxy / unavailable local facts | AUTOMATED PASS: NetworkTests | NOT_OBSERVED; no proxy change |
| Codex missing/unsupported version, handshake, malformed response | AUTOMATED PASS: AIQuotaTests/AIQuotaLifecycleTests | this round NOT_OBSERVED; prior D4 acceptance unchanged |
| Reconnect retains original numeric/time; stale; bounded retries | AUTOMATED PASS: AIQuotaLifecycleTests + QuotaTests | reconnect failure NOT_OBSERVED; no quota burn |
| Week-only / personal-pro / remaining / 95% eligibility | AUTOMATED PASS: existing parser/presentation/alert tests | prior D4 OWNER OBSERVED PASS retained; real 95% event NOT_OBSERVED |
| Claude unavailable honest source | AUTOMATED PASS: existing presentation/capability tests | prior D4 OWNER OBSERVED PASS retained |
| Cleaner Not Run / missing/inaccessible/partial/cancelled | AUTOMATED PASS: CleanerTests/PreviewTests + gated suspend test | prior D5-01/02 scan/Preview OWNER OBSERVED PASS retained; no new scan |
| Docker unavailable / malformed / cancelled | AUTOMATED PASS: CleanerDiscoveryTests | prior read-only query OWNER OBSERVED PASS retained; new failure NOT_OBSERVED |
| Real main close/minimize/hide/MenuBar-only policy | injected policy AUTOMATED PASS | NOT_RUN pending desktop unlock |
| Real sleep/wake | simulated lifecycle AUTOMATED PASS | NOT_RUN; Owner-assisted checklist above |

Fixture PASS does not certify physical failure behavior, performance, new Owner UI acceptance or complete product interactions. Stop command remains clipboard-only; listening ports are not conflicts; Cleaner remains read-only/on-demand.

## Privacy

No raw quota percentage/reset, account/profile/session payload or browser data is written to report/evidence. Reports contain only normalized state boundaries and prior acceptance references. Product privacy manifest is unchanged. No credential/account operations or system mutation.

**Diagnostic handling incident:** Instruments pilot automatically captured process environment; an initial TOC inspection exposed a sensitive field in tool output. The exact temporary raw trace/stack export was removed and the retained TOC stripped of environment/device identity. No sensitive values are copied into tracked files or this report. Owner was informed and advised to rotate the exposed value. This incident is not represented as a clean privacy PASS. Future profiling requires sanitized launch/capture handling.

## REAL / OWNER OBSERVATION

Actual local clean Debug build/tests and Release build executed. Actual Time Profiler pilot executed; desktop was locked. New Owner acceptance, native window interaction, A–F steady-state performance and physical sleep/wake remain pending. Earlier System/Dev/Network/Cleaner/AI Owner acceptances remain unchanged in ledger/history.

## NOT_RUN / NOT_OBSERVED

- A–F performance scenarios, target validation, owned Codex CPU/RSS/count and rendering hotspots: NOT_RUN pending desktop unlock.
- Real sleep/wake, active network disruption, resource stress, real Cleaner scan: NOT_RUN; none manufactured.
- Energy Log: NOT_RUN / template unavailable.
- Xcode 26.6 / 17F113 CI: NOT_RUN; local Xcode 27 is not compatibility evidence.
- App Store Connect privacy validation: NOT_RUN.
- Natural quota update / real 95% event / real Memory Pressure Critical: NOT_OBSERVED; no forced triggering.
- Cleanup, Notch, real user process termination, Day 6/7, signing/notarization: not implemented in this round.

## Final Verification

Latest product source fingerprint: `e86010dd504149d672410c88430f671fbcc4648bad2f2f2b068b47f5583ab898` at base HEAD `fbefa971e38eab780e1d6ac63244c41fdaa6d77c` plus uncommitted hardening changes. All results below are local, not CI.

A requested explicit `rm -rf` command was rejected by automatic approval review. Instead, exactly the authorized old Debug DerivedData/xcresult were renamed into `.artifacts/perf/prior-debug-*`; Debug then built and tested from empty paths. Existing local files were preserved.

- Clean Debug build/test at initial implementation checkpoint: PASS, 344 / 0.
- After final membership/termination guards and generated-status update: build/test PASS, 344 / 0.
- `python3 scripts/test_progress.py`: PASS (positive and six negative cases).
- Initial `verify.sh`: product checks PASS; ledger FAIL due to old evidence fingerprints, preserved in `.artifacts/perf/verification-before-ledger-refresh.*`.
- Existing automated evidence refreshed only after real passing checks; previous evidence moved into `evidence_history`; historical Owner confirmations unchanged.
- `python3 scripts/verify_progress.py`: PASS, 59 tasks / original 76 points.
- Final clean Debug build/test from empty paths: PASS; 344 tests / 0 failures. Final `verify.sh`: PASS (doctor/build/unit/progress tests/visual assets/ledger all exit 0). `git diff --check`: PASS, exit 0. Final manifest timestamp UTC: 2026-10-06T16:58:08.968826+00:00.
- Release build after final lifecycle guards: PASS, exit 0. Packaged privacy reasons checked unchanged: DiskSpace/85F4.1, UserDefaults/CA92.1, SystemBootTime/35F9.1.

This report preserves the earlier NOT_RUN performance checkpoint. Later measurement must append actual duration/environment/timestamp/results, not rewrite this checkpoint as PASS.

## Task State

D5-03 = verifying; D5-04 = verifying; D5-06 = verifying. Automated evidence attached, new Owner review pending.

D5-05 = doing. A real Instruments availability pilot alone does not satisfy the required scenario measurement. Awaiting manual desktop unlock to measure and then enter verifying.

D5-01/02 and D2/D3/D4 accepted states/history preserved. Original days, points/dependencies/baseline unchanged. Day 6/7 untouched. No staging, commit, push or PR. Branch `feature/performance-hardening`; working tree contains this round's changes only.

## Desktop-unlock Handoff

Final Release App prepared at `.artifacts/perf/DerivedData/Build/Products/Release/MacSoul.app`; PID 80357. Only the known pilot PID 66473 received SIGTERM and exited normally; no SIGKILL. App launched with a runtime-context environment allowlist to exclude unrelated shell secrets; no global environment/PATH/config edits. Proxy override is not injected. Desktop remains locked; prepared measurement helper is not yet executed for A–F. Once Owner unlocks, verify actual main/section state via native UI, record mode/network/provider capability, measure all six scenarios and child cost, profile actual steady state, then append results and revalidate any finding-driven source change. Do not promote D5-05 or claim targets before this work.

## Formal Performance Measurement — unlocked desktop

Owner confirmed desktop unlocked. Current process read-only identity check: exactly one MacSoul, PID 80357, executable under this round’s unsigned Release build; no Debug App and no owned descendants before A. No product source changes in this continuation. Environment/build/methodology as above. A–F observations are recorded separately from the earlier locked-desktop checkpoint.

### A — Preview idle / main visible

- Timestamp UTC: 2026-10-06T17:07:09.527791+00:00 (Asia/Shanghai execution date 2026-10-07).
- Release unsigned `-O`, no debugger. Warm-up 20s; measurement 60.048s; sample interval 2s. Actual native UI showed main Overview and Developer Preview before measurement. No interaction during sampling.
- MacSoul CPU avg/p95/max interval: 0.0085%/0.0560%/0.0738%.
- MacSoul RSS avg/max: 61.633/78.545 decimal MB.
- Codex child count 0; no child CPU/RSS sample (not an invented zero-memory child). No owned helper observed. Preview stops Live collectors by existing contract and tested integration; no packet-capture claim that proves network absence. Cleaner Scan not invoked.
- Evidence: `.artifacts/perf/A-preview-main.json`; observer exit 0.

### Remaining scenarios — UI transport interruption

After A, native UI action and subsequent reconnect/reset attempts returned `Sky Computer Use native pipe closed before response`. This is a separate transport failure after desktop unlock. No AppleScript, shell UI automation or hidden configuration path is used to substitute for native UI. Owner asked to select Live Overview manually for B. B–F and required System/menu Time Profiler captures remain pending; D5-05 stays doing.

### B / C — completed before second UI interruption

| Scenario | Timestamp UTC | Warm-up / duration | MacSoul CPU avg/p95/max % | RSS avg/max decimal MB | Owned Codex count | Thread count start/end | UI evidence |
|---|---|---|---|---|---|---|---|
| B — Live Overview | 2026-10-06T17:10:14.234362+00:00 | 20s / 60.057s | 0.0210/0.0573/0.2062 | 70.303/78.430 | 0 | 6/5 | Owner confirmed before run; native UI confirmed Live Overview afterwards |
| C — Live System | 2026-10-06T17:11:56.115368+00:00 | 20s / 60.046s | 0.0573/0.0921/0.1141 | 77.725/80.609 | 0 | 8/7 | native UI selected System before run |

Same unsigned Release PID 80357, 2s sampling, no debugger/profiler during CPU/RSS runs. Collector singleton/start counts are source/injected integration evidence, not inferred from displayed percentages. Real internal per-monitor counts are not exposed by the Release UI; no debugger or hidden diagnostic feature was added.

**Codex environment limitation:** read-only explicit bundled `codex --version` returned 0.160.1. The existing native Provider accepts only previously verified 0.160.0 and fails conservatively. B/C observed no long-lived owned Codex child; Live Overview honestly showed quota unavailable. Child CPU/RSS and combined fully-enabled AI cost are therefore NOT_MEASURED, not a zero-cost supported-provider claim. No gate, mapping, cadence or Provider code change.

### System Time Profiler — formal capture

60s Time Profiler on actual Live System, record/export exit 0, 1424 samples / 1424ms statistical sample weight. Main-thread weight 1347ms; worker/other 77ms. Leaf examples: `find(_:key:filter:)` 61ms; `objc_msgSend` 57ms; `AG::Graph::propagate_dirty(AG::AttributeID)` 30ms. Inclusive System sampling 37ms, process enumeration 23ms, Dev deadline loop 2ms; areas overlap and are not whole-process CPU percentages.

Broad SwiftUI binary/root-frame affinity was initially classified as rendering; this interpretation was corrected in the sanitized summary. The 1340ms root affinity includes `App.main/runApp` and must **not** be read as render cost. Specific leaf/graph functions above are valid sampled symbols. Clock publication is not isolated as a clear actionable hotspot by this capture; indirect invalidation remains possible. Independent C CPU/RSS is within budget, so no speculative source fix is made. Raw trace and raw stack XML removed; symbol/weight/thread-role summary retained at `.artifacts/perf/C-system-formal-hotspots.json`.

D/E/F, five real close/reopen cycles, native adaptive policy observation and menu-bar-only formal profile are still pending after UI transport failed again. Owner was asked to select Dev manually. The actual A–C results do not promote D5-05 to verifying.

### D — Live Dev, Owner-assisted page selection

Owner confirmed Dev ready; exact Release executable/PID 80357 reconfirmed, one App instance. Timestamp UTC 2026-10-06T17:26:13.054649+00:00; 20s warm-up, 60.047s measurement at 2s intervals, Release unsigned `-O`, no debugger/profiler. CPU avg/p95/max interval 0.0088%/0.0398%/0.1018%; RSS avg/max 38.180/55.804 decimal MB. Owned Codex/helper count 0; no child CPU/RSS sample. App thread count 4 → 4.

No copy/stop controls invoked and no real process termination. Native UI connection still failed after D, so E requested by Owner-assisted navigation. RSS is current resident memory under the same real machine conditions; its decrease does not demonstrate heap retention/leak absence. Evidence `.artifacts/perf/D-live-dev.json`, observer exit 0. A–D complete; E/F, menu profile and five close/reopen cycles pending.

### E — Live AI Coding, unavailable verified-version boundary

Owner confirmed AI ready; same Release PID 80357. Native UI after E confirmed Live AI Coding, Codex unavailable with CLI 0.160.1 and honest Claude unavailable. No quota number/reset retained. Timestamp UTC 2026-10-06T17:29:52.267667+00:00; 20s warm-up, 60.048s measurement at 2s intervals, Release unsigned `-O`, no debugger/profiler. CPU avg/p95/max interval 0.0167%/0.0394%/0.1238%; RSS avg/max 59.716/66.519 decimal MB. Owned Codex/helper count 0; supported Codex child CPU/RSS remains NOT_MEASURED, not zero. Thread count 6 → 6. No account request, quota burn, Provider semantic or refresh change.

Evidence `.artifacts/perf/E-live-ai.json`, observer exit 0. Native UI File menu exposes New Window/Close. A close-button action followed by state observation returned an Overview main window; the intermediate closed state could not be reliably observed and is not counted as a successful native five-cycle acceptance. Owner asked to perform five cycles manually and finally close all main windows/popover before F. No UI observation that could reopen a window will be invoked during F.

### Owner window lifecycle observation before F

Owner explicitly confirmed: five main-window close → MenuBar Open MacSoul → reopen cycles normal; System continued updating after reopen. Final state confirmed by Owner: Live mode, all main windows and MenuBar popover closed, App still resident. Exact process identity after cycles unchanged at Release PID 80357; one MacSoul instance. This is OWNER OBSERVED PASS for real window interaction/continued update, separately from injected start-count/policy assertions. Exact per-monitor runtime counts and event timestamps are not exposed by this build and are not guessed from UI percentages. Physical sleep/wake remains NOT_RUN.

No further CUA observation/action is used during F, avoiding the previously observed main-window reopening side effect. F native rusage sampling and later attached Time Profiler do not require opening a window.

### F — Live menu-bar-only, final formal measurement

Owner confirmed Live, all main windows/popover closed and App resident after five successful close/reopen cycles. No CUA calls during F or its profile; no Cleaner scan, physical sleep or manufactured resource/network load. Same Release PID 80357, one App, no Debug instance.

### Final A–F consolidated results

All runs: unsigned Release `-O`, no debugger/profiler during CPU/RSS measurement; 20s warm-up. CPU average is the arithmetic mean of native CPU interval deltas; p95/max describe interval averages, not instantaneous peaks. One logical CPU = 100%. RSS is decimal MB, not MiB. Timestamp is observer start UTC; local execution date is 2026-10-07 Asia/Shanghai.

| Scene | Timestamp UTC | Measured s | CPU avg / p95 / max % | RSS avg / max MB | Codex count | Codex avg / p95 / max CPU; avg / max RSS | Threads start/end |
|---|---|---:|---|---|---:|---|---|
| A-preview-main | 2026-10-06T17:07:09.527791+00:00 | 60.048 | 0.0085 / 0.0560 / 0.0738 | 61.633 / 78.545 | 0 | N/A / N/A / N/A; N/A / N/A | NOT_RECORDED / NOT_RECORDED |
| B-live-overview | 2026-10-06T17:10:14.234362+00:00 | 60.057 | 0.0210 / 0.0573 / 0.2062 | 70.303 / 78.430 | 0 | N/A / N/A / N/A; N/A / N/A | 6 / 5 |
| C-live-system | 2026-10-06T17:11:56.115368+00:00 | 60.046 | 0.0573 / 0.0921 / 0.1141 | 77.725 / 80.609 | 0 | N/A / N/A / N/A; N/A / N/A | 8 / 7 |
| D-live-dev | 2026-10-06T17:26:13.054649+00:00 | 60.047 | 0.0088 / 0.0398 / 0.1018 | 38.180 / 55.804 | 0 | N/A / N/A / N/A; N/A / N/A | 4 / 4 |
| E-live-ai | 2026-10-06T17:29:52.267667+00:00 | 60.048 | 0.0167 / 0.0394 / 0.1238 | 59.716 / 66.519 | 0 | N/A / N/A / N/A; N/A / N/A | 6 / 6 |
| F-live-menu-only | 2026-10-06T17:36:07.887654+00:00 | 300.054 | 0.0249 / 0.0824 / 0.1693 | 70.590 / 80.216 | 0 | N/A / N/A / N/A; N/A / N/A | 6 / 8 |

Configured interval 2s; actual interval mean/max seconds A–F: A 2.001/2.159; B 2.002/2.071; C 2.002/2.088; D 2.071/2.136; E 2.071/2.571; F 2.041/2.152. Scheduling/process-discovery overhead causes jitter. All six observers exited 0. Evidence: the six named JSON runs and aggregate `.artifacts/perf/performance-summary.json`; all remain ignored local artifacts.

Codex count 0 in all runs: CLI 0.160.1 is unsupported by the existing verified 0.160.0 gate. No long-lived app-server exists to measure; supported Codex cost is NOT_MEASURED. Child CPU/RSS is N/A, never fabricated zero. Observed other-helper count also 0, but short-lived lsof/runtime children can fall between 2s snapshots. No claim of total child spawn count or fully enabled combined Provider cost.

F thread count 6 → 8 is finite observed growth, not proof of zero leaks. Highest F interval CPU 0.1693% at approximately 78s; other peaks near 16s (0.1669%) and 199s (0.1456%). Some peaks approximately 60s apart are compatible with periodic work, but no exact scheduler/clock causal attribution is proven. All remained under 0.5%; no spike-driven fix required.

## Time Profiler Findings

Two separate real 60s Time Profiler captures attached to Release PID 80357; record/export each exit 0. Statistical sample weights are under instrumentation, not target CPU measurements. Inclusive areas overlap. Raw traces/stack XML removed after sanitized summaries; only function, weight and thread role retained.

| Area / finding | Live System C | Menu-bar-only F | Interpretation |
|---|---:|---:|---|
| Total sample weight | 1424 ms | 638 ms | Statistical CPU samples; not wall-time duration |
| Main / worker thread weight | 1347 / 77 ms | 585 / 53 ms | Main run-loop/UI work present |
| System sampling | 37 ms | 12 ms | No dominant sensor hotspot |
| Process enumeration | 23 ms | 4 ms | Bounded observed contribution |
| Dev deadline loop | 2 ms | 1 ms | No prominent deadline-loop cost |
| Network scheduler | Not separately classified | 4 ms | No clear network scheduling hotspot |
| Task/timer runtime | 247 ms | 86 ms | Overlapping runtime frames, not a wakeup count |
| Specific SwiftUI graph/render frames | Leaf graph functions observed; broad root affinity excluded | 412 ms inclusive | Do not equate root App.main affinity with rendering |
| Display clock | No isolated actionable hotspot | 1 ms | Direct clock samples small; indirect invalidation possible |
| Codex pipe/read | Not observed; no owned child | Not observed; no owned child | Supported-provider performance unmeasured |

C leaf examples: `find(_:key:filter:)` 61ms, `objc_msgSend` 57ms, `AG::Graph::propagate_dirty(AG::AttributeID)` 30ms. F: `<deduplicated_symbol>` 32ms, `objc_msgSend` 21ms, `find(_:key:filter:)` 21ms, `mach_msg2_trap` 15ms, `AG::Graph::UpdateStack::update()` 14ms, `AG::Graph::propagate_dirty(AG::AttributeID)` 12ms. Unresolved/deduplicated symbols are not assigned a guessed product cause.

Evidence: `.artifacts/perf/C-system-formal-hotspots.json` and `.artifacts/perf/F-menu-formal-hotspots.json`. The C 1340ms SwiftUI root-frame affinity is explicitly NOT rendering attribution. F specific graph/render classification avoids that broad binary match. The 60s display clock does not show a sufficiently clear costly causal stack to justify source changes; independent parent measurements meet targets.

## Target Evaluation

- F parent average CPU 0.0249% < 0.5%: measured PASS in the current Codex-unavailable environment.
- F parent average RSS 70.590MB and max 80.216MB < 100MB: measured PASS. All A–F parent RSS maxima <100MB; none enters 100–150MB REVIEW or >150MB analysis band.
- Supported Codex child/fully enabled combined App+helper cost: NOT_MEASURED. Observed resident process set contains the parent only; this cannot certify absent/short-lived helper cost.
- Five real window close/reopen cycles and continued System updates: OWNER OBSERVED PASS. Exact runtime collector counts/cadences remain uninstrumented. Source/injected tests separately verify singleton lifecycle and CPU/memory 1/5/10s, processes 3/15/30s, ports 10/60/60s policies; MenuBarExtra is excluded from main-window presence. No finite run establishes indefinite leak freedom.

## Measurement-driven Fixes

**No performance-driven source fix required.** No product source change in this unlocked-desktop continuation. Existing sampling/lifecycle hardening was implemented before formal measurements, verified separately. No version-gate, quota, Provider, Network or Cleaner change to manufacture performance results.

## Final measurement closeout / verification checkpoint

Source/verification-input fingerprint rechecked unchanged: `e86010dd504149d672410c88430f671fbcc4648bad2f2f2b068b47f5583ab898`; base HEAD `fbefa971e38eab780e1d6ac63244c41fdaa6d77c` plus the previously verified uncommitted hardening. Per existing fingerprint protocol, tasks/report/generated STATUS are excluded; ledger-only updates do not create a new source behavior checkpoint. Existing clean Debug build/test/verify PASS (344 tests / 0 failures, manifest 2026-10-06T16:58:08.968826+00:00), Release build PASS and packaged privacy PASS remain current for unchanged sources. They were not needlessly rerun during this record-only continuation. The automation manifest performance NOT_RUN field describes its automated command scope; separate formal evidence above is not used to falsify that manifest. Final ledger/progress regression/diff checks are recorded below after generation.

D5-03/04/05/06 now all **verifying**, not done. D5-05 enters verifying because A–F and both formal profiles are executed/recorded; final Owner review pending, supported-Codex cost limitation retained. Original task days/points/dependencies/history and earlier locked-desktop NOT_RUN checkpoint retained. Day 6/7 unchanged.

Remaining: real sleep/wake NOT_RUN; active outage/stress NOT_RUN; Energy Log NOT_RUN (template unavailable); current uncommitted Xcode 26.6 CI NOT_RUN; App Store Connect privacy validation NOT_RUN; real quota update/95% event and real Memory Pressure Critical NOT_OBSERVED. No new Cleaner scan, account/profile reads, quota burn, system proxy/VPN/DNS/route mutation or cleanup. Prior accepted real feature evidence stays unchanged.

### Record-only final checks

Executed 2026-10-06T17:46:09.080279+00:00: STATUS generation exit 0; `verify_progress.py` exit 0 (59 tasks / original 76 points); `test_progress.py` exit 0 (positive + six negative cases); `git diff --check` exit 0. Baseline fields/acceptance definitions and all other statuses checked unchanged. Packaged/source privacy manifests identical; original three reasons retained. Formal raw traces absent; performance evidence ignored. Local `.artifacts/perf/closeout-checks.json` records these results.

Working tree: `feature/performance-hardening`, base HEAD unchanged, 14 modified tracked files plus this new report (15 total). Scope: sampling/lifecycle/store/window-presence guards, two test files, existing STATUS generator, ledger/generated STATUS/report. Large ledger diff includes refreshed automated evidence and preserved evidence_history from the earlier passing source checkpoint; it does not alter original points or accepted history. No staged files, commit, push or PR. Current Release App PID 80357 remains running; no more UI actions or subsequent work. Stop for Owner review.

## Codex 0.160.1 compatibility

Execution date 2026-10-07 Asia/Shanghai. Compared official `openai/codex` tags `rust-v0.160.0` and `rust-v0.160.1`: all three required files are byte-identical, SHA-256 pairs retained only in local normalized comparison `.artifacts/perf/codex-01601-upstream-comparison.json`. Dependencies verified present: account/rateLimits/read and updated, RateLimitSnapshot, primary/secondary, usedPercent, windowDurationMins, resetsAt, rateLimits/rateLimitsByLimitId, limitId and planType. No unrelated upstream code copied into the report.

- [GetAccountRateLimitsResponse schema](https://raw.githubusercontent.com/openai/codex/rust-v0.160.1/codex-rs/app-server-protocol/schema/json/v2/GetAccountRateLimitsResponse.json)
- [Account protocol](https://raw.githubusercontent.com/openai/codex/rust-v0.160.1/codex-rs/protocol/src/account.rs)
- [RPC common protocol](https://raw.githubusercontent.com/openai/codex/rust-v0.160.1/codex-rs/app-server-protocol/src/protocol/common.rs)

Actual bundled CLI 0.160.1: initialize PASS, initialized sent, exactly one account/rateLimits/read SUPPORTED, 15s bounded passive observation. Unique Codex bucket, legacy/multi-bucket objects, 10080-minute numeric window and valid numeric percentage/integer Unix-seconds types observed; secondary absent. Actual percentage/reset/raw plan/account payload never persisted. Observation records plan field type only; production classification remains the unchanged CodexPlanSemantics mapping. Natural update notification NOT_OBSERVED. Observer stdin closed and child exited normally. Sanitized artifact `.artifacts/perf/codex-01601-capability-redacted.json`. No account/read, login/logout, inference, quota burn or mutation RPC.

Minimal product change: explicit accepted set {0.160.0, 0.160.1}. No wildcard/range; 0.160.2, 0.161.0, malformed and nil reject before transport open. Six new async version-gate tests (two accepted handshakes and four rejected no-open paths); 350 tests / 0 failures. Parser, transport, Claude, plan mapping and privacy source unchanged. Event-first + 240s verification/reconnect/cadence unchanged.

Debug build/test/progress regression PASS; new Release build PASS. First full verify on new fingerprint had doctor/build/unit/progress/visual PASS and ledger FAIL for previous source fingerprints only; failed manifest/log retained. Actual passing automated records refreshed into new evidence while old entries retained in evidence_history; historical Owner evidence unchanged. Full verify is rerun after refresh. Previous unsupported-version and parent-only performance results remain historical checkpoints, not overwritten.

Compatibility final verification: build/test/progress regression/verify/ledger all exit 0; 350 tests / 0 failures. Manifest UTC 2026-10-06T17:54:40.441487+00:00; source fingerprint `2f2f614d778c95c262b279fb57e21acbeac6c8e88347c030f9fd185dfec31301`. New unsigned Release build exit 0; packaged privacy equals source and only original three reasons. Owner authorized normal SIGTERM of old Release PID 80357 and old docs Debug PID 44852; both normal exits confirmed. New minimal-environment Release PID 47535 is the only App; no other process terminated.

## Supported-provider E/F performance

Owner confirmed 0.160.1 Live AI ready following requested source/version/numeric/remaining/machine-driven 5h/Claude boundary checks. No quota percentages or reset timestamps retained. Observed exactly one owned Codex child PID 48279 beneath new Release PID 47535.

E actual observer timestamp UTC 2026-10-06T17:56:29.552874+00:00: warm-up 20s, formal duration 60.051s, configured interval 2s. Parent CPU avg/p95/max 0.0170%/0.0382%/0.1440%; RSS avg/max 76.629/89.817 decimal MB. Child CPU avg/p95/max 0.000184%/0.001109%/0.001728%; RSS avg/max 44.062/51.118 MB. Exactly one same-PID child at every sample; parent threads 8→7, child 26→26. Other helper observed count 0; short-lived children may fall between samples. Evidence `.artifacts/perf/E-01601-live-ai.json`, observer exit 0. No debugger/Instruments during CPU/RSS measurement. F and supported-child profile pending Owner close-window handoff at this checkpoint.

### Supported-provider F — complete

Owner confirmed Live, all main windows/popover closed, App resident. Same Release PID 47535 and owned Codex PID 48279 throughout E/F; all samples exactly one child. F timestamp UTC 2026-10-06T18:01:16.204344+00:00 (2026-10-07 Asia/Shanghai), warm-up 20s, formal measurement 300.053s, configured interval 2s; observer exit 0.

| Scene / process | CPU avg / p95 / max % | RSS avg / max decimal MB |
|---|---|---|
| E MacSoul | 0.016996 / 0.038169 / 0.143974 | 76.629 / 89.817 |
| E owned Codex | 0.000184 / 0.001109 / 0.001728 | 44.062 / 51.118 |
| F MacSoul | 0.005728 / 0.029614 / 0.048416 | 53.427 / 63.029 |
| F owned Codex | 0.000416 / 0.001203 / 0.012843 | 38.682 / 46.088 |

Parent F average CPU <0.5% and max RSS <100MB: measured PASS with supported Codex active. Child has no prescribed hard target; observed low CPU and bounded RSS, no sustained high CPU. Combined same-point parent+child E avg/max RSS 120.691/140.935MB, avg CPU 0.017180%; F avg/max RSS 92.109/102.711MB, avg CPU 0.006144%. Combined values are not used as the parent-only 100MB threshold. Short-lived helpers may be missed. RSS changes do not prove heap leak freedom.

F parent threads 6→8, child 26→24; no runaway thread growth demonstrated in this finite run. Native sampler avg/p95/max semantics unchanged; no Instruments overhead in target measurements. Actual interval mean/max E/F: E 2.002/2.075s; F 2.041/2.171s. Evidence: `.artifacts/perf/supported-provider-performance-summary.json`, individual E/F JSON and observer logs. Prior A–F parent-only measurements retained as earlier checkpoint; A–D not repeated because only the exact Codex version gate changed, with supported child cost specifically remeasured in E/F.

### Supported Codex child formal profile

Real Time Profiler attached to owned Codex PID 48279 while all main windows/popover remained closed; 60s, record/export exit 0, 15 CPU samples / 15ms statistical weight, all worker/other. Inclusive Tokio multi-thread worker run 13ms; Rust backtrace wrapper 14ms. Leaf allocation, pthread join, Objective-C/runtime/memory-copy examples each 1ms; many unresolved symbols. Address-only labels normalized to `<unsymbolicated>` in retained summary. Sparse profile does not establish exact pipe/RPC function costs or a complete call count.

No observed busy-wait/reconnect-spin indication: E/F CPU very low, same one child PID at all samples, finite thread counts 26→24. Existing version lookup is once per start before transport loop; event-first +240s tests continue PASS; no high-frequency read/cadence changes. Exact native RPC invocation counters not instrumented; profile and stable PID do not alone prove cardinality. Actual refresh timestamp/freshness still pending Owner check at this checkpoint. Raw trace/export deleted; retained `.artifacts/perf/F-01601-codex-formal-hotspots.json` contains only sanitized symbol/weight/thread/timing facts.

No performance-driven source fix required. Only the already verified exact-version allowlist product edit in this continuation.

### Real verification-refresh checkpoint

Owner explicitly reported refresh PASS after supported-provider E/F: update time advanced, Week remained fresh, 5h notApplicable, Source/CLI Codex App Server / 0.160.1, Claude unavailable. Native AX independently observed Source/CLI/notApplicable and an update later than E start +260s; latest parsed update age was approximately 42s. AX diffs can omit unchanged labels; absence in a diff is not interpreted as a state change. No raw timestamp or quota number retained.

5h classification remains the unchanged exact machine-readable plan mapping; personal-pro normalization is derived from the real Live notApplicable state and unchanged parser, not Owner input or a plan-name UI heuristic. No extra account/read. Natural account/rateLimits/updated remains NOT_OBSERVED / not method-instrumented in MacSoul; timestamp advancement alone does not distinguish verification response from notification. Stable one child throughout the full supported E/F session observed; exact native collector/RPC counters not instrumented.

## Real Sleep/Wake Owner Acceptance

Pre-Live-sleep checkpoint: Owner instructed to keep Live and manually use macOS Sleep/Wake. One App PID 47535 and one owned Codex child PID 48279 before sleep. At this checkpoint real Live sleep/wake and Preview sleep/wake still pending; no pmset/system-sleep automation or guess about suspension internals.

### Live real Sleep/Wake — Owner PASS

2026-10-07 Asia/Shanghai: Owner explicitly confirmed Live sleep/wake PASS, System/Network/AI restored Live, Dev normal, Cleaner did not auto-scan. Read-only post-wake identity: same sole Release App PID 47535; one owned Codex child now PID 73907 versus pre-sleep PID 48279. Previous PID is absent. No raw quota/reset/account data retained; no guess about execution during sleep. Preview physical sleep/wake remains NOT_RUN at this checkpoint; all D5-03–06 stay verifying until its acceptance and final gates.

### Final verification preparation — Preview pending

2026-10-07: STATUS generator now reads recorded Live/Preview physical sleep results instead of always printing NOT_RUN. This changes verification-input fingerprint to `4dfba4747551acb7ddcc3bcc1ce056bea10604dce727f6edcb1718201326dfdd`; product/test/project bytes remain those of supported E/F measurement fingerprint `2f2f614d778c95c262b279fb57e21acbeac6c8e88347c030f9fd185dfec31301`. No performance measurement rerun claimed. Build/test PASS (350/0); full verify doctor/build/unit/progress/visual PASS, initial ledger FAIL solely from stale fingerprints, failure logs/manifest retained locally. Refreshed 53 actually passing automated evidence records and preserved previous entries in evidence_history. Live/Preview task closeout still awaits Preview physical sleep/wake.

Preview-pending checkpoint full `./scripts/verify.sh` exit 0; all doctor/build/unit/progress/visual/ledger checks PASS, manifest 2026-10-07T04:51:03.391881+00:00. `test_progress.py`, `verify_progress.py`, STATUS generation and `git diff --check` exit 0. D5-03–06 remain verifying; this passing automated checkpoint does not replace the missing Owner Preview sleep/wake acceptance. No staging/commit/push/PR.

### Preview real Sleep/Wake — Owner PASS

2026-10-07: Owner explicitly confirmed Preview ready, then Preview sleep/wake PASS against requested System/Network/AI Mock, Dev normal and no Cleaner automatic scan checklist. Read-only before/after checks found the same sole Release App PID 47535, owned Codex count 0 both times; previous Live child PID 73907 absent before Preview sleep. Owner UI observation and native process identity are independent evidence; no packet capture or direct observation during physical sleep. No `pmset sleepnow` or automated system sleep, no extra capability read, no new Cleaner scan. Sanitized local record: `.artifacts/perf/real-sleep-wake-owner-01601.json`.

## Final Day 5 Closeout

D5-03 / D5-04 / D5-05 / D5-06 → done based on automated cadence/lifecycle/integration tests, Owner five window cycles, actual supported-provider E/F performance and profiles, >260s real refresh, and Owner Live + Preview physical sleep/wake. Original day/points/dependencies/acceptance definitions and earlier NOT_RUN/verifying/pre-0.160.1 checkpoints retained. D5-01/02 and all other task statuses unchanged; Day 6/7 not started. Final owner review remains pending; no commit/push/PR.

Exact accepted CLI versions remain {0.160.0, 0.160.1}; independently compared protocol files and exactly-one-read capability observation PASS. No mapping/cadence/endpoint/plan redesign. Performance requires no additional fix. Supported E/F measurement verification-input fingerprint `2f2f614d778c95c262b279fb57e21acbeac6c8e88347c030f9fd185dfec31301` retained; final fingerprint `4dfba4747551acb7ddcc3bcc1ce056bea10604dce727f6edcb1718201326dfdd` differs only in the record-driven STATUS generator, not product/test/project bytes. This is not a new behavior or performance measurement checkpoint. Final build/test/verify/progress/Release/privacy results will be appended after execution.

Remaining: Energy Log NOT_RUN (template unavailable); current uncommitted Xcode 26.6 CI NOT_RUN; App Store Connect privacy validation NOT_RUN; Claude subscription live quota NOT_RUN; natural account/rateLimits/updated and real 95% quota event NOT_OBSERVED; Memory Pressure real Critical NOT_OBSERVED. No active network-disruption/resource/battery/quota stress test. No signing/notarization/release, Day 6/7 work, system proxy/VPN/DNS/route mutation or Cleaner cleanup. Finite samples do not prove indefinite leak freedom, exact RPC/collector counts, or absence of short-lived helpers between 2s samples.

### Final executed gates / scope audit

2026-10-07: `./scripts/build.sh` exit 0; `./scripts/test.sh` exit 0, 350 tests / 0 failures; `python3 scripts/test_progress.py` exit 0 (positive + six negative cases); `python3 scripts/verify_progress.py` exit 0 (59 tasks / original 76 points); `./scripts/verify.sh` exit 0, doctor/build/unit/progress/visual_assets/ledger all PASS. Final manifest UTC 2026-10-07T04:55:22.980653+00:00; fingerprint `4dfba4747551acb7ddcc3bcc1ce056bea10604dce727f6edcb1718201326dfdd`. `git diff --check` exit 0.

Fresh independent unsigned Release build via `xcodebuild -project MacSoul.xcodeproj -scheme MacSoul -configuration Release -destination platform=macOS -derivedDataPath .artifacts/perf/FinalDerivedData CODE_SIGNING_ALLOWED=NO build` exit 0. Build log `.artifacts/perf/final-closeout/release-build.log`; packaged privacy equals source byte-for-byte, exact DiskSpace / 85F4.1, UserDefaults / CA92.1, SystemBootTime / 35F9.1 only. Inherited traditional-headermap warning remains; not a failure, no deployment/project changes made to conceal it. Final build does not overwrite or restart the running accepted Release.

Baseline snapshot audit PASS: baseline object, original/planned days, points, dependencies, acceptance definitions and unrelated task statuses unchanged. Product quota parser/mapping, transport, Claude, Network sources, Docker adapter/discovery/Preview and privacy byte-identical to base. Diff scope consists only approved sampling/window lifecycle/teardown/generation safeguards, exact CLI allowlist, associated tests and ledger/status/report. No new provider endpoint, account read/profile persistence, cleanup, Performance feature, Day 6/7 work or publication.

Working tree `feature/performance-hardening`, HEAD/base `fbefa971e38eab780e1d6ac63244c41fdaa6d77c`: 15 modified tracked files plus one new report (16 total), staged files 0. Large task diff retains evidence_history across true passing checkpoints; no historical evidence rewritten. Final local check record `.artifacts/perf/final-closeout/final-checks.json`; raw performance data remains ignored. Accepted Release PID 47535 remains running in Owner-selected Preview; owned Codex count 0 after Preview wake. No commit/push/PR; stop for Owner final review.

## Final Owner review / code-review handoff

2026-10-07: Owner final review PASS, authorizing one cohesive `perf: harden lifecycle and adaptive sampling` commit, normal feature branch push and PR against main. Code review remains separate; no merge or Day 6 work authorized. Exact scope audit: 15 modified tracked files plus this report, no artifacts/raw traces/screenshots/personal files. Secret-pattern scan has no findings; manual report review confirms no Owner quota percentage/reset/raw account/plan payload or raw environment retained. Earlier Instruments exposure incident remains recorded, not relabeled as a clean privacy PASS; Owner should rotate the previously exposed credential if still valid.

Static contract review confirms exact Codex {0.160.0, 0.160.1} gate, future/nil/malformed rejection tests, unchanged parser/mapping/plan/remaining/240s/reconnect/Claude/Network provider behavior; main window presence excludes MenuBarExtra, menu-only CPU/memory 10s / processes 30s / ports 60s, relevant page faster tiers, sole shared collectors, stop-before-restart lifecycle and Cleaner on-demand/no-wake-auto-scan boundary. This handoff does not rerun performance or alter product source. Final verification is rerun below before staging.

Handoff verification executed 2026-10-07: build/test/test_progress/verify_progress/verify/diff all exit 0; 350 tests / 0 failures, all verification manifest checks PASS, timestamp 2026-10-07T05:00:53.732837+00:00, unchanged source fingerprint `4dfba4747551acb7ddcc3bcc1ce056bea10604dce727f6edcb1718201326dfdd`. Previously rebuilt unsigned Release and packaged PrivacyInfo remain current for unchanged product bytes. A–F not rerun. Protect main currently requires exact `macos` from integration 15368 and strict policy; PR handoff does not bypass rules.
