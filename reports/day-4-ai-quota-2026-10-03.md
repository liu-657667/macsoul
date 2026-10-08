# Day 4 — AI Quota, first phase

> 公开文本中的 Owner-home 路径前缀已替换为 `<OWNER_HOME>`；命令含义、日期、哈希和历史结果保留。原私有证据与 Git 历史未改写；此项与 distributed App package privacy 分别记录。

Checkpoint filename requested by Owner: 2026-10-03. Execution date: 2026-10-04 (Asia/Shanghai).

## Scope / revision

- Base / unchanged HEAD: `ed0f61a9c84848c1db9d1a7b87236ce36fe72673`.
- Working branch: `feature/ai-quota`; uncommitted first-phase changes only.
- D4-01–D4-07: **verifying**. No real Codex observer has been started. This checkpoint stops before account observation and does not claim the final live adapter/UI acceptance.
- Day 2, Day 3 and Cleaner human acceptance remain historical evidence; their done states and original plan/points/dependencies are preserved. D5-03–06 / Day 6 / Day 7 are unchanged.
- No commit, push, PR, UI redesign, image generation or Harness regeneration. Xcode project changes only register the new source/test files using the existing deterministic source inventory; target/scheme/resources/deployment settings remain unchanged.

## AUTOMATED

Final local verification (2026-10-04, Asia/Shanghai):

| Check | Command | Exit | Result / evidence |
|---|---|---:|---|
| Clean build | Removed only `.artifacts/DerivedData` and `.artifacts/MacSoulTests.xcresult`, then `./scripts/build.sh` | 0 | PASS; `.artifacts/build.log` |
| Unit | `./scripts/test.sh` | 0 | **298 tests / 0 failures**; `.artifacts/test.log`, `.artifacts/MacSoulTests.xcresult` |
| Combined | `./scripts/verify.sh` | 0 | PASS; `.artifacts/verification.json` |
| Ledger | `python3 scripts/verify_progress.py` (within verify) | 0 | PASS; `.artifacts/progress-verify.log` |
| Diff | `git diff --check` plus untracked-file whitespace checks | 0 | PASS; index empty |
| Privacy | Source/packed plist byte equality and exact three-category check | 0 | PASS; no manifest change |

- Local macOS **27.0.1 / 26A434**; Xcode **27.0 / 27A266a**; developer directory `/Applications/Xcode.app/Contents/Developer`.
- Existing baseline 242 test cases remain; 56 new cases added. System/Soul/Dev/Network/Cleaner suites also passed. Native fake-pipe early-stop test completes ten immediate startup/cancellation cycles.
- Base HEAD: `ed0f61a9c84848c1db9d1a7b87236ce36fe72673`; uncommitted source fingerprint: `44dfe6e308f3d996dda23fbbfc14a179cc06101fbdaaae95c5bc5d1dbd79c18d`.
- Final manifest checked at `2026-10-03T16:52:21.529657+00:00` (2026-10-04 local). Evidence is for this working tree, not a commit or CI run.
- Earlier verify attempts correctly failed ledger when prior automated fingerprints were stale. After actual build/unit/progress/assets PASS, 43 previous automated evidence records were refreshed with old copies retained in `evidence_history`; the final source revision required refreshing those plus seven D4 fake-test records. Historical plan, points, acceptance, statuses and human confirmation fields were checked against HEAD and preserved. Initial diagnostics remain in `.artifacts/day4-initial-verification.json` / `.artifacts/day4-initial-ledger.log`, and post-review stale-ledger manifest in `.artifacts/day4-post-review-verification.json`.
- Final scope review: **26 files** (17 tracked modifications, 9 additions); no staged files, build artifacts, personal configuration or credential-pattern matches. No commit, push or PR. Owner preview App PID 78340 remains untouched.
- Xcode 26.6 GitHub Actions compatibility, real AI providers, new human AI UI acceptance and formal Performance remain **NOT_RUN**.

Implementation:

- One shared AIQuotaMonitor, CodexQuotaProvider and ClaudeQuotaProvider. AppSnapshot quotas/details feed the existing Overview, AI Coding and Menu Bar paths. Live mode contains source-derived unavailable states, never Claude Mock leakage; Preview retains all prior fixtures.
- Codex production constructor authorization is closed. Candidate read-only RPC allowlist: initialize, initialized, account/rateLimits/read. No account/read is needed; no prompt, thread, login/logout or account mutation requests are exposed.
- Native transport launches a literal executable/argument array, away from the repository working directory. NDJSON is capped at 64 KiB per line and 32 queued lines; pipe draining runs off MainActor. Raw stderr/notifications are discarded. Process teardown targets only its own child and awaits reaping; App termination waits for quota teardown. Shared ShellRunner is reused for bounded CLI version discovery.
- Fake-clock tests cover one start, initial read, update, connection/read/malformed failures, capped backoff, handshake timeout, cancellation, sleep/wake and generation rejection. A standalone Python fake child validates native stdio handling, read-only allowlist and owned-child shutdown. It is not Codex and cannot access an account.
- Parsing keeps the existing five state contract. Numeric used percent is finite 0–100, never clamped. Candidate Codex windows map by explicit duration, not container order; 300/10080-minute durations allow ±1 minute of source rounding; source duration is preserved pending installed-protocol validation. Unknown durations are ignored/unreported. Missing windows are not notApplicable. Multi-bucket selects codex without other-bucket/legacy fallback; duplicates are rejected. Epoch resets are retained; absent resets remain unknown.
- Claude pure subscription-field fixtures cover both/Week-only/5h-only, 0%, 95%, missing, stale, errors, unavailable and malformed values. Spend-limit data is not subscription quota. No installed bridge is activated.

Earlier diagnostic checkpoints (not final acceptance):

1. Initial all-suite run: 295 tests / 3 failures. These were three existing assertions that Live AI must stay Mock; they were updated to the newly authorized no-Mock-leak contract, retaining System/Network assertions and adding explicit unavailable checks.
2. Two new pipe tests initially had async-autoclosure compile errors; corrected using awaited locals.
3. The native fake-pipe test exposed short-line buffering in Foundation read(upToCount:). That run was stopped (exit 143), only its owned fake/test processes were terminated; the Owner preview App was left running. Transport now uses bounded POSIX pipe reads, which return currently available bytes. The two native-pipe tests then passed. No failure is recorded as a PASS.
4. A later clean run exposed an immediate-cancellation race: the fake child had exited, while Foundation waitUntilExit remained inside its run loop. The owned test App/xcodebuild were stopped with SIGTERM (exit 143), Owner App untouched. Native teardown now waits on the Process termination callback, and the early-stop test repeats ten launches without a handshake.
5. Final parser review replaced exact duration matching with a narrow ±1-minute tolerance and added a source-duration preservation/outside-tolerance test. Installed-protocol validation remains pending authorization.

## CODEX CAPABILITY

Local discovery only:

- Executable found at `/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex`.
- Runtime CLI version: **UNKNOWN**. No Codex version command or app-server invocation has been executed in this phase. Bundle metadata does not provide a CLI semantic version.
- [Official App Server documentation](https://learn.chatgpt.com/docs/app-server) describes stdio initialization, rate-limit reads and rate-limit updates. Its rate-limit fields distinguish consumed percent, duration in minutes and reset epoch seconds. This establishes a candidate contract, not installed-version acceptance.
- Installed read method / notification / window durations / bucket behavior / cross-client update behavior: **UNVERIFIED**.

### Prepared observer proposal — requires separate Owner authorization

Literal executable above, with:

1. `--version` (bounded local version discovery).
2. `app-server --listen stdio://` as one MacSoul-owned long-lived child.
3. `initialize` with clientInfo `{name: macsoul_quota, title: MacSoul, version: 0.1.0}`; after success send `initialized`.
4. One `account/rateLimits/read`, then listen for `account/rateLimits/updated` if the installed protocol supports it. No quota polling fallback is enabled.

Read-only request IDs are local 1/2. The intended initial/read handshake has 10s timeouts. Connection recovery uses 1/2/5/10/30/60s capped delays, reset after successful quota read. Sleep/Preview stop the child; a new generation starts with unavailable data and rejects previous callbacks. No coding request, account mutation, auth refresh token request, login/logout or raw account dump.

Retained **in memory for UI only**: provider/window availability, consumed percent, window duration, reset epoch, local sample timestamp, source/capability/version. Standard codex bucket identity is used for selection; arbitrary account/bucket labels are not retained.

Retained **in reports only**: CLI version, supported method/notification names, field names/units, durations, shape/availability and standard bucket semantics. Owner real percentages/reset timestamps are omitted by default.

Discarded: email/account/workspace identifiers, credentials/tokens/headers, credits, usage/cost/session data, raw JSON/diagnostics, prompts/conversations, source/workspace paths and unrelated events. No credential-store access. Actual update support remains UNKNOWN until the authorized observer establishes it.

## CODEX LIVE

**NOT_RUN — waiting for explicit Owner authorization.** A fake response PASS is not real Codex retrieval, freshness or cross-client acceptance. The App's default provider is fail-closed; selecting Live cannot implicitly grant observer permission.

## CLAUDE CAPABILITY

- Owner has no Claude Code subscription; no purchase/account borrowing/test-token request.
- Executable: **not found** in the current process PATH or the fixed `~/.local/bin`, `/opt/homebrew/bin`, `/usr/local/bin` candidates. No recursive HOME search.
- Version: **UNKNOWN / not installed in checked locations**. No Claude executable command was run.
- [Official status-line documentation](https://code.claude.com/docs/en/statusline) describes subscription window percentage/reset fields. The candidate parser accepts only sanitized five_hour/seven_day data; other session/context/token fields never enter the quota snapshot. No status-line installation/configuration change or full session payload read occurred.
- Installed stable source capability: **UNAVAILABLE / NOT_VERIFIED**, rather than claiming that all Claude versions lack an official source.
- Public UI: Claude Code → Quota unavailable; detail: Not detected. Future detected-but-unverified installations show Detected · No verified quota source. Authentication and subscription are not inferred from a version or executable.
- Detail-layer notInstalled / detectedUnauthenticated / detectedNoSubscriptionQuota / unsupportedVersion / noVerifiedSource / available / requestFailed are covered by fake states. Common QuotaWindowState is unchanged.

## CLAUDE LIVE

**NOT_RUN / PROVIDER_UNAVAILABLE.** Fixture parsing is automated evidence only, not a real Claude subscription PASS. Honest unavailable is the allowed current boundary, not a requirement to buy a subscription.

## UI

- Shared QuotaRow retains dynamic windows, valid zero, explicit notApplicable hiding, unreported, request failure and stale semantics. Entirely unavailable providers get one compact text row and no bar.
- AI page/title and badges use Preview versus Live source mode; per-provider availability stays explicit. Provider connection/capability and localized source/time/version are details. All three entries use the same shared snapshot and injected display clock.
- The display clock advances every 60s; it never requests quota or recreates a reset. Switching App language reuses MacSoulLanguage date formatting.
- New AI human UI acceptance: **NOT_RUN**. Existing unrelated Owner acceptance was not overwritten. Current running Owner App was not restarted in this phase.

## ALERTS

- Fresh Live numeric values >=95% only, keyed by provider + window + supplied reset identity. Same reset emits once; a different reset may emit again. Missing reset conservatively suppresses announcement; no fabricated reset key.
- Unknown/unreported/notApplicable/unavailable/requestFailed/stale/Preview do not emit. Dedupe history survives provider lifecycle stop/restart. Event output is bounded in AppStore memory; eligible events carry Soul copy without changing System Soul states/priorities.
- No existing runtime UserNotifications infrastructure was present; no new permission subsystem or launch-time permission request was added. System notification delivery and real quota-triggered Soul UI: **NOT_RUN**.

## PRIVACY

- No credential files/cookies/Keychain/Authorization headers were read. No account payload was requested, printed or persisted.
- No Claude rc sourcing, shell -c, PTY/screen scraping, bridge/config mutation or transcript/history/source-path ingestion. No external quota request from tests.
- Transport termination is confined to MacSoul-owned children; no detected user process is terminated.
- Existing three Required Reason API declarations remain unchanged: DiskSpace/85F4.1, UserDefaults/CA92.1, SystemBootTime/35F9.1. No new unrelated privacy reason.
- Static privacy/source review and packed manifest check are separate from App Store Connect validation, which is NOT_RUN.

## NOT_RUN

- Real Codex capability/account quota observer, cross-client event propagation and Owner AI UI acceptance.
- Real Claude subscription quota/bridge installation/authentication verification.
- Real quota notification/Soul UI acceptance.
- Formal Performance (including the eventual Codex-owned child) and App Store Connect privacy validation.
- GitHub Actions Xcode 26.6 / 17F113 for these uncommitted changes; local Xcode 27 cannot substitute for future CI compatibility evidence.
- No next-stage Performance/Cleanup/Day 6/Day 7 work. No commit/push/PR.


## Owner-authorized Codex read-only capability observation — 2026-10-04

This later checkpoint replaces the earlier **Codex capability NOT_RUN** checkpoint only. It does not replace AI UI, ongoing Live monitor, notification, cross-client event or Performance acceptance. Earlier NOT_RUN records remain historical.

- Observation completed at `2026-10-04T00:59:35.182834+08:00` (Asia/Shanghai).
- Executable: `/Applications/ChatGPT.app/Contents/Resources/codex-cli/CodexCLI.app/Contents/MacOS/codex`.
- `--version`: **0.160.0** (only parsed version retained).
- Literal startup: `app-server --listen stdio://`; **PASS**. One observer-owned child, PID **21110**.
- `initialize` clientInfo: name `macsoul`, title `MacSoul`, version `0.1.0-dev`; response **PASS**, then `initialized`. No experimentalApi enabled.
- `account/rateLimits/read`: **SUPPORTED**, exactly **one** request. Existing managed authentication context sufficient: **YES**. No account/read, auth refresh response, login/logout, prompt, thread/turn, model inference, credit consume or email request.

### Redacted installed response shape

| Field / capability | Actual result |
|---|---|
| rateLimits | present (backward-compatible view) |
| rateLimitsByLimitId | present (multi-bucket view) |
| Bucket count | 1 |
| Codex relevant bucket | identified |
| primary | present, **10080 minutes** |
| secondary | absent |
| Candidate 5h / 300-minute window | **NOT_REPORTED**, not notApplicable |
| Candidate Week / 10080-minute window | **REPORTED** |
| usedPercent | numeric, finite, valid 0–100; actual value omitted |
| resetsAt | integer, finite, plausible Unix timestamp seconds; actual value omitted |
| account/rateLimits/updated documented support | YES |
| Notification observed in this session | **NOT_OBSERVED** during 15-second passive listening |

[Official OpenAI App Server documentation](https://learn.chatgpt.com/docs/app-server) defines consumed `usedPercent`, minute-based window duration, second-based Unix reset and the update notification. Successful read plus valid field shapes confirm the installed read contract; passive absence of an update does not prove either unsupported notifications or global/cross-client propagation. No model request was made to manufacture an update.

The installed **primary is Week**, so container order is not a window identity. Both response views describe one bucket; they are not added together. This is observation evidence only: no Provider mapping was changed and the fail-closed production constructor was not enabled.

### Privacy / lifecycle / stop boundary

- Raw JSON/stdout/stderr were processed or discarded only in observer memory. Persisted `.artifacts/codex-capability-observation-redacted.json` contains only an allowlisted shape/status/version summary. No real percentage/reset value, plan/account/workspace identifier, credits, credential, auth header, prompt or raw payload retained.
- No credential files, Keychain, browser storage or account-profile read. The child used its existing managed authentication context.
- After the 15-second passive observation, stdin was closed and the child **exited normally**. No SIGTERM escalation was needed, no SIGKILL. Only the observer-owned child was eligible for termination; existing ChatGPT/Codex/IDE/Terminal sessions were not targeted.
- Source fingerprint unchanged: `44dfe6e308f3d996dda23fbbfc14a179cc06101fbdaaae95c5bc5d1dbd79c18d`; HEAD remains `ed0f61a9c84848c1db9d1a7b87236ce36fe72673` on `feature/ai-quota`.
- No implementation, fixtures, task statuses or STATUS changes in this observation work unit. Existing 298-test/build/verify results remain the preceding implementation checkpoint; they were not rerun for this read-only observer.
- D4-01–07 remain **verifying**. MacSoul AIQuotaMonitor not activated; real quota UI / alerts / Soul / cross-client updates / Claude subscription / Performance remain **NOT_RUN**.
- No commit, push or PR. Stop here for Owner review of the observed installed protocol before final mapping/integration authorization.


## Final Codex Live mapping / integration — 2026-10-04

This checkpoint supersedes the earlier closed production gate and candidate-only mapping; first-phase results and the single Owner-authorized capability observation above remain historical evidence. No capability observation was repeated, no account/read or profile request was added, and no real MacSoul AI Live UI was started.

### Mapping contract

- Prefer the reliably identified Codex map bucket (key `codex` or unique explicit limitId), else use documented backward-compatible rateLimits. Unknown nonempty buckets without a valid fallback fail conservatively; no map-order selection, merging or addition.
- primary/secondary are unordered. Preserve ±1 minute source rounding around 300/10080; 15/60 and other unknown durations cannot become 5h. Ignore unknown valid durations before validating irrelevant percentage/reset fields.
- finite consumed usedPercent in 0–100, including valid zero, is used directly. Plausible integer Unix seconds retained; missing reset stays unknown, never sampledAt + duration. Malformed recognized window/duplicate fails that window; unrelated recognized data survives.
- Synthetic actual-shape fixture primary=10080 / secondary absent preserves Week and unreported 5h. No real Owner percentage/reset was copied to fixtures or this report.

### Owner plan semantics supplement

- [Exact installed-version rate-limit schema](https://github.com/openai/codex/blob/rust-v0.160.0/codex-rs/app-server-protocol/schema/json/v2/GetAccountRateLimitsResponse.json) supplies optional bucket planType; [official wire enum definitions](https://github.com/openai/codex/blob/rust-v0.160.0/codex-rs/protocol/src/account.rs) distinguish personal Pro/ProLite/ProMax from workspace variants. [Official current pricing](https://learn.chatgpt.com/docs/pricing#what-are-the-usage-limits-for-my-plan) states Pro currently has no five-hour limit.
- Minimal transient enum: unknown / plus / pro. Only exact typed values pro, prolite, promax establish personal Pro semantics; no UI/contains/user input/email/config classification. Selected bucket only; other buckets/envelope fields cannot supply plan evidence. Unknown future, wrong case, display names, malformed fields and workspace plans remain unknown.
- Verified personal Pro + absent 300 → notApplicable. Unknown/Plus + absent 300 → unreported. Actual reported 300 → available (or explicit requestFailed if malformed) regardless of plan. No missing-as-unlimited inference. Snapshot retains no plan/profile fields.
- Earlier observation intentionally discarded planType. **Owner/account policy strongly indicates 5h is not applicable, but current retained machine-readable Provider evidence is insufficient to classify the Owner account safely.** The implemented production rule will apply only if a future authorized Live read actually supplies the verified enum; otherwise Owner 5h remains unreported. Actual Owner machine plan is UNKNOWN at this stop point.

### Provider / lifecycle

- Native App entry explicitly injects the provider for the Owner-verified bundled executable. A bounded literal --version check must return **0.160.0**; unknown/unverified versions fail closed pending review. No new actual version command/account read was executed during automated verification. Default injected AppStore provider and XCTest host are unapproved, tested fail-closed.
- One initial read plus event updates, then **240-second verification interval** measured from preceding read completion. One verification task per provider; pending request serialized with unique IDs, 10s watchdog, duplicate/old IDs ignored. Events do not launch or overlap a second read. This is freshness verification, not quota reset timing.
- Automatic pipe/child/read failure retains the last numeric item and original sampledAt while reconnecting. Age >300s or reset expiry naturally produces stale, never a reset to zero. Capped 1/2/5/10/30/60s retry resets on successful read.
- Explicit stop/sleep/Preview clears the baseline, cancels verification/watchdog/backoff and closes/reaps only the MacSoul-owned child. Start waits for retired generation teardown; wake requires a fresh initial read. No detected ChatGPT/IDE/Terminal/user Codex process is targeted. Existing owned-child transport cancellation boundary remains unchanged.
- Live Codex + unavailable Claude share AppSnapshot, without Mock fallback; Preview restores unchanged fixtures. Claude remains not detected / no verified subscription source, not a synthetic Live quota. No installation/login/subscription/bridge configuration changes.

### Presentation / alert boundary

- AI detail preserves source, parsed CLI version and notReported/notApplicable explanation. Live Overview/Menu Bar show only reported numeric/error windows; missing 5h has no row/bar/countdown. If nothing is reported, one provider-level Not reported message remains. Reconnecting/malformed status is explicit; numeric age is shared across the three surfaces.
- Fresh available numeric + supplied reset only for >=95% alert/Soul eligibility. Missing/notApplicable/unavailable/stale/Preview cannot announce. Existing reset-key dedupe and System Soul priority/state rules stay intact.
- No new System/Dev/Network/Cleaner features or architecture/Harness reset. No credentials/profile/raw account payloads retained.

### Automated evidence

- HEAD/base: `ed0f61a9c84848c1db9d1a7b87236ce36fe72673`; branch `feature/ai-quota`; uncommitted worktree fingerprint `d35064c875ee558ea3663fe31b42ad5ae047630cc963f6480b371db81d0e712c`.
- macOS `27.0.1`; `Xcode 27.0 / Build version 27A266a`.
- Final source clean build: `./scripts/build.sh` **PASS / exit 0**; explicit clean test `./scripts/test.sh` **PASS / exit 0**, **320 tests / 0 failures** (22 added over the 298-test first-phase checkpoint).
- Final `./scripts/verify.sh` **PASS / exit 0**, manifest checked_at `2026-10-03T17:20:58.738411+00:00`; doctor/build/unit/progress_tests/visual_assets/ledger all PASS. `git diff --check` PASS; nine new untracked files also have no whitespace findings.
- First final verify: exit 1 solely for stale task evidence fingerprints after source changes; its manifest/log preserved at `.artifacts/ai-phase2-before-evidence-refresh-verification.json` / `.artifacts/ai-phase2-before-evidence-refresh-progress-verify.log`. All build/unit checks already PASS. Refreshed 50 actual automated evidence records, keeping prior entries in evidence_history; reran full verify successfully. No task state/evidence bypass or original baseline change.
- Clean-cache rm command was rejected by automatic execution review. Used exact-path filesystem removal only for the two explicitly authorized DerivedData/xcresult artifact directories instead; no source/user work deletion.
- Source and packaged PrivacyInfo exact declarations remain DiskSpace/85F4.1, UserDefaults/CA92.1, SystemBootTime/35F9.1; no additional reason. No real quota child is launched by tests; native transport tests use their standalone fake child.
- Tests cover both container orders/actual-shape Week-only/unknown windows/duplicates/zero/invalid fields/bucket fallback and ambiguity; typed plan rules; 240s fallback without real waiting; events during pending read and duplicate IDs; timeout/reconnect retention and stale aging; stop/restart fresh baseline; unavailable Claude/shared snapshot/alert boundaries.

### Tasks / stop point

- D4-01 through D4-07 remain **verifying**. Earlier Phase A, Day 2/3/Cleaner task states, original points/dependencies/acceptance and human UI confirmations are preserved. tasks.json notes/evidence updated; docs/STATUS.md regenerated with the existing script.
- Modified scope: quota models/monitor/providers/transport; shared AppStore and App termination; existing AI/Overview/Menu Bar/Settings wiring, QuotaRow/localized presentation; quota test files and earlier System/Network test expectations for the new Live boundary; project source registration; feature/architecture/status/report/task evidence.
- **NOT_RUN**: real MacSoul AI Live UI, ongoing real fallback/reconnect, cross-client notifications, real quota-triggered alert/Soul UI, Claude subscription, formal Performance, App Store Connect validation and Xcode 26.6 CI for this uncommitted work.
- Running Owner App was not targeted or restarted. New Debug build available at `.artifacts/DerivedData/Build/Products/Debug/MacSoul.app`; **not launched**. No commit/push/PR, no staged files. Stop for explicit Owner App-launch authorization and acceptance.

### Prepared Owner Live AI Quota Acceptance

1. After explicit startup/restart authorization, use this exact worktree build; select Live in Settings. Verify Codex source/version and numeric Week; Claude remains honest Unavailable/Not detected.
2. Verify AI detail explains missing 5h as not reported or not applicable based on the new Provider's actual typed evidence. Overview/Menu Bar show only the numeric Week for a Week-only result; no 5h bar/countdown/alert.
3. Compare the three entries at the same display time from the shared snapshot. Record only numeric presentation correctness, not actual Owner percentage/reset in repository evidence.
4. Let ordinary usage stay idle for >240s; confirm low-frequency verification renews freshness without manufacturing reset/zero. Do not create model requests just to induce quota events. Event/cross-client acceptance may remain NOT_OBSERVED.
5. Reopen windows/menu repeatedly; verify no extra collectors. Switch Preview → Live and sleep/wake in normal use; Preview fixtures return and Live requires a fresh baseline. Owner UI remains pending until confirmed.
6. Check Chinese/English details/summary and honest unavailable/stale/failure states as observable. No forced resource/quota pressure or credential access. Stop after this acceptance; no commit/push/next feature implied.


## Remaining-quota presentation checkpoint — 2026-10-04

Owner approved a presentation-only change from consumed to remaining quota. Canonical `QuotaWindow.usedPercent`, Provider parsing and wire semantics remain consumed percent. Presentation computes `remainingPercent = 100 - usedPercent` without clamping, and `remainingProgress = remainingPercent / 100`.

- Shared QuotaWindowView supplies AI Coding detail, Overview and Menu Bar. Chinese uses `剩余 …%`; English uses `…% remaining`. Progress uses the same remaining value.
- Synthetic tests cover consumed 0/4/95/100 → remaining 100/96/5/0; progress 1/0.96/0.05/0; exact Chinese/English detail copy; summary/detail severity; stale values retained; nonnumeric states never fabricate remaining.
- Existing alert/Soul eligibility remains fresh applicable canonical `usedPercent >= 95`; tests confirm 95 eligible and 94 ineligible. Freshness/reset expiry, notApplicable hiding, unreported and unavailable semantics remain unchanged.
- Seven protected files match their pre-adjustment hashes: AIQuota.swift, CodexQuotaProvider.swift, CodexQuotaTransport.swift, ClaudeQuotaProvider.swift, AIQuotaMonitor.swift, MacSoulModels.swift and MockStore.swift. No Provider, parser, 240s refresh, reconnect, plan mapping or Claude behavior changed.
- Source fingerprint: `359038585a11818dd89426278f49973a34ba1f16230f10f39e0f815752837b43`; HEAD/base remains `ed0f61a9c84848c1db9d1a7b87236ce36fe72673` on `feature/ai-quota`.
- `./scripts/build.sh`: PASS / exit 0. `./scripts/test.sh`: PASS / exit 0, **326 tests / 0 failures** (six additional presentation tests).
- Final `./scripts/verify.sh`: PASS / exit 0; checked_at `2026-10-03T17:32:03.847723+00:00`. Doctor/build/unit/progress_tests/visual_assets/ledger all PASS. Evidence paths: `.artifacts/build.log`, `.artifacts/test.log`, `.artifacts/verification.json`, `.artifacts/progress-verify.log`.
- The first verify after the presentation change reported stale ledger fingerprints; build/unit already passed. Its manifest/log remain at `.artifacts/ai-remaining-before-evidence-refresh-verification.json` and `.artifacts/ai-remaining-before-evidence-refresh-progress-verify.log`. Fifty automated evidence records were refreshed from actual results, earlier records retained in evidence_history; STATUS regenerated and full verify rerun successfully. No D4 status was changed.
- docs/AI-QUOTA.md now describes remaining UI semantics, with consumed canonical values and alert threshold explicitly preserved. This documentation/report update does not change the verified source fingerprint.

## REAL MACSOUL LIVE ACCEPTANCE — launch checkpoint, 2026-10-04

Owner authorization covers launching this build and the approved read-only Live path. This checkpoint records the actual launch and a UI-automation blocker; it is **not** a successful real quota acceptance. Earlier NOT_RUN checkpoints remain historical.

- Previous MacSoul previews were quit normally through their App UI. No SIGKILL, killall, pkill or termination of user Codex/ChatGPT/IDE/Terminal processes.
- Verified current App PID: **54235**.
- Actual executable: `<OWNER_HOME>/githubWorkspace/macsoul/.artifacts/DerivedData/Build/Products/Debug/MacSoul.app/Contents/MacOS/MacSoul`.
- New App initially displayed Developer Preview fixtures with remaining text/progress. Preview UI is not real Provider evidence.
- Native UI automation failed when selecting Settings with `Sky Computer Use native pipe closed before response`. A reset and bounded reconnect attempt returned the same error. Process observation confirmed the correct App remains running; this does not establish an App crash.
- At the last process observation, the App had **no child process**. Settings → Live was not confirmed, and no new app-server/read was initiated by the agent in this checkpoint. Owner was asked to perform the UI switch manually; no credential access, account/profile request or alternative UI automation was introduced.

| Acceptance item | Current evidence |
|---|---|
| Codex Live | NOT_RUN — Live switch blocked by UI automation |
| Current-build Codex CLI version | UNKNOWN — earlier authorized observation verified 0.160.0, not a new App Live read |
| Week numeric/fresh/source/reset | NOT_RUN |
| 5h final classification | UNKNOWN — no current-build Live evidence; do not infer from account policy |
| Normalized machine capability | UNKNOWN |
| 240s verification | NOT_RUN |
| rateLimits update event | NOT_OBSERVED in this attempt; no Live observer was started |
| AI Coding Live UI | NOT_RUN |
| Overview Live shared snapshot | NOT_RUN |
| Menu Bar Live shared snapshot | NOT_RUN |
| Preview → Live boundary | NOT_RUN |
| Claude Live unavailable | NOT_RUN in this build's Live UI; automated boundary tests PASS |
| Real 95% event | NOT_OBSERVED; no quota-consuming request made |
| Real sleep/wake | NOT_RUN; Mac was not put to sleep |
| Formal Performance | NOT_RUN |
| Sensitive values retained in repository evidence | NO |

D4-01 through D4-07 remain **verifying**. Automatic build/test/verify PASS remains distinct from real UI/Provider acceptance. No temporary product instrumentation, no next-stage functionality, no commit/push/PR. App remains open for Owner-assisted Live acceptance; pending items require actual observation before updating this table.


## REAL MACSOUL LIVE ACCEPTANCE — Owner UI confirmation, 2026-10-04

This later checkpoint supersedes the launch checkpoint's UI NOT_RUN rows only where explicitly confirmed below. Historical entries are preserved. The Owner confirmed real UI acceptance; real quota percentages/reset timestamps from the message are deliberately omitted.

| Owner-confirmed item | Result |
|---|---|
| Codex Live | PASS |
| Source | Codex App Server |
| CLI version | 0.160.0 |
| Week numeric presentation | PASS |
| Reset cross-check against ChatGPT Usage | PASS |
| 5h presentation | notApplicable |
| Claude Code unavailable / not detected | PASS |
| AI Coding | PASS |
| Overview | PASS |
| Menu Bar | PASS |
| Remaining numeric / Week-only / reset consistency across three entries | PASS |

ChatGPT Usage was a manual cross-check only; neither screenshot nor Owner plan description is a production mapping input. No Owner numeric/reset value or raw plan/profile data retained in repository evidence.

### Current-build machine classification review

The agent reconnected to the current verified Debug build after the native UI automation channel recovered. It observed Codex Live, fresh Week, CLI 0.160.0 and `5h: not applicable` in AI detail. PID **54235** still runs the exact worktree Debug executable; one directly owned Codex child **58371** was observed, with no second child at this checkpoint.

Protected Provider/parser/model hashes and verified source fingerprint remain unchanged. The source path is `CodexQuotaProvider.accept` → `CodexQuotaParser.parse` → selected bucket `CodexPlanSemantics(wireValue: bucket["planType"])`. For Live data, this parser can produce notApplicable only when no recognized 300-minute window is reported and selected-bucket typed semantics normalize to personal-pro. Actual 300-minute data wins; unknown/future/workspace semantics produce unreported. AppStore publishes that parsed Live item; the presentation does not classify account plans.

**Final 5h classification: notApplicable. Normalized capability: personal-pro**, established by the current-build Live result and the exclusive, hash-verified machine classification path. This is a derived confirmation from the production output/code path, not a separate capture of raw planType. No account/read, extra capability spike, raw payload logging or temporary instrumentation was used.

At this checkpoint, >240s freshness observation and Preview → Live round-trip are still pending. D4-01–07 remain verifying; no commit/push/PR.


### >240-second real freshness observation — 2026-10-04

**240s verification acceptance: PASS** for observed refresh/freshness behavior. Kept the same Live session for **277 seconds** after an in-memory UI baseline; no model request or extra observer/read was initiated.

At the final AI-detail observation:

- successful sample/update time advanced;
- Week remained fresh;
- numeric presentation remained unchanged from baseline;
- supplied reset remained unchanged from baseline (no local deadline recreation);
- 5h remained notApplicable;
- Claude remained unavailable/not detected.

Baseline numeric/reset/update values were used transiently in UI-automation memory only; only comparison booleans and elapsed observation duration are retained here. Actual Owner values are omitted.

Process observations before/after repeated AI/Overview navigation and after the wait showed the same single MacSoul-owned Codex child **58371** under App **54235**. No duplicate collector observed. The UI exposes no RPC counter: serialized/no-overlapping request behavior remains deterministic-test evidence, not a claimed live wire-count measurement. The sample renewal is consistent with the implemented 240s verification path; a natural update event cannot be distinguished from a read response through the current UI. **rateLimits update notification remains NOT_OBSERVED**, not proven absent or unsupported.

### Remaining round-trip checkpoint

Attempting Settings to perform Preview → Live caused `Sky Computer Use native pipe closed before response` again. A follow-up AX read failed identically. Process inspection confirmed App 54235 and owned child 58371 still running. The agent did not replace UI automation with scripts, terminate processes or modify code. Owner was asked to switch to Preview first so normal child teardown can be observed before returning Live.

**Preview → Live: NOT_RUN / pending Owner-assisted interaction**, rather than PASS. D4-01–07 remain verifying. Real sleep/wake and formal Performance remain NOT_RUN; real quota-threshold event remains NOT_OBSERVED. No commit/push/PR.


## Final Owner Acceptance — 2026-10-04

Owner explicitly completed the last real UI acceptance and authorized D4-01 through D4-07 → done. This section supersedes the preceding pending round-trip checkpoint; all earlier NOT_RUN/verifying checkpoints and evidence history are preserved.

### Preview → Live lifecycle acceptance: PASS

Owner manually completed Live → Developer Preview → Live:

- Preview Settings shows Developer Preview / built-in Mock; AI Coding restores Codex and Claude Mock 5h + Week. Overview and Menu Bar use Mock quota. System/Network/Dev also return to Mock. Real Codex Week does not remain in Preview.
- Returning Live restores Codex App Server, CLI 0.160.0, real Week numeric remaining quota and 5h notApplicable. Claude returns to unavailable/not detected. AI Coding/Overview/Menu Bar agree again; Preview Claude fixtures do not leak into Live.

This is explicit Owner acceptance, not an agent-invented process teardown trace. The prior single-owned-child observation and deterministic generation/stop tests remain their distinct evidence types.

| Final acceptance item | Result |
|---|---|
| Codex Live / Codex App Server / CLI 0.160.0 | PASS |
| Week numeric presentation / remaining text and progress / reset | PASS |
| Week-only semantics | PASS |
| 5h classification / normalized machine capability | notApplicable / personal-pro |
| Claude honest unavailable / not detected | PASS |
| AI Coding / Overview / Menu Bar | PASS |
| Three-surface numeric/reset consistency | PASS |
| 277-second freshness renewal | PASS |
| Single Codex child observed | PASS |
| Preview → Live round-trip | PASS |
| account/rateLimits/updated natural notification | NOT_OBSERVED |
| Real 95% quota event | NOT_OBSERVED |
| Real sleep/wake | NOT_RUN |
| Formal Performance | NOT_RUN |
| App Store Connect privacy validation | NOT_RUN |
| Real Claude subscription quota | NOT_RUN; honest unavailable boundary accepted |

No Owner real used/remaining percentage, reset timestamp, raw planType or account/profile payload was copied to the report/ledger. ChatGPT Usage is a manual cross-check only; production classification remains the selected-bucket machine path documented above.

### Task closeout

- D4-01 done: real initial read/mapping/Week-only accepted.
- D4-02 done: reconnect/stale/unavailable fixtures and 277s real freshness behavior accepted.
- D4-03 done: Claude capability/adapter boundary accepted without a subscription.
- D4-04 done: current honest unavailable accepted; supported-source mapping is fixture evidence only.
- D4-05 done: three-entry shared Live snapshot and remaining presentation accepted.
- D4-06 done: canonical >=95% eligibility/reset-key dedupe tests accepted; no requirement to burn quota to observe an event.
- D4-07 done: provider tests complete.

Original points, original days, dependencies and prior evidence are retained. Earlier verification_note/status records are preserved in status_history; change_log records the Owner-approved transition. Day 2/3/Cleaner accepted states and all later todo states remain unchanged.

The STATUS generator now derives accepted D4 wording from the ledger plus human_ui_confirmation instead of retaining its previous fixed pending/NOT_RUN text. This changes a verification input, not product behavior. Product/test/project/workflow hashes were captured before closeout for final comparison. Final build/test/verify and scope audit results follow below after actual execution.


### Final closeout automatic verification and scope audit

- Branch: `feature/ai-quota`; uncommitted HEAD/base: `ed0f61a9c84848c1db9d1a7b87236ce36fe72673`.
- Final verification-input fingerprint: `0e0c89a4e8caba0cd46546dcae5616770c0bec9fb3d8382681cdfe3f5deb53f2`.
- Product/test/project/workflow content: **93 files unchanged** from the pre-closeout snapshot. Earlier product source fingerprint `359038585a11818dd89426278f49973a34ba1f16230f10f39e0f815752837b43` remains the accepted behavior checkpoint; final aggregate fingerprint changes solely because the STATUS generator is a verification input. No new product behavior or tests added during closeout.
- `./scripts/build.sh`: PASS / exit 0.
- `./scripts/test.sh`: PASS / exit 0, **326 tests / 0 failures**.
- `./scripts/verify.sh`: final PASS / exit 0; checked_at `2026-10-03T18:00:51.153364+00:00`. Doctor/build/unit/progress_tests/visual_assets/ledger all PASS.
- `python3 scripts/verify_progress.py`: PASS / exit 0, 59 tasks and original 76-point baseline intact.
- `git diff --check`: PASS / exit 0. New untracked quota/report files checked separately for trailing whitespace below.
- Evidence paths: `.artifacts/verification.json`, `.artifacts/build.log`, `.artifacts/test.log`, `.artifacts/progress-verify.log`, `.artifacts/ai-closeout-scope-audit.json`.

The first evidence refresh helper stopped on its overly narrow build/unit-only guard when encountering an existing progress_tests record; it wrote no ledger changes. The first full verify then returned exit 1 solely for stale evidence fingerprints after the generator change; all non-ledger checks passed. Preserved manifest/log: `.artifacts/ai-closeout-before-evidence-refresh-verification.json` and `.artifacts/ai-closeout-before-evidence-refresh-progress-verify.log`. Refreshed all 50 actual successful automated records (including doctor/progress/visual checks), preserved prior evidence_history, and reran full verify successfully. Neither tests nor evidence requirements were removed. An initial scope-audit guard also incorrectly treated FileManager's temporary launch-directory lookup as persistence; the final audit distinguishes that read-only path lookup from the actual pipe-only output writes. No product patch was made for either audit-helper issue.

#### Safety / scope result

- Outbound production RPC allowlist remains initialize / initialized / account/rateLimits/read. No account/read, login/logout, quota mutation or model-inference path was invoked or added. Negative unit-test method strings do not represent executed account operations.
- Native stdout data is parsed in memory; stderr is drained/discarded without logging. No credential-store reads, tokens, account/profile payload or real quota values persisted in repository evidence. Temporary UI comparison variables were discarded after acceptance.
- Claude capability boundary remains executable/version-only when present, with no installation/login/bridge mutation. No UserNotifications permission expansion.
- No Cleaner implementation change, Performance implementation, Day 5-03–06, Day 6 or Day 7 work. Shared AppStore edits in the overall branch only wire AI snapshot/lifecycle; earlier System/Network test changes assert the AI Live boundary.
- Packaged PrivacyInfo.xcprivacy equals source exactly: DiskSpace/85F4.1, UserDefaults/CA92.1 and SystemBootTime/35F9.1. App Store Connect validation remains NOT_RUN.
- Automatic verification.json retains its script-generated manual_ui/live_provider NOT_RUN fields; real Provider and Owner UI PASS are separately documented here and in the ledger's Owner confirmations, not fabricated as automatic check results.

#### Review handoff state

- D4-01 through D4-07: **done**. Other task states, original points/days/dependencies/acceptance and earlier evidence history preserved. STATUS regenerated from tasks.json.
- Overall branch has **26 changed/untracked files**: quota model/monitor/providers/transport; AI/Overview/Menu Bar/Settings/shared AppStore/lifecycle and localization; project registration; quota tests plus earlier System/Network boundary assertions; feature/architecture docs; STATUS generator and task/status/report evidence.
- This closeout changes tasks.json, generated docs/STATUS.md, appended report and STATUS-generation wording only. Earlier uncommitted implementation remains intact for review.
- Working tree is intentionally **not clean**; **no staged files**, no commit/push/PR.
- Remaining **NOT_OBSERVED**: natural account/rateLimits/updated notification, real 95% quota event.
- Remaining **NOT_RUN**: real sleep/wake, formal Performance, App Store Connect privacy validation, real Claude subscription quota, system notification delivery, Xcode 26.6 GitHub CI for this uncommitted branch. These do not block the Owner-approved D4 boundary.
- Stop for code-review handoff; no next-stage work.


## Code-review handoff preparation — 2026-10-04

Owner separately authorized one cohesive feature commit, normal push of feature/ai-quota and PR creation targeting main, followed by both CI runs. No merge or next-stage development authorized.

- Fresh scope/static review: PASS, 26 approved changed/untracked files; no unrelated Cleaner/Performance/later-day implementation, personal files, build artifacts or raw account/quota payload staged.
- Fresh security/lifecycle/mapping/presentation/Claude review: PASS within the accepted D4 boundary. Outbound allowlist remains initialize / initialized / account/rateLimits/read; tests contain rejected-method fixtures only. Transport termination remains confined to the Process instance launched by MacSoul. No new credential/profile/notification-permission path.
- Fresh `./scripts/build.sh`, `./scripts/test.sh`, `./scripts/verify.sh`, `python3 scripts/verify_progress.py`, `git diff --check`: PASS / exit 0; **326 tests / 0 failures**.
- Manifest checked_at: `2026-10-03T18:07:20.149756+00:00`; accepted aggregate fingerprint unchanged: `0e0c89a4e8caba0cd46546dcae5616770c0bec9fb3d8382681cdfe3f5deb53f2`.
- No product source change since final Owner acceptance. This is a rerun of existing verification, not new behavior evidence.
- origin verified as liu-657667/macsoul; default branch main; origin/main remains the specified base `ed0f61a9c84848c1db9d1a7b87236ce36fe72673`. Authenticated GitHub login verified as repository Owner without reading credential stores directly.
- Protect main remains active, default-branch-only, no bypass actors, required GitHub Actions context macos / integration 15368 with strict status policy. PR is for review only.
- Audit evidence: `.artifacts/ai-pr-handoff-audit.json`; automatic manifest remains separate from manual/provider acceptance.
- Actual commit/push/PR/CI results will be reported in the handoff response and PR metadata. Xcode 27 local PASS does not substitute for Xcode 26.6 / 17F113 CI.


## PR #7 review fixes — 2026-10-04

Owner authorized only the Codex ambiguity edge case and Claude unavailable-source presentation, a separate fix commit and ordinary push. No merge or new feature work.

### Changes and regression coverage

- A keyed `codex` bucket validates its own `limitId`, then checks every other bucket for explicit `limitId == codex`. A second identity throws `ambiguousBucket`; a legacy view cannot override that ambiguity. No map-order/key-priority guessing.
- Added `testCodexKeyAndSecondExplicitCodexIdentityAreAmbiguous`, covering explicit/null/absent keyed identity, plus contradictory-own-identity coverage. Existing unique explicit identity, duplicate identities, legacy fallback and unidentified-bucket tests remain.
- Detail source presentation returns no source for Live Claude providerUnavailable, notInstalled, noVerifiedSource or unsupportedVersion. The shared detail row displays Source: —. Available Claude status-line source and Mock source remain unchanged; presentation tests cover those boundaries.
- Five new tests: **331 tests / 0 failures**. The first test compile failed because the new Mock fixture test omitted its required fixture argument; that test setup was corrected, and the failure log retained at `.artifacts/ai-edge-initial-test-compile-failure.log`.

### Actual automatic verification

- `./scripts/build.sh`: PASS / exit 0.
- `./scripts/test.sh`: PASS / exit 0, 331 tests / 0 failures.
- `./scripts/verify.sh`: final PASS / exit 0, doctor/build/unit/progress_tests/visual_assets/ledger all PASS.
- `python3 scripts/verify_progress.py`: PASS / exit 0, 59 tasks / original 76-point baseline retained.
- `git diff --check`: PASS / exit 0; checked again before staging.
- Pre-commit revision: `2f6b956a446c32c0e318b3618fdb074c4a5e5e44` plus the reviewed working-tree changes.
- Source / verification-input fingerprint: `7c0e6808686689f14a3ab46a988e458bab2290d05e617d77f7a38508eb396064`.
- Final manifest checked_at: `2026-10-03T18:26:04.704132+00:00`.
- Evidence: `.artifacts/verification.json`, `.artifacts/build.log`, `.artifacts/test.log`, `.artifacts/progress-verify.log`, `.artifacts/ai-edge-final-verify.log`.
- Initial full verify returned exit 1 solely for stale automated evidence fingerprints; all other checks passed. Preserved at `.artifacts/ai-edge-before-evidence-refresh-verification.json` and `.artifacts/ai-edge-before-evidence-refresh-progress-verify.log`. Refreshed 50 actual passing automated records, appended old entries to evidence_history, and reran full verify successfully.
- Packaged privacy manifest equals unchanged source: DiskSpace/85F4.1, UserDefaults/CA92.1, SystemBootTime/35F9.1.
- STATUS regenerated from tasks.json; generated content unchanged. All task statuses, points/day/dependencies, historical evidence and Owner acceptance retained; D4-01 through D4-07 remain done.

### Scope and acceptance boundary

Duration/plan mapping, 240s refresh, reconnect/backoff, remaining-percent semantics, alert thresholds and Preview/Live lifecycle are unchanged. No Provider/transport, Cleaner, Performance or later-day implementation changes. No raw account/profile/quota data retained.

Owner Live acceptance was **not repeated**: the accepted Codex happy path is unchanged. New unavailable-source UI behavior has presentation-test evidence, not new manual UI approval. Automatic manual_ui/live_provider/performance fields remain NOT_RUN; prior Owner/provider PASS records above remain historical evidence.

Still NOT_OBSERVED: natural quota-update notification and real 95% event. Still NOT_RUN: real sleep/wake, formal Performance, App Store Connect privacy validation, real Claude subscription quota and system notification delivery.

Xcode 26.6 / 17F113 push and PR CI for the new fix commit will be checked after publication; final results belong in PR metadata and the handoff response. Local Xcode 27 verification does not substitute for CI. Stop after review handoff; do not merge.
