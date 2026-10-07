# Day 6 — Review / Accessibility / Release Hardening

## Scope

Branch `feature/day6-hardening`; base `4984b68e5cdf46bffe0af2c99f047e300992806b`. D6-01–07 only; no commit/push/PR, Day 7, signing, cleanup or new provider. First reviewer pass completed before product edits. Prior acceptance and task baseline preserved.

## Reviewer Method

Single-agent read-only review of AppStore, SensorHub, DevMonitor, NetworkMonitor/providers, AIQuotaMonitor/provider/transport, ShellRunner, Cleaner discovery/scanner/preview, Docker/Maven, MainWindowPresence, termination delegate, views, tests and progress protocol. Followed ownership, generation, cancellation, boundaries and presentation, rather than inferring runtime proof from code. Day 5 historical checkpoints remain intact. Test-only inherited-pipe reproduction compiled in ignored `.artifacts/day6`; no user process targeted.

## Architecture Findings

Shared AppStore value snapshots remain the sole UI source. MainActor monitors own scheduling, actors own native/IO work. Views only dispatch explicit actions/policy. Separate Network/AI lifecycle; Cleaner stays on demand. No database/raw quota persistence. Existing sampling policies retained.

## Privacy Findings

Tracked credential/private-key scan found no secret literals. Email-pattern candidates are asset `@2x.png` filenames, documentation images and synthetic redaction fixtures, not Owner addresses. No tracked raw trace or `.artifacts` file. Environment maps are transient provider inputs, not logged. Prior Day 5 Instruments incident remains historical; this round neither captures raw trace nor exposes its values. No credential store/browser/session reads. Source manifest has exactly DiskSpace/85F4.1, UserDefaults/CA92.1, SystemBootTime/35F9.1. Final unsigned Release source/packaged bytes compared identical, exactly the three approved reasons; no manifest edit.

## Concurrency / Lifecycle Findings

| ID | Severity | Area / file-symbol | Finding / impact | Evidence | Recommended fix / test | Status |
|---|---|---|---|---|---|---|
| D6-H1 | HIGH | ShellRunner.ShellExecution / CodexPipeSession.close | Blocking pipe reads plus unconditional readers.wait can outlive timeout/close when descendant inherits pipe; termination delegate awaits these tasks | Ignored C fork fixture: direct parent exits, descendant holds pipe 3s; ShellRunner timeout 1s returned at 3.005s. Codex uses same unbounded drain/wait pattern | Cancellable bounded-chunk pipe reads; no descendant kills. Regression for timeout, cancellation, transport close with held pipes | FIXED |

Generation rejection, prior-generation teardown serialization, observer removal, display-only clock, idempotent stop/wake and multiple-window visibility reviewed against existing integration tests. No additional evidenced CRITICAL/HIGH.

## Performance Findings

Day 5 A–F and supported-provider E/F results preserved. System 1/5/10s, processes 3/15/30s, ports 10/60s, runtime 300s cache, Codex event+240s, Cleaner explicit scan, Network deadlines/backoff. No actionable hidden fast polling found. Current30-minute sustained result recorded below; old5-minute run is not substituted.

## Test Findings

350 baseline tests cover lifecycle, injected clocks, malformed/failure states, read-only containment, RPC allowlist, remaining quota and cadence. Real child timeout tests use bounded short wall-clock waits because OS pipes cannot be proven by fake clocks. UI exact-copy tests enforce deliberate semantics. Progress verifier checks fingerprints and commands but relies on human report evidence for manual/performance; does not independently attest owner identity. No tests deleted.

## Finding Severity Summary

First-pass counts: CRITICAL 0; HIGH 1; MEDIUM 3; LOW 1; INFO 1. Post-fix OPEN CRITICAL 0 / HIGH 0. Five actionable findings fixed; INFO motion item deferred as no actionable motion exists, not an unresolved defect.

| ID | Severity | File / symbol | Finding / impact / evidence | Fix / test | Status |
|---|---|---|---|---|---|
| D6-M1 | MEDIUM | MetricTile / QuotaWindowView ProgressView | Progress has value but lacks metric/window name; adjacent text can be repeated by assistive technology | Group read-only label/value, remaining semantics; helper tests; VoiceOver manual | FIXED |
| D6-M2 | MEDIUM | PortTable / CleanerPreviewTable | Native Table has no selection binding; keyboard selection not provided | Native selection binding; keyboard owner checklist | FIXED |
| D6-M3 | MEDIUM | README zh/en | Current text says accepted Disk/Network/Dev/AI/Cleaner are not implemented and formal performance not run | Update truthful current scope, privacy, bounded performance; link check | FIXED |
| D6-L1 | LOW | SettingsView capabilities | Live says Partial Live + Mock despite honest unavailable providers; HTTPS probe text lacks HEAD | Local wording polish, no behavior changes | FIXED |
| D6-I1 | INFO | Views / SoulArtwork | No actual animation or continuous motion found; decorative Soul already hidden | No motion subsystem added; system toggle manual NOT_RUN | DEFERRED |

## Critical / High Fixes

D6-H1 fixed with cancellation-pipe wakeup: stdout/stderr readers block on native poll(input,cancel), not timer polling. Stop wakes both readers; owner joins before closing handles. Same helper used by ShellRunner and Codex transport. No descendants are killed. C reproduction after patch: configured1s timeout returns~1.100s instead of~3.005s. Three real test-owned pipe regressions cover timeout/cancel/Codex close; existing literal arguments, output bounds, cancellation races and native handshake tests retained.

363 tests /0 failures after patch and test cleanup. D6-M1/M2 and L1 are local low-risk fixes; M3 is authorized README scope. No new actor/provider architecture.

## Accessibility

Inventory: sidebar native List/Label; Soul static artwork hidden and adjacent mood/message informative; metrics/quota M1; Network labeled rows/status strings; Dev actions labeled/help and clipboard-only; Cleaner native actions plus directory button, M2 table selection; Settings native Picker/Switch; MenuBar native buttons, shared metric/quota components; badges/stale/error text do not rely solely on color. Scan/Preview spinners have named state. Read-only metric/window groups ignore duplicate children and expose localized name plus value/status; quota voices remaining, including stale/near-limit. The safe Developer Preview AX tree actually returned localized metric name/value and remaining-window descriptions (fixture data only). This checks AX attributes, not VoiceOver speech. Manual assistive behavior not inferred from source.

## Reduce Motion

No actionable motion finding. No `.animation`, `withAnimation`, repeating transition, timer-driven transform or animated assets in production. Static Soul preserves state. System Reduce Motion ON/OFF manual NOT_RUN; no global setting mutation.

## Keyboard

Native buttons/pickers/sidebar retained. Native selection bindings added to shared Port Table and Cleaner Preview Table. Native Settings scene supplies system Cmd+, without overriding Cmd+Q. Owner: Tab/Shift-Tab, Space/Return, sidebar navigation, Picker, tables, Scan/Cancel/View contents/Back/Refresh/Copy/Finder/MenuBar. No destructive action.

## Failure-State Matrix

AUTOMATED fixture/injection matrix PASS in current 363-test run; this is not real outage UI acceptance.

| Module | Covered failures / test evidence |
|---|---|
| System | CPU first/invalid, memory invalid, pressure unknown, disk unavailable, no battery: SystemSoulTests / SystemDetailsTests; shared failure snapshot in AIQuotaLifecycleTests |
| Dev | runtime missing/malformed/version context, lsof empty/failure/timeout: DevEnvironmentTests |
| Network | unsatisfied/requiresConnection/unknown/unavailable path, IPv4/IPv6 independent failures, probe timeout/OFF, malformed proxy/local facts unavailable: NetworkTests |
| AI | unsupported/missing executable, handshake timeout/failure, malformed JSON/rate-limit, reconnect/stale, Claude absent/no source: AIQuotaTests / AIQuotaLifecycleTests / QuotaTests |
| Cleaner | notRun, missing/inaccessible/partial/cancelled, Docker unavailable/remote context and boundary failures: CleanerTests / CleanerDiscoveryTests / MavenCleanerTests / CleanerPreviewTests |

Shared Snapshot failure test keeps unknown distinct from healthy and provider unavailable distinct from Mock. Numeric quota value is absent for unavailable, stale retains its value and source time, malformed input does not clamp into valid quota. Docker missing remains unknown size, not zero. No real Wi-Fi/VPN/proxy/DNS/route changes or intentional resource stress.

## Launch at Login

Native SMAppService adapter implemented with seven injected tests: mapping, read-only init/refresh, explicit mutation, idempotence, approval, errors and unavailable/external updates. [Apple API reference](https://developer.apple.com/documentation/servicemanagement/smappservice). No real register/unregister executed. OWNER NOT_RUN. System status source of truth, not UserDefaults.

## Settings Polish

Live capability copy now says availability per source, Cleaner read-only/on-demand, anonymous HTTPS HEAD and ipify disclosures. Native login section follows actual enabled/disabled/requiresApproval/unavailable with generic operation error and explicit refresh. No appearance redesign.

## Sustained Performance Method

Current unsigned Release with supported Codex 0.160.1 active, Owner-confirmed Live, no main windows/popover, Cleaner idle; warm-up20s, interval5s, actual30min run completed. Machine Mac14,9 /12 logical CPUs /16GiB; macOS27.0.1 (26A434), Xcode27.0 (27A266a), deployment13 unchanged. Native proc_pid_rusage, one logical CPU=100%, decimal MB. PID/PPID/executable basename only; no argv/environment/owner quota payload.

## Sustained Performance Results

First reviewer checkpoint: NOT_RUN, retained above. Final real observation completed on 2026-10-07 UTC, 1800.044s after20s warm-up, 358 samples at approximately5s, no debugger/Instruments. Owner confirmed supported Live menu-bar-only setup. Raw sanitized CPU/RSS/PID/counts: `.artifacts/day6/sustained-live-menu.json`; context/identity: `.artifacts/day6/measurement-context.json`, `.artifacts/day6/release-identity.json`.

| Process | Avg CPU | p95 interval CPU | Max interval CPU | RSS start → end MB | Avg RSS MB | Max RSS MB | Threads start → end |
|---|---:|---:|---:|---:|---:|---:|---:|
| MacSoul | 0.026535% | 0.097671% | 0.287339% | 118.948 → 97.452 | 101.987 | 118.948 | 10 → 8 |
| owned Codex | 0.000420% | 0.001658% | 0.013950% | 50.758 → 46.432 | 44.685 | 54.985 | 26 → 21 |

Parent CPU target <0.5%: PASS. Parent RSS target <100MB: REVIEW, not PASS (average101.987MB, maximum118.948MB); below150MB review budget. First/middle/final-third RSS means107.559/101.312/97.131MB decrease; no obvious sustained growth observed in this finite run. Start/end decrease alone is not a leak proof. No >150MB interval or CPU spike beyond0.2874%; no additional sensitive profiler capture warranted. Owner may review the100–150MB budget result; no product change made to manufacture <100MB.

Codex min/max count1/1 across all358 samples; exactly one observed PID54955, parent53989 stable, no replacement observed, no owned helper at sample points. Codex RSS third means45.338/47.364/41.382MB fluctuate without sustained upward growth; threads26→21, parent10→8. These sampled observations cannot exclude processes shorter than the5s sampling interval, and do not prove leaks impossible. Codex has no parent-only100MB target. No physical sleep/reconnect scenario deliberately introduced during the run.


## README / Documentation Draft

Bilingual README updated incrementally, retaining brand/concept/License. Current core scope, Preview/Live, remaining quota, verified versions, read-only Cleaner, explicit external requests, source build, finite measured performance and limitations. 41 local links/image paths in README zh/en + DEVELOPMENT checked; zero missing. Architecture appended current boundary without rewriting historical checkpoints. Generated STATUS report selector minimally extended to current D6 ledger/report rather than stale D5 text; no validation semantics changed. This verification-input-only edit changes the final source fingerprint after launch; measured product bytes remain identical to the built Release.

## Screenshot Draft / Checklist

SCREENSHOT_PENDING. Developer Preview only, obvious Mock badge, no real IP/quota/reset/path/proxy/account. Checklist: Overview, System, Network, AI, Dev, Cleaner, Settings, MenuBar. Local drafts only; no GIF/marketing regeneration. Native channel initially returned safe Preview AX tree; metrics had localized name/value, quotas said remaining. The subsequent screenshot/shortcut call failed: native pipe closed before response. No screenshot was fabricated; no Live capture persisted. Remaining screenshot checklist is pending.

## Privacy Recheck

Source/diff boundary scan found termination only in owned ShellRunner/Codex and normal App Quit, Dev command is clipboard-only. No product destructive calls, credential reads or payload logging. Source/Release manifest byte-identical, exact approved reasons. New login API adds no new required-reason declaration. Raw trace remains untracked. Final source/packaged/launched manifest and executable identity check PASS; no manifest mutation.

## Owner Manual Acceptance

Owner authorized normal SIGTERM of old MacSoul PID47535; it exited normally. New unsigned Release copied to visible build-preview/MacSoul.Day6.8gvorwfw/MacSoul.app, App PID53989. Owner confirmed Live menu-bar-only setup, supported Codex source/0.160.1 with numeric Week (no real numeric/reset recorded), windows/popover closed and Cleaner idle. This is measurement setup confirmation only.

VoiceOver / keyboard / Reduce Motion / real Login Item NOT_RUN. Prior Day 2–5 owner evidence preserved; not silently upgraded by unit tests. Login item Owner may manually toggle on/off and verify System Settings; agent must not do so.

## NOT_RUN / NOT_OBSERVED

Current Xcode26.6 CI NOT_RUN; App Store Connect privacy validation NOT_RUN; real pressure critical / 95%-quota event / updated notification NOT_OBSERVED historically. Real outage/resource stress NOT_RUN. Day7 release/sign/notarization not performed.

## Final Verification

Initial final-source verify checkpoint: doctor/build/unit/progress/visual PASS, ledger FAIL solely because previous done-task automatic evidence carried the pre-Day6 fingerprint. The failed result is retained in `.artifacts/day6/verify-first.log`; no task status was downgraded or evidence requirement removed. Current-source automatic command evidence was refreshed after actual PASS; previous entries archived in evidence_history. Earlier Owner observation/profile entries are retained in evidence_history; current entries explicitly record a scope review against accepted baseline, with prior_evidence_fingerprint and prior report references. They are not new Owner tests/profiles. The 21 unchanged core/manifest byte comparisons and full existing integration suite support carry-forward, while new UI remains Owner NOT_RUN. Current sustained30-minute measurement recorded separately above, parent CPU PASS/RSS REVIEW.

Debug build/test PASS, 363 tests /0 failures, local Xcode27.0/27A266a macOS27.0.1/26A434. Release build exit0, packaged privacy comparison PASS. Local progress tests PASS; explicit ledger check after truthful evidence refresh PASS. Verification-input refresh checkpoint in `.artifacts/day6/verify-refresh.log`: all actual automatic checks PASS, ledger FAIL only stale previous fingerprint; explicit errors retained in `.artifacts/day6/ledger-refresh-failure.log`. Automatic evidence and scope-review entries refreshed from actual command results, old entries retained. Final `./scripts/verify.sh` exit0 with doctor/build/unit/progress_tests/visual_assets/ledger all PASS (`.artifacts/day6/verify-final.log`, `.artifacts/verification.json`). Explicit `python3 scripts/test_progress.py`, `python3 scripts/verify_progress.py` and `git diff --check` exit0. Final unsigned Release command exit0 (`.artifacts/day6/release-final.log`), source/packaged privacy byte-identical. 363 tests /0 failures; no test removed. Current Xcode26.6 CI NOT_RUN.

## Task State

D6-01–07 verifying; Owner final review required before done. D6-06 has actual30-minute observation; RSS target remains REVIEW. D6-05 real Login Item remains Owner NOT_RUN. Previous done, points, original days, dependencies, acceptance and historical confirmations unchanged. No staged files.

### Fingerprint scope

Measured product fingerprint at launch: `213ee72b3d113d1e5601dff89bb5f8695588b2f0ee7ac414ae907ac02c24971a`. Final verification fingerprint: `c7d4c49bb2261b7e07f1bac40be02752a692ee1b2a9b2c5502909999f9407dfb`. The only post-launch fingerprint input change is the STATUS generator; product Swift/project bytes are unchanged and running App matches the built Release. Historical Day5 measurement fingerprints remain historical.

### Change inventory / worktree

21 changed/new files; branch `feature/day6-hardening`, HEAD remains base `4984b68e5cdf46bffe0af2c99f047e300992806b`; worktree intentionally dirty, staged files0. No commit/push/PR. Build-preview/.artifacts remain ignored and App stays running.

- `MacSoul.xcodeproj/project.pbxproj`
- `MacSoul/App/MacSoulApp.swift`
- `MacSoul/Components/AccessibilityPresentation.swift`
- `MacSoul/Components/MetricTile.swift`
- `MacSoul/Components/QuotaRow.swift`
- `MacSoul/Models/CodexQuotaTransport.swift`
- `MacSoul/Models/LoginItem.swift`
- `MacSoul/Models/ShellRunner.swift`
- `MacSoul/Theme/MacSoulTheme.swift`
- `MacSoul/Views/Cleaner/CleanerPreviewView.swift`
- `MacSoul/Views/Cleaner/CleanerView.swift`
- `MacSoul/Views/Dev/DevView.swift`
- `MacSoul/Views/Settings/SettingsView.swift`
- `MacSoulTests/Day6HardeningTests.swift`
- `README.en.md`
- `README.md`
- `docs/ARCHITECTURE.md`
- `docs/STATUS.md`
- `reports/day-6-review-hardening-2026-10-07.md`
- `scripts/generate_status.py`
- `tasks.json`

### Owner acceptance checklist (NOT_RUN)

- VoiceOver: Overview/System metric name plus value; AI remaining plus stale/unavailable; Cleaner/Settings/Menu Bar meaningful labels without duplicate decorative artwork.
- Keyboard: Tab/Shift-Tab traversal; Space/Return actions; sidebar and Picker; native Port/Preview table selection; Scan/Cancel/View contents/Back/Refresh/Copy/Finder/Menu Bar. Cmd+, opens Settings and Cmd+Q stays native.
- Reduce Motion: Owner-only system ON/OFF, static Soul/state feedback retained; no agent mutation.
- Login Item: Owner-only switch enable/disable, check macOS system status, requiresApproval/error honesty. Real register/unregister NOT_RUN.
- Preview screenshot drafts: Overview/System/Network/AI/Dev/Cleaner/Settings/Menu Bar, Mock badge, no real IP/quota/reset/path/proxy/account; SCREENSHOT_PENDING.
- Parent RSS100–150MB review-budget result remains for Owner review; not a <100MB PASS claim.

## Final Owner Acceptance — 2026-10-07

Owner explicitly approved formal Day6 closeout on the unchanged product reviewed above. Earlier NOT_RUN/verifying checkpoints, previous automatic evidence and measured fingerprints remain historical; this section is the current acceptance boundary.

### Accessibility / keyboard / Reduce Motion

- VoiceOver PASS: Owner used real VoiceOver navigation to access Overview/System read-only metrics, metric name/value and AI quota remaining semantics. Read-only metrics need not be ordinary Tab stops.
- Keyboard PASS: Owner confirmed Sidebar navigation, Tab/Shift-Tab primary paths, native controls/table semantics, preserved system Cmd+Q and clipboard-only stop command. Read-only metrics need not be ordinary Tab stops.
- Reduce Motion PASS: Owner verified App/static Soul state expression under the real system Reduce Motion setting, with no abnormal animation.
- This is scoped Owner acceptance, not an exhaustive control inventory test or a full VoiceOver speech transcript. Agent did not change global Accessibility settings.

### Launch at Login approved boundary

Implementation acceptance PASS: native SMAppService, authoritative system status, enabled/disabled/requiresApproval/error mapping, fake tests and honest unavailable UI accepted. Owner observed Launch at Login unavailable in the unsigned Release/build-preview; it is an honest failure-state rather than a product failure. Real register/unregister remains OWNER NOT_RUN, explicitly deferred to Day7 installed/signed release-shaped build. No agent registration, system Login Item change, UserDefaults substitution or SMAppService bypass.

### Screenshot approved boundary

Day6 draft/checklist ACCEPTED: bilingual README and Preview-safe checklist complete; native capture pipe failure retained; no fabricated or sensitive Live screenshots. Final public screenshots/GIF PENDING, deferred to D7-07. Prefer obvious Mock Developer Preview; exclude real public IP/quota/reset timestamp/local paths/accounts/proxy secrets/token/session data. No image/GIF generated during closeout.

### Sustained performance approved boundary

Owner ACCEPTED the existing30-minute run, without remeasurement. CPU PASS: average0.026535%, p950.097671%, maximum0.287339%. RSS REVIEW ACCEPTED: start118.948MB, end97.452MB, average101.987MB, maximum118.948MB. This remains the100–150MB REVIEW band, not RSS<100MB PASS. No obvious sustained growth observed; a finite run does not prove absence of leaks. Owner accepts the current Day6 budget. Exactly one Codex child across sustained samples; observed CPU/RSS stability accepted for current scope. Original raw measurements and measurement_fingerprint unchanged.

### Current remaining limitations

| Item | Current status |
|---|---|
| Real Login Item register/unregister | OWNER NOT_RUN; deferred Day7 installed/signed environment |
| Final public screenshots/GIF | PENDING; D7-07 |
| Energy Log | NOT_RUN; template unavailable |
| App Store Connect validation | NOT_RUN |
| Claude real subscription quota | NOT_RUN |
| Natural account/rateLimits/updated notification | NOT_OBSERVED |
| Real95% quota event | NOT_OBSERVED |
| Memory Pressure Critical | NOT_OBSERVED |
| Active network/resource disruption/stress | NOT_RUN |
| Current Xcode26.6 CI | NOT_RUN; no commit/push this round |

These do not block the Owner-approved Day6 boundary. Day7 implementation/signing/notarization/packaging has not started. Cleanup/Trash/Notch/new providers remain outside scope.

### Task closeout / verification checkpoint

D6-01–07 done by explicit Owner approval. Day7 tasks remain todo. Original points/days/dependencies/acceptance definitions and prior Owner confirmations preserved. Closeout edits are documentation/ledger/STATUS wording only; no new product behavior or performance evidence claimed. Final automatic verification follows; source/test/project hash comparisons bind this boundary to the accepted product.

### Closeout evidence refresh

Verification-input fingerprint: `75cc53eb7dc7f7dc4b3313b8ae44a66d71bcd2407fe077624a4c668d1ca579b1` (prior accepted worktree verification fingerprint `c7d4c49bb2261b7e07f1bac40be02752a692ee1b2a9b2c5502909999f9407dfb`). The only source-fingerprint input edit is STATUS generator wording. All95 product/test/project files byte-identical to pre-closeout, privacy manifest unchanged. Original measurement fingerprint `213ee72b3d113d1e5601dff89bb5f8695588b2f0ee7ac414ae907ac02c24971a` and measurement files preserved; no new performance or product behavior evidence. Context: `.artifacts/day6/owner-closeout-context.json`.

Closeout refresh checkpoint: doctor/build/unit/progress_tests/visual_assets PASS; ledger initially refused stale previous fingerprint (verify exit1). Failed result/errors retained in `.artifacts/day6/owner-closeout-verify-refresh.log` and `.artifacts/day6/owner-closeout-ledger-refresh-failure.log`. Existing automatic evidence refreshed only from actual PASS command results; previous entries retained in evidence_history. Current non-automatic entries explicitly describe unchanged-scope review, not new measurement/Owner runs. Owner acceptance entries are separate and preserve RSS REVIEW, real Login Item NOT_RUN, final screenshots PENDING. Final verify follows.

### Final closeout automatic verification

`./scripts/build.sh`, `./scripts/test.sh`, `python3 scripts/test_progress.py`, `python3 scripts/verify_progress.py`, `./scripts/verify.sh`, `git diff --check`: exit0/PASS. Final363 tests /0 failures; no tests added/removed for closeout. Verify doctor/build/unit/progress_tests/visual_assets/ledger all PASS (`.artifacts/day6/owner-closeout-verify-final.log`, `.artifacts/verification.json`); progress verifier59tasks/original76points. Source fingerprint `75cc53eb7dc7f7dc4b3313b8ae44a66d71bcd2407fe077624a4c668d1ca579b1`. Existing unsigned Release privacy manifest is still byte-identical to source with exactly DiskSpace85F4.1/UserDefaultsCA92.1/SystemBootTime35F9.1; no new Release/performance/signing/packaging claims.

Closeout edited only `tasks.json`, this report, generated `docs/STATUS.md`, `scripts/generate_status.py` wording, and existing README zh/en/architecture closeout wording. Product/test/project file set and95 hashes unchanged.41 current local links/image paths PASS. Total branch worktree remains21 modified/new Day6 files, including earlier accepted implementation; staged0. HEAD remains `4984b68e5cdf46bffe0af2c99f047e300992806b`, branch `feature/day6-hardening`, no commit/push/PR. Day7 not started.
