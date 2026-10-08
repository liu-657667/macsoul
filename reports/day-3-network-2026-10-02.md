# Day 3 Network — 2026-10-02

> 公开文本中的 Owner-home 路径前缀已替换为 `<OWNER_HOME>`；命令含义、日期、哈希和历史结果保留。原私有证据与 Git 历史未改写；此项与 distributed App package privacy 分别记录。

Branch: `feature/network`
Base / current uncommitted revision: `1e3eda82e051abe51bc4668250119b35cfed136b`
Source/project/script fingerprint: `a638365f05ce3d2bf278754b2de4ea99dbd4eb6b80d810dcc35ae03b0ca27681`
Verification recorded at: `2026-10-01T17:22:55.943246+00:00` (UTC; local date 2026-10-02).
Environment: macOS 27.0, Xcode 27.0, Build version 27A266a; Debug, macOS 13 deployment target.

Scope: D3-04 / D3-05 / D3-06 and Network portion of D3-07. No commit/push/PR. Prior Day 2 and Dev implementation/manual evidence retained. Network does not drive Soul. No AI quota, Cleaner, process termination or system-network configuration work.

## AUTOMATED

| Command/check | Result | Evidence |
|---|---|---|
| `./scripts/build.sh` | PASS, exit 0 | `.artifacts/build.log` |
| `./scripts/test.sh` | PASS, exit 0; **105 tests / 0 failures** | `.artifacts/test.log`, `.artifacts/MacSoulTests.xcresult` |
| `./scripts/verify.sh` | PASS, exit 0; doctor/build/unit/progress/assets/ledger | `.artifacts/verification.json` |
| `git diff --check` | PASS, exit 0 | reviewed tracked diff; new files separately inspected |
| Source and packaged PrivacyInfo | PASS; three existing reasons unchanged | source + Debug App `Contents/Resources/PrivacyInfo.xcprivacy` |

The original 68 tests remain; **37 Network tests** were added. Existing Live System/Dev tests inject a fake path with no online events so unit tests never access the internet. The earlier assertion that Live mode retains the Mock IP was updated for the new authorized boundary; quota fixtures remain Mock and returning to Preview restores the established IP/fixtures. No existing test was removed.

Coverage: legal family-specific IP parsing, malformed/oversized responses, HTTP versus timeout, fresh/stale/never-success semantics, independent IPv4/IPv6 outcomes, 300s cache and expiry, debounce, meaningful interface changes, offline-to-online, manual cooldown, in-flight trigger coalescing, uppercase/lowercase proxies and mismatch, credentials stripped, CFNetwork HTTP/HTTPS/SOCKS/PAC, absent/unavailable proxy separation, context comparison including same-count different bypass lists, tunnel-only naming, reachable 200/401/403/500, timeout/transport states, 60s success cadence, capped backoff/reset, pending-probe cancellation, toggle ON, repeated start/stop and new baseline, stale callback rejection, shared Store boundary and repeated window appearances. Injected monotonic clock/sleeper avoids real 5/15-minute waits. Native NWPath construction itself is validated by compilation/read-only observation; deterministic fakes exercise monitor state/lifecycle. These are not automated visual acceptance.

Development verification history (retained as failures, not relabelled PASS): initial XCTest compilation exited 65 because Swift could not infer a Void checked continuation in the test sleeper; explicit continuation typing fixed it. A subsequent 100-test run exited 65 with 5 assertions failing in three new tests: ambiguous IPv4 spelling and cache/manual tests advancing fake time before the batch completed. IPv4 octets now reject leading-zero ambiguity; tests await the actual in-flight batch before advancing time. The next 100-test run passed; five additional cancellation/backoff/context tests bring the final total to 105. Final verification used the fingerprint above.

### Architecture and scheduling

- One shared `NetworkMonitor` → `NetworkSnapshot` in `AppSnapshot` → Overview / Network / Menu Bar. No View calls a shell or HTTP provider. UI reads one shared value, not independent network sources. System SensorHub and DevMonitor continue their existing work; Network Refresh does not restart either.
- One effective `NWPathMonitor`, utility queue, MainActor bridge. start/stop are idempotent. Preview/sleep cancels work and clears conclusions; wake creates a new path baseline. Lifecycle/generation guards discard late callbacks/results. Cancelled batches finish before new batches start; deinit cancels pending timers/tasks and native path provider cancellation stops callbacks.
- Path reads status, used interface types, expensive/constrained and IP-family capability only. No SSID/BSSID, location, DNS or route inspection. `other` is not labelled VPN.
- Public IP provider: ipify family endpoints `https://api.ipify.org` and `https://api6.ipify.org`, isolated in `PublicIPProvider`. They are provider-observed exits, not absolute truth or physical location. IPv4/IPv6 have separate address/time/source/freshness/failure fields. Region = **Not collected** in Live; no Example region or Mock IP survives Live entry.
- HTTP: ephemeral URLSession; request timeout **4s**, resource timeout **5s**; cookie storage, credential storage and cache nil; cookies disabled; redirects declined. Bounded streaming IP GET body **1024 bytes** including Content-Length and incremental checks. HEAD probes retain no body. Task cancellation explicitly invalidates the underlying session; all sessions invalidate at completion. No Authorization, account tokens, project data, hostname, username or environment upload.
- Public IP cache **300s**, refreshed on Live path baseline, expiry, offline→online/meaningful path change and manual refresh. Path debounce **0.75s**. One active two-family batch; duplicate triggers coalesce. Network manual cooldown **4s**. Failure preserves previous IP only as **Stale**, with error/time visible; no previous success is Unavailable/Timeout/failure, not Mock.
- Local facts read initially, on path/manual refresh and about **60s**: selected App environment proxy keys, CFNetwork system settings, and up tunnel-like names from `getifaddrs`. Provider work runs off MainActor.
- Uppercase HTTP_PROXY/HTTPS_PROXY/ALL_PROXY/NO_PROXY take precedence over lowercase; disagreement is explicit. Raw proxy input, userinfo, path/query/fragment never enter Snapshot/UI/report. Snapshot stores only scheme/host/port and bounded display summaries. Bypass lists are counted and compared by a canonical digest so different same-count lists do not claim Same. App environment is not the current Terminal shell. Context differences are informational, not errors.
- CFNetwork system API = `CFNetworkCopySystemProxySettings()`. HTTP/HTTPS/SOCKS, PAC origin, auto discovery and exceptions count are represented; No proxy is distinct from API unavailable or invalid setting. PAC content is not downloaded or executed by this detector; detailed PAC path/query are omitted for privacy.
- Tunnel prefixes: utun/tun/tap/ppp/ipsec; deduplicated up interface names only. Text explicitly says **Tunnel interfaces are hints, not proof of VPN routing**. No VPN brand/control or route proof.
- Connectivity endpoints (HEAD): GitHub `https://api.github.com/zen`; OpenAI `https://api.openai.com/v1/models`; Anthropic `https://api.anthropic.com/v1/models`. Any HTTPS HTTP response (including 401/403/405) = transport reachable. Authentication/product health **NOT_TESTED**. No inference, prompts or paid API call.
- Success cadence **60s**; failure backoff **60 / 120 / 300 / 600 / 900s**, capped. Meaningful path changes reset backoff/debounce. Offline/connection-required paths do not issue HTTP. One task per endpoint; no per-second probe loop. A cancellable timer sleeps to the nearest deadline rather than polling every second.
- Settings probe toggle defaults **ON** unless previously saved; only works externally in explicit Live mode. OFF cancels pending probes and replaces green results with Disabled; ON schedules new results. Public IP remains independent of probe toggle and its external requests are explicitly disclosed. Preview sends no external requests.

### UI wiring (not yet owner-accepted)

Network grouped sections: path, public IPv4/IPv6/source/times/Region, separate App/system proxy contexts, tunnel hints, transport-only probes with status/latency/HTTP/time and Refresh. Overview has compact IPv4/path/system-proxy/tunnel/connectivity summary. Menu Bar keeps only shared IP/proxy/tunnel summary. Both use `NetworkSummary` and the same `store.snapshot.network`.

Global Live label: **SYSTEM + DEV + NETWORK LIVE · AI MOCK** / **系统 / 开发环境 / 网络实时 · AI 模拟**. System and Dev stay Live; AI Coding stays Mock; Cleaner stays Not Run. Existing Preview fixtures remain unchanged. English/Chinese Network labels added through the established localization mechanism. No redesign of other sections.

## REAL OBSERVATION

Executed the actual model/provider/monitor sources as a read-only, explicit-opt-in runner; `.artifacts/network-observation.json` stores only sanitized observations. Command (exit 0):

```bash
swiftc MacSoul/Models/MacSoulModels.swift MacSoul/Models/SystemSensors.swift MacSoul/Models/SystemDetails.swift MacSoul/Models/ShellRunner.swift MacSoul/Models/DevEnvironment.swift MacSoul/Models/ListeningPorts.swift MacSoul/Models/NetworkSnapshot.swift MacSoul/Models/NetworkProviders.swift MacSoul/Models/NetworkMonitor.swift scripts/observe-network.swift -o .artifacts/observe-network
.artifacts/observe-network --allow-external-requests > .artifacts/network-observation.json
```

- Path: **Connected**, interfaces **Wi-Fi**, expensive **false**, constrained **false**.
- IPv4 detected **YES**; IPv6 detected **NO**, current failure **Transport failed**. Sources: ipify / api.ipify.org and api6.ipify.org. IPv6 failure does not erase IPv4. No full public IP recorded.
- App environment proxy detected **NO**; system proxy detected **YES**; **Different proxy contexts**. Both native reads available. No proxy host, username or password recorded.
- Tunnel hint count **11**: utun0, utun1, utun10, utun2, utun3, utun4, utun5, utun6, utun7, utun8, utun9. VPN routing **NOT_PROVEN**.
- Manual Refresh updated both families' attempt times, monitor starts remained **1**. This is the model/provider observation, not a click/visual PASS.

| Service | Transport state | HTTP | Observed latency | Auth |
|---|---|---:|---:|---|
| GitHub | Reachable | 200 | 1258 ms | NOT_TESTED |
| OpenAI | Reachable | 401 | 1126 ms | NOT_TESTED |
| Anthropic | Reachable | 405 | 1258 ms | NOT_TESTED |

These timings are one ordinary network observation, not benchmark/SLA evidence. In particular Anthropic HEAD returned 405; that is a server response proving HTTP/TLS reachability, not API authentication or full service health. No account credential was used. No network configuration or user resource stress was changed.

## MANUAL UI

**PENDING / NOT_RUN for the new Network UI.** Earlier System/Soul/Dev owner approvals remain historical evidence and are not reused as Network approval. Owner must inspect Live Network, actual exit-IP agreement, IPv6 failure, proxy contexts, hint wording, probe update/OFF/ON, Refresh, three surfaces' consistency and unchanged System/Dev/AI boundary. Unit state tests do not prove tooltip/layout/click behavior.

Acceptance build/restart: preparation below; old running App must be normally exited only after owner confirmation. Default launch mode remains Developer Preview; select Live System to enable these external requests. Native observations above used the explicitly enabled observer, not the old running App.

## PRIVACY

- Review found no network code path supplying account credentials/Authorization, uploading process environment/project content or logging response bodies. Proxy userinfo/query/path is removed before publication. Failure output is categorical, never raw error/userInfo or URL payload.
- Cookie/credential/cache persistence disabled; cancellation is explicit; response size bounded; UI does no provider work; debounce/coalescing prevents path-trigger storms; OFF stops pending probes.
- Existing **DiskSpace/85F4.1**, **UserDefaults/CA92.1**, **SystemBootTime/35F9.1** retained exactly in source and packaged App. No additional Required Reason API category identified for Network.framework, CFNetwork proxy settings, getifaddrs or URLSession against Apple's current listed APIs; no unsupported privacy reason added. No new entitlement or location permission.
- No Wi-Fi SSID/BSSID, precise location, route/DNS/firewall edits, VPN control, sudo, packet capture, traceroute or network speed test.

## PERFORMANCE

**Formal Performance measurement: NOT_RUN.** Deadline/event-driven structure and unit tests do not prove the background CPU/memory budget. No Instruments, Release sustained measurement or SLA claim.

## NOT_RUN / NOT_IMPLEMENTED

- Owner Network manual UI: pending; offline/path-change correctness fake-tested, not tested by disrupting this Mac's network.
- Live AI Provider: **NOT_RUN**; AI fixtures unchanged.
- Formal Performance: **NOT_RUN**.
- Memory Pressure real Critical: **NOT_OBSERVED** (historical real Warning acceptance retained); no artificial exhaustion/stress.
- Region/ASN/ISP: **NOT_IMPLEMENTED / Not collected**.
- VPN routing proof/control, firewall, process termination, port conflict detection, project-aware IDE SDK: **NOT_IMPLEMENTED**.
- No artificial CPU/memory/battery stress; no Wi-Fi disconnect, VPN toggle, proxy/DNS/route modification, user project launch or account login.

## Task ledger and working tree

D3-01/02/03 remain **done**. D3-04/05/06/07 are **verifying**, waiting for owner Network UI approval. All Day 2 done states and original plan points retained. Current passing regression evidence refreshes retained DONE tasks to this fingerprint; prior evidence is preserved in `evidence_history`, not overwritten. `docs/STATUS.md` was generated with the existing script.

Tracked changes: Network models/providers/monitor, shared Store/model fields, Network/Overview/Menu Bar/Settings wiring/localization, project references, Network tests and fake-path injection in prior Live tests, architecture/status/ledger/report and observer documentation/script. No System/Dev provider/parser/classifier/sampling logic changed. No source/asset/Harness recreation; the existing deterministic project generator only adds the new Swift file references. No credentials, personal config or build outputs staged; **nothing is staged and no commit/push/PR**.

## Primary references checked

- [ipify family-specific endpoints](https://www.ipify.org/): IPv4 and IPv6 requests isolated and both validated.
- [Apple NWPathMonitor cancel](https://developer.apple.com/documentation/network/nwpathmonitor/cancel()): cancel old monitoring before new lifecycle.
- [Apple ephemeral sessions](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/ephemeral) and [credential storage](https://developer.apple.com/documentation/foundation/urlsessionconfiguration/urlcredentialstorage): explicitly disable persistence/storage.
- [Apple CFNetwork proxy APIs](https://developer.apple.com/documentation/cfnetwork/proxy-types) and [getifaddrs](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/getifaddrs.3.html): local native facts only.
- [Apple Required Reason API list](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype): retain supported existing categories, no guessed addition.

## Prepared acceptance bundle

- Verified App: `<OWNER_HOME>/githubWorkspace/macsoul/build-preview/MacSoul.Network.kZJlBU/MacSoul.app`
- Copied executable SHA-256: `2f65cd8bfe44bcd778fbf897cab88eca41c12965a1df32f73c4f3b3d2429e4d3` (matches current Debug build).
- Launch: **PENDING**, owner confirmation required to normally exit old PID 87093 at `build-preview/MacSoul.LvD8Hy/MacSoul.app`. No process was terminated.

## Owner-authorized launch

Owner approved only normal restart of PID 87093. Exact old executable identity was checked, SIGTERM sent and exit confirmed; no other process was terminated and no SIGKILL used. The prepared binary hash and source fingerprint were rechecked before launch.

- App: `<OWNER_HOME>/githubWorkspace/macsoul/build-preview/MacSoul.Network.kZJlBU/MacSoul.app`
- New PID: **50388**
- Branch: `feature/network`; HEAD/base `1e3eda82e051abe51bc4668250119b35cfed136b`; Network changes uncommitted, nothing staged.
- Default initial mode is Developer Preview; owner should select Settings → Live System. Network observations above come from this same source in the explicit Live observer. App UI acceptance remains PENDING.


## Network i18n / presentation follow-up — 2026-10-02

Owner reported Chinese/English mixing while Network manual acceptance is still open. This follow-up changes **only** `MacSoul/Theme/MacSoulTheme.swift`, `MacSoul/Views/Network/NetworkView.swift` (including its existing presentation extensions), `MacSoulTests/NetworkTests.swift`, and ledger/generated status/report evidence. Earlier Network implementation remains uncommitted and intact.

### Display changes

- Added Chinese labels for Status → 状态, Context → 上下文, and Monitoring… → 监测中…. Retained IPv4 更新时间 / IPv6 更新时间, 未采样 and 未采集.
- Network path/interface/failure/probe enums now have explicit `MacSoulLanguage` presentation mapping; Network UI does not display enum raw values. Technical brands, URLs, interface names, HTTP status codes and proxy addresses stay unchanged.
- Localized composite proxy summaries (for example HTTP / 自动发现), and connectivity counts even while path monitoring is not yet online. The original disabled/offline/count distinctions and public-IP TTL/error rules are preserved.
- Audited Network path, expensive/constrained, IP freshness/failure, proxy contexts, tunnel, probe states, refresh and explanatory footnotes. Every literal presentation translation key used in NetworkView has a Chinese mapping. Source label now explicitly says 来源 in Chinese.
- Shared `MacSoulLanguage.dateTime` / `sampledTime` uses Foundation `Date.FormatStyle` with explicit application locale (`zh_CN` / `en_US`), and an injectable time zone for deterministic tests. It does not read the system locale to choose language. Network IPv4/IPv6 and probe timestamps use this helper; future Overview/Menu Bar timestamps can reuse it. No DateFormatter is constructed in Views.
- Same UTC fixture renders Chinese `2026年10月2日 1:30:00`, English `Oct 2, 2026 at 1:30:00 AM` (locale punctuation/space follows Foundation). Existing AppStorage/environment language propagation remains unchanged and drives rerender without restart. Pure presentation tests verify alternating languages on the same reading; actual in-App language switching is **MANUAL UI PENDING**, not automated PASS.

### Tests and verification

Added **12 presentation tests** covering labels, every path/interface/failure/probe state, both date locales, language rerender with unchanged readings, proxy contexts/composite summaries, technical names, IP TTL/stale/error preservation, connectivity disabled/offline/count and tunnel summaries.

- `./scripts/build.sh`: **PASS**, exit 0.
- `./scripts/test.sh`: **PASS**, exit 0; **117 tests / 0 failures** (105 prior + 12 presentation).
- `./scripts/verify.sh`: **PASS**, exit 0; doctor/build/unit/progress/assets/ledger all PASS.
- `git diff --check`: **PASS**, exit 0.
- Verification time: `2026-10-01T17:40:07.575703+00:00`; HEAD/base `1e3eda82e051abe51bc4668250119b35cfed136b`; source fingerprint `1f1a3d62f00e5a1cbf933147712b0da688c56b95dd1dcf4d2dbecea728689a3a`.
- Logs/results: `.artifacts/build.log`, `.artifacts/test.log`, `.artifacts/MacSoulTests.xcresult`, `.artifacts/verification.json`.

### Network behavior guard

SHA-256 before/after **identical** for NetworkMonitor.swift, NetworkProviders.swift, NetworkSnapshot.swift and MockStore.swift. Baseline/result: `.artifacts/network-i18n-before.json`, `.artifacts/network-i18n-hashes.json`.

- `MacSoul/Models/NetworkMonitor.swift`: `fa6883fa1a3822e9fd0417e2c13eb9971e15749800d197caac1a8558c76b15b3` (unchanged).
- `MacSoul/Models/NetworkProviders.swift`: `35ed78628939c68751dbad20fb0eb183105a145dd6487a98698a83b643f148da` (unchanged).
- `MacSoul/Models/NetworkSnapshot.swift`: `6740a520c483becdd93914d9a1236f3ddc027c19b005cdd05ab7a4727e9fd789` (unchanged).
- `MacSoul/Models/MockStore.swift`: `f83d6a6a6a537e7f544c2527663830d7852ded0c085358e35bd6428e2bde5a93` (unchanged).

These unchanged files cover NWPathMonitor, URLSession, public-IP/proxy/tunnel providers, endpoints, timeouts, TTL, debounce, probe state machine/backoff, cadence, refresh and Snapshot/store semantics. No new external observation calls or network configuration changes were performed for this presentation follow-up.

D3-04/05/06/07 remain **verifying**; prior Day 2/Dev manual acceptance and original ledger points are retained. Updated current regression evidence preserves prior evidence in history. Formal Performance and Live AI Provider remain **NOT_RUN**, Memory Pressure Critical remains **NOT_OBSERVED**. No commit, push or PR.

### Prepared bilingual acceptance build

- App: `<OWNER_HOME>/githubWorkspace/macsoul/build-preview/MacSoul.NetworkI18n.a7x0bg8b/MacSoul.app`.
- All 11 packaged-file hashes match the verified Debug build, including `MacSoul.debug.dylib` (not merely the unchanged Debug launcher executable).
- Debug implementation SHA-256: `df94a394548bef76ea1e98df0c60463931410c360ef14209b28b9a9c3fa60b18`.
- Restart **PENDING** owner confirmation for only old PID 50388; no process has been terminated in this follow-up. Chinese/English Network UI acceptance remains pending.


### Owner-authorized i18n build launch

Owner authorized normal restart of PID 50388 only. Its exact executable identity was confirmed; SIGTERM exited it successfully. No SIGKILL and no other process termination. The prepared bundle hashes and current source fingerprint were checked before launch.

- New App: `<OWNER_HOME>/githubWorkspace/macsoul/build-preview/MacSoul.NetworkI18n.a7x0bg8b/MacSoul.app`
- New PID: **65382**
- Branch: `feature/network`; source remains uncommitted, nothing staged.
- Chinese/English Network UI and immediate language switching: **PENDING owner acceptance**. No automated or manual visual PASS inferred from launch.


## Native connectivity Switch / presentation refinement — 2026-10-02

Owner requested presentation refinements only; Network manual acceptance remains open. Changed source paths in this follow-up: `MacSoul/Views/Settings/SettingsView.swift`, `MacSoul/Views/Network/NetworkView.swift` (presentation extensions included), `MacSoul/Theme/MacSoulTheme.swift`, `MacSoulTests/NetworkTests.swift`. Ledger/report/generated STATUS current evidence refreshed; prior evidence retained.

### Settings Switch

Native SwiftUI `Toggle` with `.toggleStyle(.switch)` and `.labelsHidden()`, positioned at the right of an HStack; title and both request explanations remain on the left. Localized accessibility label and hint retained on the Toggle, so standard keyboard/accessibility behavior is provided by the native control. Visual, keyboard and VoiceOver acceptance is **MANUAL PENDING**, not an automated PASS.

The binding still calls the existing `store.setConnectivityEnabled`. Store key `macsoul.connectivityEnabled` and absent-preference default **true/ON** are untouched. No monitor or storage implementation changed. A previously persisted OFF preference is respected, not reset to ON.

### Localization / presentation

- 高流量成本网络 / Expensive network; 低数据模式 / Low Data Mode. Existing NWPath expensive/constrained values are simply relabelled, not reinterpreted as network failure or performance.
- Probe checking → 正在探测…; timeout → 探测超时. Reachable, transport failure and disabled remain 网络可达 / 传输失败 / 探测已关闭.
- Same proxy contexts → 代理上下文一致; different contexts remains 代理上下文不同. No system proxy → 无系统代理; unavailable remains 不可用. Empty tunnel hint → 未发现类隧道接口, without claiming VPN routing.
- Public IP footnote explicitly describes provider-observed exit address, not physical device location. Status/Context/Source, IPv4/IPv6 update labels, Region 未采集 and technical strings retain correct localization from the prior follow-up.
- Probe timestamps now carry 更新时间. `networkLabel("Updated")` scopes this noun wording to Network; shared Quota/System `Updated` copy remains 更新于. 上次更新时间 is mapped as well.
- Existing shared `MacSoulLanguage.dateTime`/`sampledTime` follows explicit `zh_CN` / `en_US`, independent of system locale. Chinese hour now uses two digits: fixed UTC fixture `2026年10月2日 01:30:00`; English retains Foundation `Oct 2, 2026 at 1:30:00 AM` style. Existing language environment/AppStorage propagation is unchanged; no View creates DateFormatter.
- Overview and Menu Bar both continue using the same NetworkSummary/presentation functions. Overview badge/title translate 网络 / 实时; Menu Bar IP abbreviation remains technical. No changes to System/Dev/AI implementation or presentation.

### Tests

Added **5 tests** (previous 117 → **122 total**, 0 failures; 17 more than the original 105-test Network baseline). Updated existing presentation expectations for the owner-approved terminology/two-digit Chinese time; no test deleted.

New coverage:
1. Chinese/English expensive and Low Data Mode labels.
2. Network labels/source/update/context and preservation of other sections' Updated copy.
3. Empty proxy/tunnel, unavailable distinctions and probe checking/timeout copy.
4. Existing monitor OFF after prior successful probes: state disabled, old latency/HTTP/sample time cleared, **90 seconds of injected time + manual Refresh** do not re-enable or issue probe requests; public-IP refresh still succeeds.
5. Existing monitor ON from disabled: enters checking/正在探测…, clears disabled presentation, starts the ordinary three probes. A held fake HTTP client observes the intermediate state, without external requests.

Existing cancellation, success 60s cadence, failure backoff, 4s refresh cooldown and 0.75s debounce tests still pass. These fake-clock tests do **not** claim real UI click or real 90-second acceptance.

### Final verification

| Command | Actual result |
|---|---|
| `./scripts/build.sh` | PASS, exit 0 |
| `./scripts/test.sh` | PASS, exit 0; **122 tests, 0 failures** |
| `./scripts/verify.sh` | PASS, exit 0; doctor/build/unit/progress/assets/ledger |
| `git diff --check` | PASS, exit 0 |

Verified at `2026-10-02T01:52:37.914186+08:00` (Asia/Shanghai), manifest UTC `2026-10-01T17:52:37.914186+00:00`. HEAD/base `1e3eda82e051abe51bc4668250119b35cfed136b`, working source fingerprint `19b2b6dd4ff8a73951b7b669e1498a94c6ffec711d5de13621b349cc0f906b3d`. Evidence: `.artifacts/verification.json`, `.artifacts/build.log`, `.artifacts/test.log`, `.artifacts/MacSoulTests.xcresult`.

### Core behavior protection

Before/after SHA-256 **identical, 4/4**. `.artifacts/network-switch-before.json` / `.artifacts/network-switch-hashes.json` retain the guard evidence.

- `MacSoul/Models/NetworkMonitor.swift`: `fa6883fa1a3822e9fd0417e2c13eb9971e15749800d197caac1a8558c76b15b3` (unchanged).
- `MacSoul/Models/NetworkProviders.swift`: `35ed78628939c68751dbad20fb0eb183105a145dd6487a98698a83b643f148da` (unchanged).
- `MacSoul/Models/NetworkSnapshot.swift`: `6740a520c483becdd93914d9a1236f3ddc027c19b005cdd05ab7a4727e9fd789` (unchanged).
- `MacSoul/Models/MockStore.swift`: `f83d6a6a6a537e7f544c2527663830d7852ded0c085358e35bd6428e2bde5a93` (unchanged).

These cover the native path provider, public IP provider, URLSession transport, local proxy/tunnel reads, probe endpoints/state machine/scheduler/backoff, timeout/TTL/debounce/refresh and shared Snapshot/store semantics. Credential redaction is unchanged. No external observer/probe invocation or system-network configuration edit was made for this UI follow-up.

D3-04/05/06/07 remain **verifying**. Network manual UI remains **PENDING**. Formal Performance and Live AI Provider remain **NOT_RUN**; real Memory Pressure Critical remains **NOT_OBSERVED**. Prior System/Dev/Phase A evidence and approvals retained. No commit, push or PR.

### Acceptance build prepared

- App: `<OWNER_HOME>/githubWorkspace/macsoul/build-preview/MacSoul.NetworkSwitch.95tbqvkb/MacSoul.app`.
- All 11 packaged files match the verified Debug App, including executable and `MacSoul.debug.dylib`.
- Implementation dylib SHA-256: `dc4e5719219dae9d3b1fe70360b0439fa13a41511479e3af37f2e2b4743920e2`.
- Restart pending owner confirmation for only PID 65382; no process terminated in this follow-up yet.

Owner still needs to check native Switch layout/keyboard, OFF for 60–90s, OFF + Refresh, ON intermediate/result states, bilingual Network dates and both summaries, and unchanged System/Dev/AI surfaces. No automated visual PASS inferred.


### Owner-authorized Switch build launch

Owner approved normal restart of only PID 65382. Exact identity checked, SIGTERM exit confirmed; no SIGKILL or other process termination. Verified bundle file hashes and source fingerprint were checked before launch.

- App: `<OWNER_HOME>/githubWorkspace/macsoul/build-preview/MacSoul.NetworkSwitch.95tbqvkb/MacSoul.app`
- New PID: **77827**
- Branch: `feature/network`; no staging, commit, push or PR.
- Native Switch and bilingual UI acceptance remains **PENDING owner**.


## Final owner acceptance / Day 3 closeout — 2026-10-02

**Current acceptance: PASS for the owner-confirmed Network scope below.** Earlier PENDING/NOT_RUN UI entries describe previous checkpoints and are superseded for these specific acceptance items by the owner's explicit confirmation in this session. They remain as history. UI approval does not prove formal performance, account authentication or untested scenarios.

### Owner-confirmed manual results

| Task / area | Confirmed result |
|---|---|
| D3-04 path | Connected / Wi-Fi PASS; expensive/constrained presentation PASS |
| Public IP | Public IPv4 PASS; IPv6 transport failure accurately presented PASS; refresh PASS; Region not-collected semantics PASS |
| D3-05 proxy | MacSoul environment proxy, macOS system proxy, context difference, HTTP/HTTPS/SOCKS presentation and credential redaction PASS |
| Tunnel | Tunnel-like interface hints PASS; no VPN-routing proof claim PASS |
| D3-06 transport | GitHub HTTP 200, OpenAI HTTP 401, Anthropic HTTP 405 presentation PASS |
| Probe control | OFF PASS; old reachable state cleared PASS; OFF + Refresh does not enable probes PASS; ON recovery PASS |
| Probe timing / refresh | Ordinary successful cadence about 60s PASS; Refresh Network PASS |
| Presentation | Native macOS Switch, Chinese Network localization/date-time, high-data-cost / Low Data Mode terminology PASS |
| Shared surfaces | Overview / Menu Bar wiring and Chinese presentation PASS |

**HTTP 401/405 means an HTTP/TLS transport response was received. Account authentication and complete service health were NOT_TESTED.** The user did not authorize or perform an authenticated service call for this acceptance.

### Task state

D3-04, D3-05, D3-06 and D3-07 changed to **done** on explicit owner acceptance. D3-01/02/03 remain done, so **D3-01 through D3-07 are all done**. All Day 2 states, original plan points, dependency and acceptance records are retained. Human confirmation is recorded independently from command/unit evidence in tasks.json. STATUS is regenerated by the existing script, not maintained manually.

### Explicit limitations retained

- Formal Performance measurement: **NOT_RUN**.
- Live AI Provider: **NOT_RUN**; AI remains Mock.
- Region: **NOT_COLLECTED**; no inferred or invented location.
- IPv6 in this actual environment: **transport failed**; no fabricated IPv6 success.
- Real Memory Pressure Critical: **NOT_OBSERVED**; historical natural Warning acceptance retained.
- No system proxy, VPN, DNS or route modifications.
- No network disconnection or network/resource stress tests.
- Tunnel routing proof, service authentication and full service health are not established.

### Closeout scope

Only ledger/report acceptance records and the generated STATUS were updated for this closeout. The scripts README now explicitly distinguishes offline injected-provider unit tests from the separately opted-in external observer; it no longer claims that every script avoids provider calls. Product implementation, endpoints, cadence, redaction, timeout/backoff and native APIs are unchanged. No new functionality, observer rerun, network configuration change or App restart was performed for closeout.

Final build/test/verify, privacy and staging results are recorded below once completed. Owner authorized local commit only; no push or PR, and no next feature work.


### Final closeout verification and local commit scope

- `./scripts/build.sh`: **PASS**, exit 0.
- `./scripts/test.sh`: **PASS**, exit 0; **122 tests / 0 failures**. Existing System/Dev/Soul regression and all Network/presentation tests passed; no existing test removed.
- `./scripts/verify.sh`: **PASS**, exit 0; doctor/build/unit/progress/assets/**ledger** all PASS.
- `git diff --check`: **PASS**, exit 0; staged diff is checked before commit as well.
- Source and final packaged PrivacyInfo: **PASS**, exactly DiskSpace/85F4.1, UserDefaults/CA92.1, SystemBootTime/35F9.1. No new unsupported reason, no privacy-source modification.
- Verification timestamp `2026-10-02T02:03:58.759050+08:00` (Asia/Shanghai). Base revision `1e3eda82e051abe51bc4668250119b35cfed136b`, verified source fingerprint `38a2a56f2cd2b758cca08f3094845f46bf391dcd1231ae8a490c0b5fba2d9014`. Commands ran against the final source before local commit; the fingerprint is checked unchanged at commit time.
- Evidence: `.artifacts/verification.json`, `.artifacts/build.log`, `.artifacts/test.log`, `.artifacts/MacSoulTests.xcresult`, `.artifacts/network-closeout-privacy.json`.
- NetworkMonitor, NetworkProviders, NetworkSnapshot and MockStore hashes unchanged from the accepted Switch build. No implementation change during closeout.
- Scope audit: **21 files**, including 3 Network model/provider/monitor files, shared model/Store and three-surface UI/Settings/localization wiring, Xcode file references, Network tests and fake-path regression isolation in existing tests, architecture/script documentation, an explicit-opt-in redacted observer, tasks/STATUS/report.
- No System/Dev/Soul provider/classifier/state-machine source changes; no AI Provider/Cleaner/Notch work. No build outputs, personal config, credential/token files or raw sensitive logs in the commit scope.
- Baseline, task IDs, original/current points, acceptance/dependency lists preserved; non-Day-3 task states unchanged. Prior evidence retained in history.
- One cohesive local commit: `feat: add live network monitoring`. No push, tag, Release, PR or next-round feature work. Exact commit SHA is returned after creation and recorded locally in ignored `.artifacts/network-local-commit.json`.

Formal Performance / Live AI Provider remain NOT_RUN; Region NOT_COLLECTED; IPv6 transport failed in this environment; HTTP 401/405 transport-only semantics remain explicit. Network UI PASS above is the owner's explicit approval of the listed scope, not formal performance or all possible interactions.

Staging-check history: first `git diff --cached --check` returned exit 2 for four Markdown hard-break trailing-space lines at the historical report header. Removed only those trailing spaces; historical values/evidence retained. Rechecked staged diff after this document-only correction. Product source fingerprint and passing build/test/verify results are unchanged.


## PR #5 review correction: preserve checking in summaries — 2026-10-02

The prior unknown-path summary test incorrectly accepted `0/3 可达` while all probes were still checking. Corrected the expectation and presentation; the historical first-round expectations are superseded for this summary behavior.

- Disabled takes priority: 探测已关闭 / Probes disabled.
- Offline/requiresConnection: 离线 / Offline.
- All checking: 正在探测… / Checking….
- One reachable + two checking: `1/3 可达 · 正在探测` / `1/3 reachable · Checking…`.
- Only after no checking remains: final `3/3`, `2/3` or `0/3` reachable count.
- English display reuses `NetworkSnapshot.connectivitySummary`; Chinese retains matching localized semantics. Overview already consumes the shared helper automatically. Network detail states and Menu Bar scope are unchanged.

Tests: corrected `testConnectivitySummaryUnknownPathAlsoLocalized`; added two tests for final 3/2/0 results and partial failure with probes still checking. Both Chinese and English, disabled and both offline path states are covered. **124 tests / 0 failures** (previous 122 + 2), with no test removed.

- `./scripts/build.sh`: PASS, exit 0.
- `./scripts/test.sh`: PASS, exit 0; 124 tests / 0 failures.
- `./scripts/verify.sh`: PASS, exit 0; doctor/build/unit/progress/assets/ledger.
- `git diff --check`: PASS, exit 0.
- `git diff origin/main...HEAD --check`: PASS, exit 0; repeated after committing the fix.
- Verified `2026-10-02T02:20:26.439043+08:00` (Asia/Shanghai), base revision `e9c96bc28a16ebc0ab722367bb9c91ffb84e974e`, source fingerprint `84282de07fbbda100d08b4b105ccc418435d26a3b74e7fee0a62f7a9f6b09138`.
- Evidence: `.artifacts/verification.json`, `.artifacts/build.log`, `.artifacts/test.log`, `.artifacts/MacSoulTests.xcresult`.

Protection checks: NetworkMonitor/NetworkProviders/MockStore hashes unchanged (baseline `.artifacts/connectivity-summary-before.json`); NetworkSnapshot fields and the endpoint/schedule portion unchanged; Network detail code before the summary extension unchanged. No provider, endpoint, NWPathMonitor, timeout, cache, scheduler, backoff, cadence or refresh change.

Day 2 and D3 done states/historical owner approvals remain unchanged; current regression evidence is refreshed and old evidence preserved. This small summary fix is unit-tested; revised summary visual acceptance is NOT_RUN, not inferred from the prior manual approval. Formal Performance / Live AI Provider remain NOT_RUN, Region NOT_COLLECTED, real IPv6 transport failed, HTTP 401/405 transport-only semantics retained. No App restart, network disruption, stress test or configuration edit for this fix.

Owner authorized commit `fix: preserve checking state in connectivity summary` and normal push to existing feature/network; no force push or PR merge.
