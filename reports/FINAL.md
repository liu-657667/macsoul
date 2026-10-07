# MacSoul v0.1.0 — Final Report

## Current authoritative checkpoint — Owner scoped final review completed

Recorded 2026-10-07T10:43:18.034361+00:00. **Local unsigned System-layout Archive-derived v0.1.0 / build1 RC ACCEPTED by Owner. Owner Live regression PASS; Preview smoke PASS; CPU PASS; RSS REVIEW ACCEPTED; Package privacy PASS.** This is local RC acceptance, not public release or GitHub CI acceptance.

- Executable SHA256: `7224f208d58b45612c3482b24ee7ec637c4f6c725fb0cde4a49fc4aabac60200`
- Zip SHA256: `6b541098d2cddcab546fecad4d5a48b09e1c837892ea0af68a912ff634e3f177`; **6,062,427 bytes**.
- Source fingerprint: `1c60e81ec22795ba49bac7877309e57f534e2bc1d21911dcddef9adb171fb067` (unchanged).
- Archive: `.artifacts/day7/system-layout/MacSoul.xcarchive`; visible byte-identical App: `build-preview/MacSoul.Day7.SystemLayout.bos7qpyh/MacSoul.app`; zip: `.artifacts/day7/system-layout/release/MacSoul-v0.1.0-unsigned.zip`.
- **365 tests / 0 failures / 0 skips** come from previously completed current-source verification, not a run in this documentation-only closeout. Strip1, arm64/x86_64 zero owner-prefixes, private matching dSYM and independent extraction remain accepted recorded evidence; no rebuild/package/measurement rerun.

### Accepted finite performance review

**RSS REVIEW ACCEPTED by Owner for this finite v0.1.0 RC observation.** CPU avg / p95 / max: **0.012488% / 0.039502% / 0.063822%**. RSS start / end / avg / max: **100.483 / 79.479 / 88.107 / 100.483 decimal MB**. RSS first / middle / final-third means: **93.502 / 89.300 / 81.833 MB**.

Owner accepts the average CPU below0.5%, RSS start/peak slightly above100MB but average/end below100MB, all RSS observations below150MB, no obvious sustained RSS/thread growth in this finite run, exactly1 owned Codex child with stable PID, and no further-investigation trigger. The **100MB target and150MB investigation threshold remain unchanged**. Raw measurement verdict remains **RSS REVIEW**; this acceptance is neither `<100MB target PASS` nor proof of no memory leak. Separate child/footprint/thread data and original measurement records below are retained unchanged. No Time Profiler, stress test or rerun added.

### Actual D7 ledger decisions

All eight original criteria and their D6-01 dependency (done) were assessed separately. No acceptance/points/dependencies were edited; no prior completed task status was changed. D7 adds10 accepted original points; original plan **76/76 points** within its approved scope, with incremental tasks retaining their existing states. D7-03 task acceptance closes on explicit Owner review acceptance, not an altered RSS threshold verdict.

| Task | Final status | Basis | Remaining original required gap |
|---|---|---|---|
| D7-01 | done | Independent Day7 clean build PASS retained; current-source automatic verification 365 tests / 0 failures / 0 skips and Release Archive PASS; Owner accepts recorded verification. No build/test rerun this unit. | None within approved local RC scope. |
| D7-02 | done | Current final Owner Live regression PASS; Preview smoke and normal Quit/reopen PASS; unchanged earlier Soul/Cleaner read-only acceptance retained. | None within approved local RC scope. |
| D7-03 | done | Valid existing 300.051-second native Live measurement; CPU PASS; measured RSS REVIEW, explicitly REVIEW ACCEPTED by Owner for this finite v0.1.0 RC observation. Targets unchanged. | None within approved local RC scope. |
| D7-04 | done | Current final Archive executable/resources/zip privacy PASS; Strip1, both executable slices owner-prefix0; sanitized log review and independent extraction PASS; Owner accepts. | None within approved local RC scope. |
| D7-05 | done | Version0.1.0/build1, LICENSE/ThirdPartyNotices, CHANGELOG and CONTRIBUTING present and reviewed; Owner accepts recorded automatic/document checks. | None within approved local RC scope. |
| D7-06 | done | Reproducible Archive-derived unsigned zip/checksum/independent extraction PASS and complete owner-ready signing/notarization PLAN available in docs/RELEASE.md. Actual signing/notarization NOT_RUN; original criterion explicitly permits plan path. | None within approved local RC scope. |
| D7-07 | done | Actual sanitized Preview screenshots integrated in both READMEs and explicitly Owner approved; overall review now completed. GIF optional under prior Owner clarification, NOT_GENERATED; menu icon DRAFT. | None within approved local RC scope. |
| D7-08 | done | FINAL records implemented scope, deferred work, limitations and proposed v0.2 items; current scoped acceptance and historical checkpoints distinguished; Owner final review completed. | None within approved local RC scope. |

**CI boundary:** none of D7-01–D7-08 has GitHub CI as an original mandatory condition for this local unsigned RC. The original Day7 instructions retain Xcode26.6 CI as **NOT_RUN before push**, with a separate Day7 PR run later; local Xcode27 and historical PR#9 CI do not substitute for it. D7-06 explicitly accepts a signing/notarization **plan or completed path**. GIF is optional under prior Owner clarification. No new gate or unexecuted PASS was added.

### Unexecuted, unobserved and deferred scope

- **NOT_RUN:** Day7 GitHub Xcode26.6 CI; signing, notarization, Gatekeeper and public distribution; App Store Connect privacy validation; real Claude subscription quota (honest unavailable); pressure/resource stress, Energy Log and related special/outage validation.
- **Deferred / NOT_RUN:** real signed/installed Login Item registration/unregistration under the prior approved boundary; awaiting a separately authorized signed/installed environment. No registration performed.
- **NOT_OBSERVED:** natural quota update notification; real critical memory pressure; real quota95% event.
- Region **NOT_COLLECTED**; Cleaner deletion **NOT_IMPLEMENTED BY DESIGN**; observed IPv6 transport failure retained; GIF **NOT_GENERATED / optional**; menu icon **DRAFT**.
- v0.2 ideas remain proposals only: separately designed Cleaner cleanup/Trash/confirmation, build tools and Docker extensions. No next-version work starts.

Evidence: `.artifacts/day7/owner-final-closeout/owner-acceptance.json`, existing current-source verification/package/Owner Live/finite measurement artifacts, and the documentation consistency checks recorded after execution. Old reports and raw artifacts are preserved. Historical pending/failed verdicts below are chronological observations superseded only where later explicit evidence resolves them.

STATUS is generated with the unchanged existing script. Its D7 task rows and points reflect this ledger; its fixed D6 Manual UI sentence still mentions historical D7 screenshot/GIF PENDING and its performance pointer still names D6. Those legacy summary strings are not current D7 verdicts; use this checkpoint for the scoped current conclusion. The generator was not edited because it participates in the source fingerprint.

### Documentation-only closeout checks

`python3 scripts/generate_status.py`, `python3 scripts/verify_progress.py`, `python3 scripts/test_progress.py` and `git diff --check`: actual exit0 / PASS in this unit. Progress tests: positive ledger plus six negative cases. Existing local-link audit reused:78 local links,0 missing; linked Markdown fragments checked. Protected-source/package/history comparison:369 files unchanged; all original ledger definitions/points/dependencies/history and all non-D7 task objects unchanged; all earlier report bodies retained with historical heading labels. Raw performance files still contain measured RSS REVIEW and their historical pending-review checkpoint; new Owner acceptance is a separate record.

This round changed only `tasks.json`, generated `docs/STATUS.md`, the two reports and short current-summary wording in `README.md`, `README.en.md`, `docs/RELEASE.md`. Full accumulated Day7 worktree:22 modified/new files; staged0; branch `feature/day7-release-closeout`, HEAD `a0a93a59c1d553a527f75616732fc9b9db90a820` unchanged. Logs/manifests in `.artifacts/day7/owner-final-closeout/`. No Swift test/build/Archive/packaging/performance run here;365tests are prior current-source evidence.

**STOP:** documentation and ledger only; no commit/push/PR/tag/Release/sign/notarize/repackage/additional performance/product changes. Await separate Owner direction for repository integration or publication.

## Historical / Superseded — Current final RC checkpoint — Owner Live PASS, finite performance REVIEW

Owner explicitly reports **Live regression PASS** and **Day7 Live performance ready** for the final System-layout Archive-derived RC. System resizing/scrolling, Network, Dev clipboard-only actions, AI Coding/Overview/Menu Bar shared presentation, Live main/Menu Bar and normal Quit/reopen PASS under the issued checklist. Existing Cleaner read-only scan/lifecycle/idle PASS retained; no rescan, no active scan/traversal in the Owner readiness setup. Mock/Live boundary and honest Claude unavailable retained. This is scoped manual acceptance, not final overall Day7 review or public-release approval.

### Actual native five-minute measurement

Release Archive-derived unsigned -O, no debugger/Instruments, macOS 27.0.1, Mac14,9 / 12 logical CPUs / 16 GiB. Owner confirms windows/settings/popovers closed, Live Codex active, Cleaner idle and no interaction/sleep/mode switch. No UI/provider/account query used to inspect readiness. Actual preheat 20.004s; formal duration 300.051s; 61 sample points, 60 valid CPU intervals per process, no missing samples/timing anomalies. First point is a baseline, not 0% CPU. Per-process native cumulative user+system deltas divided by actual monotonic intervals, duration-weighted mean; one logical CPU100%, no core division. RSS and physical footprint separately reported in **decimal MB**.

| Metric | MacSoul parent | Owned Codex child |
|---|---:|---:|
| PID | 16961 | 17072 |
| CPU avg / p95 / max | 0.012488% / 0.039502% / 0.063822% | 0.000647% / 0.001543% / 0.012119% |
| RSS start / end / avg / max MB | 100.483 / 79.479 / 88.107 / 100.483 | 45.990 / 46.285 / 47.341 / 56.492 |
| Physical footprint start / end / avg / max MB | 51.250 / 52.725 / 52.033 / 52.839 | 39.831 / 37.389 / 37.976 / 40.912 |
| Threads start / end (min–max) | 6 / 7 (6–12) | 26 / 26 (26–28) |
| Valid CPU intervals / coverage seconds | 60 / 300.043 | 60 / 300.042 |

Owned Codex min/max count **1/1 at every sample**, no other owned helpers. Exact executable identity verified with proc_pidpath plus PPID ancestry; parent/child PIDs stable, no replacements, no cross-PID CPU subtraction or missing-interval zero fill. No argv/environment/quota/reset/account/prompt/network/IP/Cleaner path retention. Sanitized artifacts: `.artifacts/day7/final-live-performance.json`, `final-live-performance-context.json`, `final-live-performance-verdict.json`; helper measurement-only/ignored, outside product source.

**Parent CPU PASS** (<0.5% average). **Parent RSS REVIEW**: start/max 100.483 MB slightly exceeds100MB target; average/end below100MB and all observations below150MB review budget. Do not relabel this as unconditional <100MB target PASS. Codex memory reported independently with no parent-only threshold applied. Parent RSS first/middle/final-third means: 93.502 / 89.300 / 81.833 MB; child: 50.012 / 46.214 / 45.871 MB. Parent thread third-means 8.050 / 7.600 / 7.810; child 26.500 / 26.100 / 26.333. No obvious sustained RSS or thread growth observed in this finite5-minute sanity run. Physical footprint is distinct and its values remain explicit. This is **not proof of no memory leak**. No CPU spin, >150MB parent RSS, repeated child or clear sustained RSS/thread growth trigger observed; no added Time Profiler or performance rerun.

### Compatibility, verification and package identity

0.162.0-alpha.2 compatibility PASS from the prior authorized sanitized protocol/parser observation; Owner current Live three-surface acceptance PASS. No new rate-limit/account observation this measurement. Actual final `supportedVersions` set: `0.160.0`, `0.160.1`, `0.162.0-alpha.2`. Historical unknown-version STOP retained. HeldPipe history:3cases×20iterations=60executions/0failures, retained, not rerun. Current-source automatic verification remains **365passed / 0failed / 0skipped**, from `.artifacts/day7/system-layout/verification.json` and `test-summary.json`; build/test/full verify PASS, not rerun for this report-only unit. Source fingerprint **`1c60e81ec22795ba49bac7877309e57f534e2bc1d21911dcddef9adb171fb067`** unchanged.

Current executable SHA256 **`7224f208d58b45612c3482b24ee7ec637c4f6c725fb0cde4a49fc4aabac60200`**. Archive-only zip SHA256 **`6b541098d2cddcab546fecad4d5a48b09e1c837892ea0af68a912ff634e3f177`**, **6,062,427bytes**. Running App file hashes match all7formal Archive files; no rebuild or package overwrite. Release testabilityNO/installed strippingYES/dwarf-with-dsym, no temporary settings overrides, actual Strip1, arm64/x86_64 owner-prefix0, all resource/zip member scans0, private dSYM UUID match and independent extraction equality remain PASS. Exact PrivacyInfo/source bytes and DiskSpace85F4.1/UserDefaultsCA92.1/SystemBootTime35F9.1 plus notices PASS. Owner manual smoke/Live acceptance completes the current scoped **FINAL UNSIGNED RC PACKAGE PRIVACY = PASS**; private dSYM excluded from distributed zip. Prior accepted package and178path failures/false-zero SUPERSEDED/debug-map/testability/temporary-strip checkpoints preserved.

### Ledger, limits and stop

**D7-01 through D7-08 = verifying**, pending Owner overall final review; no automatic done promotion. D7-02 now has actual Owner regression PASS, D7-03 actual measurement with RSS REVIEW; D7-07 screenshot review PASS retained, menu icon DRAFT. Original points/day/dependencies/history and all earlier done statuses unchanged.

NOT_RUN: Day7 GitHub Xcode26.6 CI; signed/installed Login Item registration/unregistration; signing/notarization/Gatekeeper/public distribution/App Store Connect privacy validation; real Claude subscription quota; Energy Log/active outage or resource stress. NOT_OBSERVED:15s natural quota update notification; real critical memory-pressure/quota95% event. Region NOT_COLLECTED; observed IPv6 transport failure retained. Cleanup NOT_IMPLEMENTED BY DESIGN. Overall Day7 Owner final review PENDING. Current finite measurement replaces earlier performance NOT_RUN checkpoints only for this specific RC; historical records remain intact.

Product/source/project/privacy/tests unchanged in this unit. Worktree remains uncommitted, staged0, no commit/push/PR/tag/GitHub Release, signing or notarization. STOP for Owner final review; no next-feature work. Document/ledger/link/fingerprint consistency checks recorded separately below after execution.

## Retained earlier report checkpoints — historical / superseded where noted


## Executive Summary

Day 7 in progress on `feature/day7-release-closeout`, base `a0a93a59c1d553a527f75616732fc9b9db90a820`. Day 2–6 implementations and scoped Owner acceptance are retained. Final Day 7 manual regression and performance sanity are pending. Prior RC unsigned package privacy/smoke PASS is historical; new System-layout RC static privacy PASS, minimum Preview smoke partial awaiting Owner manual checks. Required Preview screenshots passed privacy review and final Owner screenshot review. No public release is claimed.

## Baseline

- Original seven-day plan: 76 original points, preserved in the task ledger; no denominator/acceptance/dependency changes.
- Owner clarifications: applicable quota windows only; remaining is presentation over canonical usedPercent; v0.1 Cleaner read-only; Notch excluded; unknown is not healthy/zero.
- Implemented, verified, Owner accepted and publicly distributed are separate states.

## What Shipped in v0.1.0 Scope

“Shipped” here means implemented source/RC scope, not public distribution. Earlier acceptance is historical, not a substitute for final Day 7 regression.

### System

Shared native whole-system CPU (first delta unknown), memory used/total and pressure events, root-volume disk usage, battery/power notifications and developer process CPU delta/RSS. Adaptive independent cadences. Day 2 Owner acceptance PASS, natural pressure warning observed; critical NOT_OBSERVED.

### Soul

Local deterministic sustained CPU/memory state machine: thresholds, hysteresis, category cooldown, priority/recovery. Suspend clears transient health facts and pending duration while preserving announcement history. Static artwork, no LLM or quota-burning test.

### Network

Shared NWPath, independent IPv4/IPv6, redacted environment/system proxy facts, tunnel hints and optional anonymous HTTPS HEAD probes. Cache, debounce, failure backoff and disabled/checking semantics preserved. Region NOT_COLLECTED. Day 3 accepted; IPv6 transport failure in the observed environment is honest unavailable data.

### Dev Environment

Bounded cancellable literal child commands; Java/Node/Python/Go and SDKMAN/NVM/pyenv/goenv contexts, cache/manual refresh. TCP LISTEN sockets, conservative developer relevance, grouped binds, native Table and clipboard-only port/PID/SIGTERM text. No process termination or conflict claims. Day 3 accepted.

### AI Coding

Exactly verified Codex CLI 0.160.0/0.160.1/0.162.0-alpha.2 App Server, initial read/events plus serialized 240s verification refresh. Shared remaining quota and provider resets; Week-only capability-driven notApplicable, unknown/unreported/failure/stale remain distinct. Claude honest unavailable without verified source. Day 4 accepted; historical supported0.160.1 Owner acceptance retained;0.162.0-alpha.2 read-only protocol/parser compatibility observed PASS without quota/reset retention, new RC Live UI pending.

### Cleaner

Explicit Discovery/Scan/Explain/Content Preview/drill-down for Xcode/Gradle/Maven/npm/Homebrew; Maven markers counted once. Docker local logical read-only storage, no VM traversal. v0.1 has no cleanup/Trash. Real scan, Preview and Docker queries previously Owner accepted.

### Menu Bar

Overview/main/Menu Bar consume shared snapshots. Main-window close does not duplicate or stop required background collectors. D2–5 opening/closing accepted. Small menu icon remains DRAFT.

### Settings / Accessibility

Preview/Live, Chinese/English and App appearance; native SMAppService authoritative status with explicit actions. Day 6 scoped VoiceOver, keyboard and Reduce Motion Owner acceptance PASS. Real Login Item unavailable in unsigned preview and registration/unregistration NOT_RUN.

## Architecture

One AppStore owns SensorHub, DevMonitor, NetworkMonitor, AIQuotaMonitor and on-demand Cleaner sessions. Value snapshots feed views; generation rejection and serialized teardown prevent stale publication. Views do not launch providers. Pipe cancellation wakes bounded readers rather than waiting for descendant EOF.

## Safety / Privacy

No credential-store/profile read, quota mutation, inference or project upload. No shell rc sourcing, sudo, destructive Cleaner or actual copied stop-command execution. Live Network makes disclosed external requests; local-first is not zero network traffic. Proxy secrets are redacted. Prior Day 5 profiler exposure incident remains in its historical report, not reclassified as clean. Day7 source/document/artifact audit PASS; Overview and the four required Preview images have been visually privacy reviewed. AI quota/reset values are explicitly authorized Mock data, with bilingual captions; no real account telemetry is included. Final Owner screenshot-set approval PASS; final regression/performance and overall release approval remain separate.

Privacy reasons remain DiskSpace/85F4.1, UserDefaults/CA92.1 and SystemBootTime/35F9.1; final packaged bytes match source exactly.

## Test Summary

Baseline 363 tests. Day 7 independent clean Debug build PASS. First test compile checkpoint failed due to a test-only Data/String assertion; failure log retained, assertion corrected. Repaired full test run: 363 tests, 0 failures. Final full test run:363passed/0failed/0skipped. HeldPipe3cases ×20iterations=60executions/0failures. Formal doctor/build/test/progress/visual/verify/ledger/diff PASS after preserved stale-fingerprint checkpoint and truthful evidence refresh. No production change or test deletion.

## Manual Acceptance Summary

Historical Day 2–6 Owner acceptance retained. Day 7 final Live System/Network/Dev/AI/Cleaner/Menu Bar and final RC launch/quit/reopen are OWNER ACTION REQUIRED. No current final manual PASS is inferred from fixtures or screenshots.

## Performance Summary

Day 5 finite Release scenarios and Day 6 30-minute run retained. Day 6 parent CPU avg0.026535%, p950.097671%, max0.287339%; RSS start118.948/end97.452/avg101.987/max118.948 decimal MB: CPU PASS, RSS REVIEW ACCEPTED, not <100MB PASS. One supported Codex child at every sample. Finite results do not prove absence of leaks.

Day 7 final-byte five-minute sanity: NOT_RUN; awaits final Release and Owner-confirmed Live menu-bar-only setup. No full profiling/stress test is planned absent an evidenced anomaly.

## Packaging Status

Version 0.1.0/build1 is configured in both App configurations and generator. Debug generated Info.plist checked. Earlier pre-compatibility unsigned Release clean build/package PASS (historical; not final current RC). Zip6,890,124bytes, SHA256 `142e55c8f6db4541c80dbfc15c5792541dbab895e553e3948840c73f91c974a6`; independent extraction matches all7Appfilehashes. Version/resources/icon/notices/privacy checked. Earlier candidate launch/Preview AX observed. New compatibility RC clean build PASS, but packaged-binary privacy scan FAIL; no accepted new final package SHA, no new RC launch or final Owner launch/quit/reopen acceptance. Build outputs remain ignored and are not public installers.

## Signing / Notarization Status

NOT_RUN. `local.macsoul.app`, signing disabled. Owner must choose production bundle ID, Team/certificate, hardened runtime and entitlements; no Keychain access, account action, installation or submission. [Release guide](../docs/RELEASE.md) provides unsigned path and Owner-authorized plan. Public distribution pending signing.

## Screenshots / Documentation

Bilingual README incrementally updated, concept clearly labeled; CHANGELOG and CONTRIBUTING added. Actual Developer Preview Overview, AI Coding, Cleaner not-scanned, Settings upper-section and Menu Bar images exist and are integrated into both READMEs. Each of the four requested images passed visual privacy review: no real public IP, quota/reset, account identity, absolute local path, proxy credential, token/session or unnecessary real PID. Menu Bar contains only a TEST-NET example address. AI clearly labels both providers Mock and the source as a bundled scenario, without Live Provider metadata. Owner explicitly authorized simulated quota/reset values; both README captions identify them as Developer Preview mock data, not a real account.

Existing Cleaner, Settings and Menu Bar image bytes are retained unchanged. Earlier connection failures remain **TOOL FAILURE / not proven MacSoul defect**; historical checkpoints are preserved in the Day 7 report. No further Computer Use, App restart, image generation or product change was needed. The small menu icon remains **DRAFT**. GIF NOT_GENERATED (optional). D7-07 remains verifying until the Day 7 overall closeout; final Owner screenshot review and the main/secondary README arrangement passed; screenshot privacy review does not establish functional, performance or complete interaction acceptance.

## Earlier environment stop — Codex version changed (historical checkpoint)

Read-only version query of the exact bundled executable used by `CodexQuotaProvider.nativeLive()` returned `codex-cli 0.162.0-alpha.2`. Only exact 0.160.0 / 0.160.1 are verified. Source inspection confirms unknown versions are rejected before opening the native transport; this is not a new Live UI observation. The original Day 7 instruction explicitly requires STOP on an unknown version. No version allowance, protocol/account read, compatibility spike or product change was performed. Final supported-Codex Live regression and five-minute performance measurement remain NOT_RUN. Historical supported-version acceptance remains historical.

Current unsigned RC executable and zip checksum, version0.1.0/build1 and privacy bytes were rechecked PASS without rebuilding. Owner-approved Settings caption explains unsigned unavailable Login Item; real registration/unregistration awaits signed/installed validation. No App restart or process termination.

## Historical / Superseded — Latest compatibility / packaging checkpoint — STOP

Owner-authorized 0.162.0-alpha.2 read-only compatibility PASS: exactly one rate-limit read, actual unchanged production parser validation in memory, no raw/numeric/account retention;15s natural update notification NOT_OBSERVED; observer normal exit. Exact allowlist alone extended;365tests/0failures/0skips, build/verify/ledger PASS. The previous unknown-version STOP is preserved as history, not the current incompatibility verdict.

New Release clean build and archive/extraction/version/privacy-manifest/notices checks passed. Executable literal privacy check found178actual owner-home path occurrences: **FAIL**. No raw strings included here; classification as debug metadata or runtime strings remains UNKNOWN. Following Owner's stop-on-failure instruction, no repair or new RC launch was attempted. Current new package is unaccepted and unshared; old package SHA remains historical. Final Live regression and five-minute performance NOT_RUN.

Cleaner current RC scan lifecycle and idle Owner PASS; retained results are compatible with idle, no rescan requested. This Owner message does not explicitly confirm current RC Content Preview navigation; earlier accepted Preview remains historical.

Post-v0.1 follow-up: replace exact-version admission with a strict runtime protocol/capability compatibility gate while retaining the read-only RPC allowlist, strict schema validation and fail-closed behavior; no account/profile/prompt/thread access. Not implemented in this RC.

## Known Limitations

- Exact verified Codex versions only; unknown versions fail closed. Provider quotas are not an SLA; Claude subscription quota unavailable without verified source.
- Cleaner read-only; APFS clones/shared blocks, sparse files/hard links/purgeable estimates differ from exact reclaimable bytes. Docker logical usage is not VM physical size.
- Listener is not conflict; clipboard stop command may refer to a reused PID. Network transport reachability is not full health/authentication, tunnel hint is not routing proof.
- Finite performance is not leak proof; historical parent RSS REVIEW remains visible.
- Menu icon DRAFT; real Login Item, signing and public distribution not validated.

## NOT_RUN

Day 7 GitHub Xcode26.6 CI; final manual regression/performance/package Owner acceptance; signed installed Login Item; signing/notarization/Gatekeeper/public release; App Store Connect privacy validation; Claude subscription quota; Energy Log; active outage/resource stress.

## NOT_OBSERVED

Real Memory Pressure critical, quota95% event and account/rateLimits/updated notification.

## Deferred

Real installed/signed Login Item validation requires Owner setup. Final screenshots have Owner approval; final manual regression awaits a supported Codex environment or separately authorized compatibility verification. No deferred item is silently counted PASS.

## v0.2.0

Separately design Cleaner selection, confirmation, dry-run/policy, Trash/recoverability and cleanup; Maven/Gradle Build Tools and Docker storage/cleanup extensions. None is current functionality.

## Later Roadmap

v0.3 timeline/history/daily reports; Notch remains a future enhancement. No next-stage work in this round.

## Historical / Superseded — Final Verification

Current exact-version automatic commands PASS (365tests/0failures/0skips); fingerprint `82396e1efc6f75dd50aae89b556912560d647e62207be38088c240c8cd4dc8c2`, recorded in [Day 7 detailed report](day-7-release-closeout-2026-10-07.md). Local Xcode27 does not substitute for Day 7 Xcode26.6 CI. Historical PR9 CI is not Day 7 evidence.75local document/image links PASS,0missing; immutable baseline/priorstatus audit PASS;21changed/newfiles,0staged.80product files unchanged; sole production delta is observed exact-version admission.

## Task Ledger

D7-01/04/05/06/08 verifying; D7-02/03 doing, pending final Owner regression and five-minute sanity; D7-07 verifying with screenshot Owner PASS, awaiting overall closeout. Never self-approved done. Day 2–6 done preserved. [Generated STATUS](../docs/STATUS.md) is the only progress summary; original76points unchanged.

## Release Decision

**NOT READY** for final Owner acceptance at this checkpoint. Final manual regression and performance sanity remain pending; all required Preview images, privacy checks and Owner screenshot review passed. No signed/notarized/public release claim. Current System-layout Archive-derived App/zip static privacy and extraction PASS; new minimum Preview smoke remains partial after TOOL FAILURE. Prior accepted package privacy/smoke PASS retained as historical. Final Live regression/performance remain separate. Historical failed checkpoints below are preserved, superseded by the newest checkpoint.

## Historical / Superseded — Latest owner-path diagnosis — packaging gate FAIL / STOP

Standard unsigned Archive built successfully without source or project-setting changes, but still has178owner-home references:89per slice, entirely `__LINKEDIT / LC_SYMTAB/string_table` debug-map metadata (`N_SO`44, `N_OSO`44, `N_AST`1). No executable DWARF sections and no runtime-section hits. Production tracked source44files and generated Swift2files explicit-path scan PASS. Root cause: **DEBUG METADATA / PACKAGING PIPELINE**. Effective Archive `DEPLOYMENT_POSTPROCESSING=YES`, `STRIP_INSTALLED_PRODUCT=NO`; no Strip action. No manual strip or repair performed.

Independent extraction of the old zip proves it also contains178, with its original executable hash unchanged. The earlier zero claim is not reproduced; the original binary-scanner implementation and historical effective strip/debug settings are UNKNOWN. Both retained build commands were isolated Release clean builds, same universal architectures/version; no evidence implicates the Codex allowlist. Preserve prior checkpoints as history, superseded for binary privacy.

Failed new build executable/zip SHA256 remain `4b0dd49d28c2593963d25a57be5a1dba2ee475c8744e02bbf86e6ab62cae3430` / `dcab860db5b638cf20cdc3e874cf751f89ce7ba6ae6ef549e439a94d909bdddb`. Diagnostic Archive executable SHA256 `39b45ae6ea32e74398211263ce78a52676378c25330e0afc08a00da3a73744e1`; not an accepted final executable. No new accepted zip/hash/size. Archive version0.1.0/build1, universal architecture, PrivacyInfo byte equality/exact3reasons, notices and no bundled source/log/testfixtures PASS. Full counts/offset categories and sanitized evidence are in the [Day7 report](day-7-release-closeout-2026-10-07.md).

Release guide now requires an accepted Archive-derived App; raw build-product packaging is superseded. Owner-reviewed standard Archive with installed-product stripping is the proposed next work unit, not executed/proven. **No launch, Live regression or performance** in this diagnostic work unit. Current source fingerprint remains `82396e1efc6f75dd50aae89b556912560d647e62207be38088c240c8cd4dc8c2`; prior365test/build/verify evidence unchanged. Staged0; no commit/push/PR/signing/notary. Release remains NOT READY, awaiting Owner decision.

## Historical / Superseded — Latest first-stage stripping hypothesis validation — FAIL / STOP

Owner-authorized unsigned Archive requested `STRIP_INSTALLED_PRODUCT=YES`, but the effective Archive target value remainsNO and no Strip action/command ran. Build exit0; executable still178debug-map references (89per architecture, N_SO44/N_OSO44/N_AST1), same diagnostic hash `39b45ae6ea32e74398211263ce78a52676378c25330e0afc08a00da3a73744e1`. Requested-override/effective-setting discrepancy cause UNKNOWN. No runtime-section hit, DWARF section or resource loss. PrivacyInfo/notices/version/universal/resource byte checks PASS; package privacy FAIL.

Per the explicit first-stage stop condition, no additional flags, generator/project settings or production Swift changed. Release DEBUG_INFORMATION_FORMAT still dwarf; no dSYM generated, UUID matching N/A. No formal final Archive/zip, launch/quit/reopen smoke, Live regression or performance. Original failure artifacts and prior zero-claim correction retained. Prior365test/build/verify evidence is unchanged, not rerun by this attempt. Task states remain verifying/doing; no final acceptance inferred. Further investigation waits for Owner. No staging/commit/push/PR/signing/notary.

## Historical / Superseded — Latest persisted Release packaging checkpoint — static PASS, smoke pending

Root cause confirmed by temporary testabilityNO/stripYES/dwarf-with-dsym Archive:178→0. Generator and checked-in project now persist only App Release ENABLE_TESTABILITYNO, STRIP_INSTALLED_PRODUCTYES and DEBUG_INFORMATION_FORMATdwarf-with-dsym. Candidate diff/byte-consistency PASS; Debug/tests/all other settings and all product/test source bytes unchanged. Guard retained. Fingerprint `0298b0278fc08b049dcd62397abbd53efde6ba2023576228f8ec5c917dfb64da`.

Actual full doctor/build/test/progress/verify/ledger/diff rerun PASS;365tests/0failures/0skips. Formal Archive without temporary packaging overrides PASS, actual Strip1. Both slices and all seven App files/resources owner-prefix0; N_SO/N_OSO/N_AST path maps removed. Universal/version0.1.0/build1/privacy exact3reasons/notices/resource preservation PASS. Private dSYM generatedYES/UUIDmatchPASS, excluded from zip. Independent extraction all7filehashes equal; all uncompressed zip-member/extracted-binary privacy PASS.

Executable SHA256 `b97a0c0fe276f68b8875879456a3e2f0963d6a76505bc2df8d824992d0dedb1f`; zip SHA256 `8a230b20839ceb5d51d303896fac85e85faceaa0ebb0f7d1eb77a99bd44c5411`,6,062,468bytes. Old false-zero claims and failed artifacts preserved as SUPERSEDED history, corrected scanner authoritative. Minimum Preview launch/main/Menu Bar/normal Quit/reopen smoke **PENDING**, so no combined final unsigned package privacy acceptance yet. New App not launched while old-process authorization pending. Owner Live/performance NOT_RUN. UNSIGNED/UNNOTARIZED/NOT FOR PUBLIC DISTRIBUTION. No signing/notary/commit/push/PR/tag/Release.

## Historical / Superseded — Current final unsigned packaging verdict — PASS, stop before Live/performance

**FINAL UNSIGNED RC PACKAGE PRIVACY = PASS.** The newest completed checkpoint supersedes pending-smoke statements above while preserving them as earlier checkpoints. Formal no-override Archive, actual Strip1, both architecture owner-prefix counts0, removed N_SO/N_OSO/N_AST path references, private dSYM UUID match, exact privacy3reasons/notices, Archive-only zip and independent extraction all PASS. Full actual automatic verification365passed/0failed/0skipped and ledger PASS.

Minimum Preview launch/main/normal Quit/reopen PASS via native observations and confirmed process exit; Menu Bar Extra/Mock label PASS via Owner-operated screenshot. A duplicate instance was explicitly authorized for SIGTERM and removed; exactly one current App PID76421 remains. Screenshot establishes visual smoke, not Owner final release approval. No new Live or performance observation.

Executable SHA256 `b97a0c0fe276f68b8875879456a3e2f0963d6a76505bc2df8d824992d0dedb1f`; zip SHA256 `8a230b20839ceb5d51d303896fac85e85faceaa0ebb0f7d1eb77a99bd44c5411`,6,062,468bytes. Source fingerprint `0298b0278fc08b049dcd62397abbd53efde6ba2023576228f8ec5c917dfb64da`. Running App/Archive file hashes still match. Safe for separately authorized Owner Live regression:YES. Final Live regression/final300sperformance NOT_RUN; signed/installed Login Item, signing/notary/Gatekeeper/App Store Connect validation NOT_RUN. Overall Day7 approval still pending, task statuses unchanged. No public distribution, commit/push/PR/tag/Release. See latest Day7 report and ignored package/smoke audits for scope.

### Historical / Superseded — Final RC Live screenshot checkpoint — visual observations, Owner verdict pending

Owner supplied13Live screenshots for visual review. Overview/System/Network/AI/Dev/Settings show Live sources. AI visibly reports Codex App Server / CLI0.162.0-alpha.2, applicable Week-only remaining semantics and fiveHour notApplicable; Claude honest unavailable. Network preserves independent IP outcomes, distinct proxy contexts, tunnel-hint disclaimer and HTTP/TLS-only probe semantics. Memory pressure unknown/monitoring is retained; Soul copy limits its health claim to CPU. Dev context/shim and filtered/all listener tables are visible. Cleaner screenshots show not-run→active scan→completed, but no Content Preview traversal observation.

Layout concern: System content is vertically centered with substantial blank space and a wide separation between process names and numeric columns. Read-only inspection confirms SystemView currently uses default Form with padding; Network uses grouped Form. No code edit or causal toolchain claim. Owner must decide whether this is a final UI issue or an accepted presentation limitation before proceeding.

No final per-section Owner PASS, Live Menu Bar/three-surface consistency, Live normal Quit/reopen or performance readiness was supplied in this screenshot-only message. Clipboard actions and current Preview traversal cannot be proven from static images. Final Live regression remains pending, final300sperformance NOT_RUN; no preheat or sampling. Live images and their real quota/reset/IP/local-path data were not copied into repository/evidence; only sanitized semantic observations recorded. Existing package identity/privacy PASS is unchanged.

## System-layout RC automatic/static closeout — PASS; manual smoke pending

Full actual verify exit0: doctor/build/unit/progress_tests/visual_assets/ledger PASS, independent XCTest365passed/0failed/0skipped. Source fingerprint `1c60e81ec22795ba49bac7877309e57f534e2bc1d21911dcddef9adb171fb067`. No layout-mirroring unit tests added. Existing method suffix for disk/battery/process rows is byte-identical; only System-local layout composition changed. Shared parent/AppShell, providers/semantics/cadences/other pages/tests/project settings/PrivacyInfo unchanged. Minimum900×620, default1120×760 are defined in MacSoulApp; actual minimum/default/large/tall visual checks remain PENDING, not automated PASS.

Formal new Archive `.artifacts/day7/system-layout/MacSoul.xcarchive` exit0 with only unsigned CODE_SIGNING_ALLOWED override, no temporary packaging flags. Effective testabilityNO/stripYES/dwarf-with-dsym, optimization-O, COPY_PHASE_STRIPYES/DEPLOYMENT_POSTPROCESSINGYES/STRIP_STYLEall; actual Strip1. Universalarm64/x86_64, owner-prefix0in each slice and all App resources, old debug-map references absent; private dSYM generated and both UUIDs match. Version0.1.0/build1, exact unchanged3privacyreasons/source bytes, notices/source bytes and runtime resources PASS. Seven distributed files, no source/tests/logs/raw payloads/artifacts/screenshots/private dSYM in bundle/zip. Independent fresh extraction all7filehashes identical and privacy rescan0.

**New current RC identity:** executable SHA256 `7224f208d58b45612c3482b24ee7ec637c4f6c725fb0cde4a49fc4aabac60200`; zip SHA256 `6b541098d2cddcab546fecad4d5a48b09e1c837892ea0af68a912ff634e3f177`; zip6,062,427bytes at `.artifacts/day7/system-layout/release/MacSoul-v0.1.0-unsigned.zip`. New static package privacy PASS. Prior accepted b97a0c/8a230b/6,062,468byte RC is HISTORICAL / SUPERSEDED for current final validation, with its original privacy and Preview smoke PASS retained, not converted to FAIL or overwritten. All earlier STOP/FAIL/SUPERSEDED/temporary-strip/HeldPipe/history retained.

Per this work unit's explicit restart instruction, verified old exact RC PID76421 received only SIGTERM; normal exit confirmed. Started byte-identical new Archive-derived copy `build-preview/MacSoul.Day7.SystemLayout.bos7qpyh/MacSoul.app`, PID3374; exactly one App at launch. Native AX confirms main Overview and Developer Preview Mock labels PASS. System click returned **TOOL FAILURE: native pipe closed**, not proven MacSoul defect. No further Computer Use retries, alternate UI automation, source workaround or repeat restart. Requested Owner manual System minimum/default/large/tall checks, Preview Menu Bar and normal Quit/reopen. These gates remain PENDING, combined new minimum smoke PARTIAL; no final combined new package runtime verdict inferred. Other-page regression beyond the observed Overview is NOT_CONFIRMED this unit.

Owner new-RC Live acceptance pending: System layout; Live Menu Bar / AI Coding / Overview consistency; final Live Quit/reopen and remaining per-section results. Cleaner existing lifecycle/idle PASS retained; no new scan or traversal initiated by agent. Final performance NOT_RUN; only after actual new-RC Owner Live PASS and readiness can that next unit begin. No new quota/reset/account/IP/path retention, no signing/notary/publication/commit/push/PR/tag/Release or Day7 done promotion.

Owner authorized one additional Computer Use retry after suggesting backgrounding may cause disconnect. getApp again succeeded and observed Preview Overview; clicking System again returned native pipe closed. The backgrounding hypothesis remains UNKNOWN, not a proven App defect. No further retries, source changes, App restarts or screenshots; remaining System size/layout and Menu Bar/Quit-reopen manual checks still pending.

System Preview screenshot checkpoint: Owner supplied a Mock-only System screenshot showing content starting near the navigation header, readable metrics without overlap and explicit simulated-data labels. Visual observation PASS for the pictured window only; exact window point dimensions UNKNOWN. This is not Owner all-size approval, minimum/default/large scrolling proof or Live process-table acceptance. Screenshot privacy PASS and file retained only at ignored `.artifacts/day7/system-layout/owner-system-preview.png`. Remaining Menu Bar/normal Quit-reopen and Owner size/Live checks pending. No source/build/package change or performance sampling.

### Additional Owner Preview visual observations

Owner supplied three System Preview window screenshots and one Menu Bar Preview screenshot. System content remains top-leading with readable metrics and no visible overlap at the pictured sizes. Exact point dimensions, the minimum/default sizing gate and scrolling are not inferred from image pixels. Menu Bar visual smoke PASS: rendered popover with explicit simulated-data labeling. Screenshot privacy PASS: all quota/reset values are visibly Mock, the IP is the documentation example, and no real account/telemetry/local absolute paths/credentials are visible. Images retained only under ignored `.artifacts/day7/system-layout/`; existing evidence preserved.

Normal Quit/reopen of the new RC and Owner final size/Live acceptance remain PENDING. Combined new Preview smoke remains PARTIAL; no source/package identity changes, task promotion, Live action, performance measurement or publication.

Manual reopen checkpoint: Owner ran `scripts/run-mock.sh`, which builds and copies the Debug product. Read-only inventory observes one MacSoul (PID9413, `build-preview/MacSoul.kVtM1k/MacSoul.app`), not the current System-layout Archive copy. Therefore this launch does not establish same-Archive normal Quit/reopen PASS; that gate remains pending. Existing Archive/zip identity and privacy evidence are unchanged. No agent termination, launch, source change or performance measurement.

### Correct Archive reopen — Owner manual smoke checkpoint

After correcting the accidental Debug launch, Owner reports executing the instructed exit/open steps and supplies reopened Preview Overview and Menu Bar screenshots. Read-only inventory confirms exactly one MacSoul, PID10479, running the current `build-preview/MacSoul.Day7.SystemLayout.bos7qpyh/MacSoul.app`. All seven App file hashes match the formal System-layout Archive, including executable SHA256 `7224f208d58b45612c3482b24ee7ec637c4f6c725fb0cde4a49fc4aabac60200`. Previous Archive PID3374 and accidental Debug PID9413 are absent.

Same-Archive reopen/main/Menu Bar manual smoke PASS, with explicit Mock labeling. Normal exit is based on Owner's report of executing the instructed steps; the native Quit action was not independently observed. Screenshot privacy PASS; Mock quota/reset and documentation-example IP only, stored under ignored `.artifacts/day7/system-layout/`. Prior pending and accidental Debug checkpoints preserved. Exact minimum/default size and scroll confirmation, Live process layout and final Owner Live acceptance remain pending; no overall Day7 approval or performance readiness inferred. No source/package changes, task promotion, agent termination, App launch, Live action or performance sampling.

### New System-layout RC — Live screenshot observations

Owner supplies Settings/Live System at several pictured window sizes and Live Menu Bar screenshots. Visual observation PASS: System is top-leading, metrics and developer-process ranking are separate bounded sections, numeric columns align without visible overlap, and explanatory footnotes remain readable. Memory pressure remains unknown/monitoring rather than being inferred from memory-used percentage. Settings shows Live mode; Menu Bar shows applicable Week-only remaining quota and honest Claude unavailable without Mock leakage.

These are visual observations, not an inferred explicit Owner acceptance verdict or exact minimum/default dimension/scroll proof. System Owner verdict and remaining Live regression/three-surface/lifecycle acceptance remain pending. Raw Live screenshots and real quota/reset/IP/process IDs were not copied into repository or evidence; only presentation semantics recorded. Source/package identity unchanged; performance NOT_RUN, no task promotion, commit/push/PR or new product changes.

### New RC Live cross-surface screenshot checkpoint

Owner supplies Network, AI Coding, Overview and Menu Bar screenshots. AI three-surface visual consistency PASS: applicable Week-only remaining numeric presentation and reset expression agree; detail explicitly retains fiveHour notApplicable, Codex App Server / CLI0.162.0-alpha.2 and freshness, while Claude remains honest unavailable with no fabricated source. Network shows connected Wi-Fi, independent IPv4/IPv6 failure semantics, region not collected and distinct App/system proxy contexts. Overview shows the transport-reachable summary and Cleaner read-only/not scanned. No real quota/reset/IP/process IDs or raw Live images retained.

Static visuals do not prove Dev clipboard interactions, System scrolling, final Live normal Quit/reopen or an explicit Owner overall acceptance verdict. Those confirmations remain pending; performance NOT_RUN and no warmup/sampling initiated. Source/package/task statuses unchanged, historical evidence preserved.

Final documentation/ledger closeout checks actually executed: `python3 scripts/generate_status.py` exit0; `python3 scripts/verify_progress.py` exit0 (59tasks/original76points); `python3 scripts/test_progress.py` exit0; read-only source/baseline/privacy/local-link audit exit0 (76links/images,0missing); `git diff --check` exit0. Evidence `.artifacts/day7/final-live-closeout-checks.json` and `final-performance-consistency.json`. Source fingerprint unchanged;22modified/newfiles in full Day7 worktree, staged0, tracked measurement/build artifacts0. Product-source changes across the whole Day7 branch remain limited to the previously accepted exact Codex allowlist and System-local layout repair; this performance/report unit changes no product code. Overall Owner final review and RSS REVIEW acceptance pending.
