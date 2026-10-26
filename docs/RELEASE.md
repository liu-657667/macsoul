# MacSoul release guide

## Current v0.1.1 Beta.1 publication

**当前最新公开预发布候选 / Latest public prerelease candidate: [v0.1.1-beta.1](https://github.com/liu-657667/macsoul/releases/tag/v0.1.1-beta.1)** — **2026-10-23 17:22:30 Asia/Shanghai** (`2026-10-23T09:22:30Z`), GitHub **Pre-release, not Latest**. App **0.1.1 / build 2**, **No Developer ID / Unnotarized Beta Developer Preview**.

| Identity | Published value |
|---|---|
| Release ID / state | **421589810** / `draft=false`, `prerelease=true`, `isLatest=false` |
| Tag / raw annotated object | `v0.1.1-beta.1` / `de1a700aa01c998494ff72e6342b9a2e58aa5b23` |
| Tagged Commit | `66ce3719e232af0df1a8e1648efc61660750d6e1` |
| Tagged Tree | `1e7620b47993d97d9610cf2830113d915dd57480` |
| Source fingerprint | `4e347031518054703acfbc94c4efccd7c51b9029b968a0208693a3a7d7373f04` |
| 277 inputs SHA256 | `d26b68d617f2627d5630c8c73c797cb3e2442d20fab807177998098ac8cbd45d` |
| Notes UTF-8 SHA256 | `802aae14533e030d9e2b868ed23161807c6e946aa60a01894b25463d849db026` |
| Real Tag CI | [39916936993](https://github.com/liu-657667/macsoul/actions/runs/39916936993), completed/success, **11/11 Gates PASS**; exact test counts **NOT_EXPOSED** |

| Public asset | Bytes | SHA256 |
|---|---:|---|
| [MacSoul-v0.1.1-beta.1-macos-universal-no-developer-id.dmg](https://github.com/liu-657667/macsoul/releases/download/v0.1.1-beta.1/MacSoul-v0.1.1-beta.1-macos-universal-no-developer-id.dmg) | 6,660,656 | `9b75bfcab322ad9b8af60963cf055caba45b0af63ef8bf556be54613bcef8db4` |
| [MacSoul-v0.1.1-beta.1-no-developer-id.zip](https://github.com/liu-657667/macsoul/releases/download/v0.1.1-beta.1/MacSoul-v0.1.1-beta.1-no-developer-id.zip) | 6,276,771 | `6306413271efd2d988c536b52177302e9a88cf42ff4cdd439b7abd7a4af46f42` |
| [SHA256SUMS.txt](https://github.com/liu-657667/macsoul/releases/download/v0.1.1-beta.1/SHA256SUMS.txt) | 232 | `a73cc49c29690ea7b3f360bcba45100c5d489e19aea5835e1cb52109266ec3d7` |

**Phase 3E-R2 actual public verification — PASS:** anonymous HTTP access to the public page and all three files, exact sizes/SHA256/checksum contents, independent read-only DMG mount and ZIP extraction. All 7 App files, paths/types, permissions/xattrs, resources/PrivacyInfo/ThirdPartyNotices, version and Universal slices matched the accepted R3 Release Archive. No source, private dSYM, logs, internal evidence or account data were included. This records the accepted 2026-10-23 execution, not a new package or browser test in this documentation sync.

**实际匿名公开验证已通过**：公开页面、三个附件的下载/大小/哈希/校验文件，以及独立 DMG 挂载、ZIP 解包与包内 App 完整身份匹配均依据 Phase 3E-R2 真实证据。发行包来自新 Release Archive，不是 Debug App；文档同步不重建、不重签、不移动发布 Tag。

### Beta.1 validation boundaries

| Scope | Actual result / retained limit |
|---|---|
| Full Code Signing | **FAIL / classification A**: arm64 **linker ad-hoc**, x86_64 **unsigned**; **No Developer ID / Unnotarized**. No unexplained corruption was found in the accepted diagnostics; this is not Signing PASS. |
| Public-browser quarantine / Gatekeeper | **PENDING_OWNER / NOT_RUN**. Anonymous HTTP and local/cross-Mac opening do not establish Gatekeeper PASS. |
| Beta.1 finite hardware observations | Apple Silicon installation/Bundled Mock/main window/appearance/Menu Bar/Quit/Reopen observed within Owner scope. Second **MacBook Air M1 / macOS 27.0.1** UI and enabled-login autostart / disabled-login no-autostart events **PASS**. |
| LaunchAgent attribution | Full controlled attribution **PARTIAL_PASS**. Existing Debug core PASS does not replace package evidence; original **LA-P3 PARTIAL**, Accessibility **OWNER_DEFERRED** remain. Tab/Shift+Tab **NOT_PASSED**, cause **UNCONFIRMED**; Space/VoiceOver **NOT_TESTED**. |
| [#15 Codex](https://github.com/liu-657667/macsoul/issues/15) | **Limited Owner Acceptance**. Finite standalone CLI session and limited App observation; long-running operation, Sleep/Wake, performance and full UI/Accessibility are not certified; no guarantee covers future CLI versions. |
| [#17 Typography](https://github.com/liu-657667/macsoul/issues/17) | **PASSED_WITH_SCOPE**. VoiceOver/Keyboard **NOT_RUN**, Reduce Motion **NOT_FULLY_VERIFIED**, continuous Resize **NOT_RUN**; not every window size verified. |
| [#18 Network](https://github.com/liu-657667/macsoul/issues/18) / [#20 follow-up](https://github.com/liu-657667/macsoul/issues/20) | Owner Live/UI **PARTIAL_PASS**. #20 **OPEN**, scheduled **after Beta**: automatic fallback, dual-source failure → Stale, recovery → Fresh and Querying **NOT_OBSERVED**; usable IPv6, actual network switching, Sleep/Wake and full interaction **NOT_RUN**; complete Refresh time comparison **PARTIAL_PASS**. |
| Other coverage | Intel and other macOS hardware, full Accessibility, long-running and some Live/Performance checks remain incomplete. No historical v0.1.0 performance/test counts are reassigned to Beta.1. |

**浏览器 Gatekeeper 尚待 Owner**；第二台 M1 Air 的有限 UI 与登录启停事件 PASS，不等于完整受控 LaunchAgent 归因（仍 PARTIAL_PASS）。#15/#16/#17/#18 的原有限验收与 #20 OPEN/Beta 后推进、Intel/其他 macOS/Accessibility/Live/Performance 限制均保留。Completed 只表示已接受范围，不等于全面验证。

For installation, choose DMG or ZIP plus checksums above. With both packages present, run `shasum -a 256 -c SHA256SUMS.txt`; for one package compare its `shasum -a 256` output with its entry. Normally Quit existing MacSoul, then install in `/Applications` or your user's `~/Applications` and confirm **0.1.1 / build 2**, **Bundled Mock**. Minimum deployment target: macOS 13.0; Universal arm64/x86_64 is not hardware coverage. Enable login launch only from the installed copy, explicitly; moving it requires reconfiguration.

下载后先核对 SHA256，安装及首次打开由用户本人执行。No Developer ID/未公证的首次打开可能被拦截；可信来源与哈希核对后参考 [Apple 官方逐 App 打开说明](https://support.apple.com/en-us/102445)，不关闭全局保护、不清除 quarantine。若损坏、恶意内容、无法启动或异常退出，停止并报告。Record actual browser download/quarantine/system prompt and action; without Owner observation retain **PENDING_OWNER / NOT_RUN**. No App Store, Homebrew or automatic updates; Cleaner remains read-only and Claude unavailable without verified source.

### Release history and immutable source

[PR #25](https://github.com/liu-657667/macsoul/pull/25) integrated Beta source/release validation; [PR #26](https://github.com/liu-657667/macsoul/pull/26) fixed annotated-Tag checkout normalization before the final main above. The original `v0.1.1-beta` raw Tag `712e6e4dc5009e3dfdb60cf8869f648a3606be88` still points to `b77d87fc00a4ddd3f7c4444dfcd707a91fca6722`; [real Tag CI 39880285031](https://github.com/liu-657667/macsoul/actions/runs/39880285031) remains **FAILURE**. That Tag was never published as a GitHub Release. Beta.1's real Tag CI and public verification are separate later evidence, not a rewrite of the failure.

The old Phase 1/2/3 plan below is a **historical/superseded snapshot**, not a pending release instruction. The App and project/generator configuration are 0.1.1 / build 2; Codex clientInfo.version is 0.1.1 (MacSoul client metadata, not the CLI version). Tag CI, new Release Archive/package and publication steps were completed in their separately authorized phases. Published Tag/Release/assets and their Markdown snapshots remain fixed. This Phase 3F updates only four documentation files through a branch/PR; merge and any later release or #20 work require separate authorization.

## v0.1.1 Beta preparation — Unreleased

> **Historical / superseded Phase 1 snapshot — 2026-10-22.** This entire preparation section (including Phase 1/2/3 authorizations, dependencies and NOT_RUN statements) records that checkpoint only. It is not the current release state or permission to repeat the old steps; current Beta.1 facts and validation boundaries are above. The heading is retained for historical links.

**v0.1.1-beta is planned as a GitHub Pre-release and has not been published.** The current public download remains [v0.1.0 Unsigned Developer Preview](https://github.com/liu-657667/macsoul/releases/tag/v0.1.0). Read-only GitHub verification on 2026-10-22 found main at `66149decaec43f08b986ab2fa302aa9530d0d196`, tree `e5884360e2118fa77396f527ee09ddefd826be98`, and no Beta Tag, Release or release assets. [Post-merge CI 39743270528](https://github.com/liu-657667/macsoul/actions/runs/39743270528) is SUCCESS using `./scripts/verify-v0.1.1.sh`; successful logs do not expose test counts. Historical local counts must not be assigned to this CI or Beta.

当前公开版本仍为 v0.1.0。main 已合入四项改进，但 Beta 发行包及公开发布尚未完成；本节是 Phase 1 文档候选，不是 Release Candidate 或发布批准。

### Phases and authorization

| Phase | Scope and stop point |
|---|---|
| **Phase 1 — current authorization** | Local documentation only: README.md, README.en.md, CHANGELOG.md and this guide; read-only GitHub/local verification, applicable documentation/Git checks, and fresh ignored `.artifacts/` evidence. No commit, push, PR, Tag, Release or package. Stop for Owner Review; only a candidate with resolved scope/environment/check issues may be marked `PHASE_1_DOCUMENTATION_CANDIDATE_READY_FOR_OWNER_REVIEW`. |
| **Phase 2 — separate Owner authorization required** | Version/Build synchronization, unified verification, a new Release Archive, Universal architectures, resources/privacy, DMG/ZIP/SHA256 and actual distribution-package validation, all bound to the new candidate identity. Signing/notarization conclusions require actual artifact evidence and appropriate authorization. |
| **Phase 3 — separate Owner authorization required** | Review, PR, CI, Merge, Tag, GitHub Pre-release, public-download verification and post-publication documentation synchronization. Phase 1 authorizes none of these actions. |

After actual publication and verified public downloads, synchronize real release links through a normal documentation commit/PR. Do not move a published Tag. The v0.1.0 Tag's documents retain their pre-publication Unreleased snapshot; main's later published-status record is authoritative for the completed publication and must not be replaced by that old text.

### Merged changes and retained acceptance boundaries

[#15](https://github.com/liu-657667/macsoul/issues/15), [#16](https://github.com/liu-657667/macsoul/issues/16), [#17](https://github.com/liu-657667/macsoul/issues/17) and [#18](https://github.com/liu-657667/macsoul/issues/18) are Closed / completed. Completed denotes only each accepted scope, not full verification or Beta release approval.

- **Codex — [PR #21](https://github.com/liu-657667/macsoul/pull/21):** current-connection handshake and first quota-response validation replace exact-version matching as the sole gate. Fixed ChatGPT.app bundled CLI provenance, the minimal `initialize` / `initialized` / `account/rateLimits/read` RPC set, applicable-window semantics, schema/ID validation and fail-closed behavior remain. Version information is diagnostic and does not automatically certify unverified versions.
- **Launch at Login — [PR #23](https://github.com/liu-657667/macsoul/pull/23), [PR #24](https://github.com/liu-657667/macsoul/pull/24):** the final Settings path uses a Native User LaunchAgent. Only explicit enable/disable mutates configuration; lifecycle events and Refresh observe. Install directly in `/Applications` or the current user's `~/Applications` before enabling. Enabling configures the next login, without an immediate extra App launch; moving the App requires explicit disable/reconfiguration. Legacy SMAppService types are not dual registration, and the old macOS system issue's root cause remains unconfirmed.
- **Typography — [PR #22](https://github.com/liu-657667/macsoul/pull/22):** fonts, weights, spacing and hierarchy span Settings/System, Dev/AI, Network/Cleaner and Overview/Menu Bar/Sidebar. Fixes include Overview background, Cleaner summary heading and content entering the title bar at minimum window height; this is not full accessibility or every-window-size acceptance.
- **Network — [PR #19](https://github.com/liu-657667/macsoul/pull/19):** IPinfo primary → ident.me fallback, independently for IPv4/IPv6. Primary success skips fallback; failure allows at most one fallback attempt. Stale, Unavailable, Unsupported, actual source and time remain explicit; HTTPS/TLS and strict response checks remain. Preview sends none of these external requests. Connectivity probes controls anonymous HTTPS HEAD probes, not Live public-IP queries. Published v0.1.0 used ipify; current main uses IPinfo with ident.me fallback.

| Record | Accepted/observed scope | Retained limits — not new Phase 1 execution |
|---|---|---|
| [#15 latest acceptance](https://github.com/liu-657667/macsoul/issues/15#issuecomment-6189348347) | **Limited Owner Acceptance**: finite standalone real protocol session with CLI `0.162.0-alpha.17.2`; limited App observation across AI / Overview / Menu Bar **PARTIAL_PASS** | App CLI version/window categories **NOT_RECORDED**; strict single Live entry **NOT_MET**; duration/request count **NOT_MEASURED**; natural update notification **NOT_OBSERVED**; observer/pipe measurements incomplete. 240-second long-running check, longer operation, Sleep/Wake, performance and full UI/Accessibility **NOT_RUN**. No guarantee for all future CLI versions. |
| [#16 latest acceptance](https://github.com/liu-657667/macsoul/issues/16#issuecomment-6335761099) | Core Debug real-machine enable/disable **PASS** | Original **LA-P3 PARTIAL** retained; Accessibility **OWNER_DEFERRED**. Tab/Shift+Tab **NOT_PASSED**, cause **UNCONFIRMED**; Space/VoiceOver **NOT_TESTED**. One Mac/macOS observation; Beta distribution-package acceptance not performed. |
| [#17 latest acceptance](https://github.com/liu-657667/macsoul/issues/17#issuecomment-6211963717) | Owner visual **PASSED_WITH_SCOPE** | VoiceOver/Keyboard **NOT_RUN**; Reduce Motion **NOT_FULLY_VERIFIED**; continuous Resize **NOT_RUN**. Local minimum-height recheck does not cover all window sizes. |
| [#18 latest acceptance](https://github.com/liu-657667/macsoul/issues/18#issuecomment-6160623602) | Implementation complete; Owner Live/UI **PARTIAL_PASS**; limited IPv4 Fresh/IPinfo and source/time observations, with IPv4 working when IPv6 was Unsupported | Terminal provider reachability does not prove automatic App fallback. IPv6 terminal TLS root cause remains unconfirmed; full Live/UI limits remain in #20. |
| [#20 open follow-up](https://github.com/liu-657667/macsoul/issues/20) | Complete before/after Refresh time comparison **PARTIAL_PASS** | Automatic fallback, dual-source failure → Stale, recovery → Fresh and Querying **NOT_OBSERVED**. Usable IPv6, actual network switching, Sleep/Wake, VoiceOver/Keyboard and full interaction/other window sizes **NOT_RUN**. |

Under the Owner's current plan, #20 proceeds **after Beta**; this sequencing comes from the current Owner authorization, not an edit to the older Issue body. Outstanding checks are not automatically all release blockers. Cross-macOS and Intel hardware coverage remains incomplete. Beta packages, signing, notarization, public publication and download verification have not been executed.

**This Phase 1: Build / Unit / Live / UI / Performance / Package / Signing / Notarization / Publication = NOT_RUN.** Read-only inspection of existing GitHub CI is not a new local run. The documentation validator checks external-link syntax only, not public downloads. Original Owner decisions, failure records, ledger/STATUS and historical fingerprints are preserved.

### Later dependencies — recorded, not fixed in Phase 1

1. `MacSoul.xcodeproj/project.pbxproj` and `scripts/generate_project.py` still specify **0.1.0 / build 1**; synchronize both in Phase 2.
2. `MacSoul/Models/CodexQuotaTransport.swift` still sends `clientInfo.version = 0.1.0`; review it during later version synchronization. This is MacSoul client metadata, **not the CLI version**.
3. Proposed Tag: **v0.1.1-beta**; proposed App numeric version: **0.1.1**. The Build Number remains to be determined in Phase 2; no values are changed here.
4. `verify-v0.1.1` performs **Debug** automatic verification; it does not validate an actual Release Archive or distribution package.
5. `.github/workflows/verify.yml` responds to Tag pushes, but the new-ref whitespace branch in `scripts/verify_v011.py` accepts only `refs/heads/`. Before creating the Beta Tag, complete a separately authorized minimal adaptation or an explicit validation strategy. This is a **static-review risk**, not an observed Tag CI failure; this phase does not push a Tag or change the workflow/checker.
6. Existing LaunchAgent Debug real-machine PASS cannot substitute for Beta distribution-package acceptance.
7. Source configuration `CODE_SIGNING_ALLOWED=NO` does not mean the Beta artifact's signing state has been checked. Unsigned/Signing/Notarization conclusions must come from the later actual artifact.
8. Universal architecture, privacy/resources, per-architecture path scans and independent extraction/mount checks must all bind to the new candidate identity. Historical Archive methods may inform later work; old App bytes, ZIPs and PASS records cannot serve as Beta evidence.

**v0.1.0 historical scope below:** the following public assets, sizes, hashes, dates, Day 5–7 measurements, 365 tests, Archive procedure, failures, deferrals and finite Owner acceptance remain v0.1.0 records. The future Developer ID section is a retained plan, not authorization or executed Beta work. No old package or acceptance is reused for Beta, and no historical content is rewritten as a Beta result.

## Historical v0.1.0 public release / v0.1.0 历史公开发行状态

**v0.1.0 UNSIGNED / UNNOTARIZED Developer Preview was publicly released on 2026-10-07.** [Official Release](https://github.com/liu-657667/macsoul/releases/tag/v0.1.0) — published at **2026-10-07T12:44:17Z**, `draft=false`, `prerelease=true`, **not Latest**. Tag `v0.1.0` is fixed at commit `2075572faafa5989ce3fd6ff7e6d7393365d8b99`; later documentation commits advance main without moving this tag. Day 7 local RC acceptance and repository integration remain complete: [PR #10](https://github.com/liu-657667/macsoul/pull/10) merged; [main CI 37614072470](https://github.com/liu-657667/macsoul/actions/runs/37614072470) SUCCESS. Signing/notarization remains NOT_RUN.

v0.1.0 已于 2026-10-07 公开发布，为 Pre-release、非 Latest；仍未签名、未公证。发行 tag 固定在上述提交，后续文档同步只推进 main，不重开 Day 7 验收。

| Public asset | Bytes | SHA256 |
|---|---:|---|
| [MacSoul-v0.1.0-macos-universal-unsigned.dmg](https://github.com/liu-657667/macsoul/releases/download/v0.1.0/MacSoul-v0.1.0-macos-universal-unsigned.dmg) | 6,437,720 | `57bc9d89432d681348e5e58346f5c9d77964b236304c2297c6d8aa689e7b3154` |
| [MacSoul-v0.1.0-unsigned.zip](https://github.com/liu-657667/macsoul/releases/download/v0.1.0/MacSoul-v0.1.0-unsigned.zip) | 6,062,427 | `6b541098d2cddcab546fecad4d5a48b09e1c837892ea0af68a912ff634e3f177` |
| [SHA256SUMS.txt](https://github.com/liu-657667/macsoul/releases/download/v0.1.0/SHA256SUMS.txt) | 204 | `59466571dac5e194ac6b5119fddb7520e04d4640495c1a2d70467b9c11627632` |

### Download and install / 下载与安装

Use the public assets on the [v0.1.0 GitHub Release](https://github.com/liu-657667/macsoul/releases/tag/v0.1.0) or the direct links above; no sign-in is required.

1. Download [MacSoul-v0.1.0-macos-universal-unsigned.dmg](https://github.com/liu-657667/macsoul/releases/download/v0.1.0/MacSoul-v0.1.0-macos-universal-unsigned.dmg) (recommended) or [MacSoul-v0.1.0-unsigned.zip](https://github.com/liu-657667/macsoul/releases/download/v0.1.0/MacSoul-v0.1.0-unsigned.zip), plus [SHA256SUMS.txt](https://github.com/liu-657667/macsoul/releases/download/v0.1.0/SHA256SUMS.txt).
2. In the download directory, run `shasum -a 256 -c SHA256SUMS.txt` if both packages are present, or compare the chosen file's `shasum -a 256` output with its checksum entry.
3. Open the DMG and drag `MacSoul.app` to `Applications`; alternatively extract the ZIP and copy the App. No Xcode or compilation is required. Normally quit other MacSoul instances before opening the App.
4. Launch MacSoul and confirm or choose Developer Preview / mock data in Settings; existing preferences may retain the previous mode. Live System is an explicit Settings choice. Owner package-smoke confirmation covers mock mode.
5. This App has no Developer ID signature or Apple notarization. If first opening is blocked, only after trusting the source and checksum, follow [Apple's per-App opening instructions](https://support.apple.com/en-us/102445): try opening, then System Settings → Privacy & Security → Open Anyway, if offered. Do not disable global protection or remove quarantine. A damaged-app message or abnormal exit requires separate investigation.

从 [正式 Release](https://github.com/liu-657667/macsoul/releases/tag/v0.1.0) 或上方直链下载 DMG（推荐）或 ZIP（备用）及校验文件，无需登录；核对 SHA-256，正常退出其它 MacSoul 实例，打开 DMG，将 App 拖入 Applications 后启动，或解压 ZIP 后复制 App。无需 Xcode 或自行编译。启动后在设置中确认或选择「开发预览」以使用模拟数据；已有设置可能保留先前模式，需要实时数据时再明确选择「实时系统」。未签名、未公证的首次打开可能被拦截；确认来源和校验值可信后，按上面的 Apple 官方逐 App 说明操作，不关闭全局保护或清除 quarantine；损坏提示、架构错误或异常退出需另行调查。

### Requirements and limits

- Minimum deployment target: macOS 13.0; Universal includes arm64 + x86_64. Existing Owner observations were on Apple Silicon; Intel hardware and all supported OS versions are not claimed tested.
- Codex exact verified CLI versions: **0.160.0 / 0.160.1 / 0.162.0-alpha.2**. Unknown versions fail closed. Claude without a verified real quota source remains honestly unavailable.
- Cleaner is read-only, with deletion NOT_IMPLEMENTED BY DESIGN. Region NOT_COLLECTED. Signed/installed Login Item validation remains deferred; App Store Connect privacy validation, signing/notarization, stress/specialized tests are NOT_RUN. Natural quota-update notifications and real critical / quota95% events remain NOT_OBSERVED.
- The unsigned Developer Preview is publicly available. No App Store, Homebrew or automatic updates; no signed installer or Gatekeeper PASS is claimed.
- Prior local validation for the accepted source: **365 tests / 0 failures / 0 skips**, not rerun for packaging. Successful repository CI reports unit PASS / exit 0 without exposing test counts; its manual_ui / performance / live_provider remain NOT_RUN.
- Owner Live PASS, CPU PASS and package privacy PASS remain accepted. Five-minute CPU avg / p95 / max: **0.012488% / 0.039502% / 0.063822%**. RSS start / end / avg / max: **100.483 / 79.479 / 88.107 / 100.483 decimal MB**; first / middle / final-third means: **93.502 / 89.300 / 81.833 MB**. Original result: **RSS REVIEW**. Owner decision: **RSS REVIEW ACCEPTED by Owner for this finite v0.1.0 RC observation.** The 100 MB target and 150 MB investigation threshold remain unchanged; no all-run <100 MB or no-memory-leak claim.

### Accepted App identity

- Source fingerprint: `1c60e81ec22795ba49bac7877309e57f534e2bc1d21911dcddef9adb171fb067`
- Executable SHA256: `7224f208d58b45612c3482b24ee7ec637c4f6c725fb0cde4a49fc4aabac60200`
- Original ZIP SHA256: `6b541098d2cddcab546fecad4d5a48b09e1c837892ea0af68a912ff634e3f177` — **6,062,427 bytes**

### Public verification and Owner observation / 公开验证与 Owner 观察

- Public page and all three attachments were accessible anonymously without GitHub token, Authorization or login cookie. Download sizes, SHA256 and SHA256SUMS.txt contents matched; the downloaded DMG mounted read-only, and all 7 App files in both DMG and ZIP matched the accepted Archive. These are publication/file-identity checks, not new browser-opening or Gatekeeper PASS evidence.
- Browser-candidate first opening: **BLOCKED_OBSERVED**. Owner personally allowed this App through the Privacy & Security per-App exception, then confirmed the mock main window, clear mock label, Menu Bar popover and normal Quit. Record only this actual scope.
- Browser-candidate **reopen: NOT_RUN**; **Applications installation check: NOT_RUN**. Earlier local candidate smoke is separate and cannot substitute for these checks. Still **UNSIGNED / UNNOTARIZED**; no Gatekeeper PASS.
- 公开页面及三个附件的匿名下载、大小、SHA256、校验文件内容核对通过；下载 DMG 可只读挂载，DMG / ZIP 中全部 7 个 App 文件匹配已接受 Archive。首次 **BLOCKED_OBSERVED** 保留；Owner 本人应用逐 App 安全例外后，确认模拟主窗口、清晰模拟标识、菜单栏及正常退出。该浏览器候选 reopen 和 Applications 安装检查仍为 **NOT_RUN**；仍未签名、未公证，不宣称 Gatekeeper PASS。

Build, unit, package, UI, performance, signing, notarization and publication remain distinct checks. Public tag, Release body and three attachments remain unchanged by this documentation sync.

## Historical unsigned release preparation (completed before publication)

**Historical / superseded scope, not current instructions.** Before Owner authorized public publication, preparation covered a minimal native DMG, a byte-identical copy of the accepted ZIP, checksums, public documentation and an unpublished Release draft. At that checkpoint, public tag and Publish Release awaited final Owner approval. That approval and publication subsequently occurred as recorded above; the original preparation workflow below is retained, not an instruction to rebuild or republish.

Reuse the accepted Archive App unchanged; copy the original ZIP bytes. A new DMG gets its own SHA256/size. Use a fresh ignored output directory and compare every mounted App file, PrivacyInfo and ThirdPartyNotices with the accepted inputs; corrected per-slice scanner must show zero owner-home prefixes and no N_SO/N_OSO/N_AST debug map. Distribute only App + Applications symlink in the DMG; no dSYM, Archive, source, logs or private evidence.

### Historical separate validation records

Record individually: DMG mount; mounted App identity/privacy; local Preview launch/main/Menu Bar/normal Quit/reopen; authenticated Draft attachment download/hash; actual browser download/quarantine/first opening; post-publication anonymous download. Local or authenticated command-line download is not browser/Gatekeeper evidence. Public anonymous download stays NOT_RUN before publication. Current run results belong in the PR body, ignored evidence and Release draft, not rewritten historical reports.

An unpublished draft uses proposed tag `v0.1.0`, exact CI-passed final main SHA, prerelease=true and not Latest. Confirm the tool does not create a public tag while saving a draft; verify remote tag refs before/after. Upload only DMG, original ZIP and SHA256SUMS.txt. Stop for Owner review before tag/publication.

Build, unit, package, UI, performance, signing, notarization and publication remain distinct checks.

## A. Historical Day 7 Archive procedure (already completed; do not rerun for documentation sync)

Requirements: macOS, full Xcode, Python 3. Version `0.1.0`, build `1`, bundle ID `local.macsoul.app`, `CODE_SIGNING_ALLOWED=NO`. The generator and checked-in project agree. No Developer Team, entitlements or signing are added.

App Release alone uses `ENABLE_TESTABILITY=NO`, `STRIP_INSTALLED_PRODUCT=YES`, `DEBUG_INFORMATION_FORMAT=dwarf-with-dsym`; optimization stays `-O`. App Debug and both Tests configurations retain their previous testability/development behavior. Effective Archive `COPY_PHASE_STRIP=YES`, `STRIP_STYLE=all`, `DEPLOYMENT_POSTPROCESSING=YES` are verified. The [Apple build-settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference) documents that enabling testability disables installed-product stripping.

Final package input must be the **stripped App from a Release Archive**, never a raw `BUILT_PRODUCTS_DIR` build product. Use a fresh archive/output path; do not overwrite failed or historical candidates:

```bash
./scripts/doctor.sh
./scripts/build.sh
./scripts/test.sh
python3 scripts/test_progress.py
python3 scripts/verify_progress.py
./scripts/verify.sh
git diff --check

xcodebuild -project MacSoul.xcodeproj -scheme MacSoul \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath .artifacts/day7/final-archive/MacSoul.xcarchive \
  CODE_SIGNING_ALLOWED=NO archive
```

No temporary testability/strip/debug-info override is needed. Before zip creation, require an actual Strip step and zero owner-home prefix occurrences in **both** executable slices and all distributed App resources. Check universal architecture, version/build, absence of source/tests/logs/raw payloads/artifacts, source-identical PrivacyInfo with exactly the approved three reasons, and intact ThirdPartyNotices. Section classification must not substitute for the zero-prefix gate.

Private `MacSoul.app.dSYM` stays separately inside ignored `.artifacts/day7/.../MacSoul.xcarchive/dSYMs/`. Confirm its UUIDs match the executable. Source paths inside that private dSYM are outside the distributed App gate. Do not put dSYM, the whole xcarchive, logs or source in the App zip, README download or public release.

After App static checks pass, package only the archived App:

```bash
mkdir -p .artifacts/day7/final-archive/release
ditto -c -k --sequesterRsrc --keepParent \
  .artifacts/day7/final-archive/MacSoul.xcarchive/Products/Applications/MacSoul.app \
  .artifacts/day7/final-archive/release/MacSoul-v0.1.0-unsigned.zip
shasum -a 256 .artifacts/day7/final-archive/release/MacSoul-v0.1.0-unsigned.zip
stat -f '%z' .artifacts/day7/final-archive/release/MacSoul-v0.1.0-unsigned.zip
```

Independently extract to a fresh ignored directory, compare all App file hashes with the Archive App, and rescan extracted executable and all uncompressed zip members. Static packaging checks do not prove launch/UI/runtime behavior. After privacy PASS and process authorization, use a byte-identical visible `build-preview/` copy for the minimum Preview launch/main/Menu Bar/normal Quit/reopen smoke. Do not install into `/Applications` automatically. Declare combined final unsigned RC package privacy acceptance only after all automatic/Archive/privacy/extraction and smoke gates pass; Owner Live regression and performance remain separate.

### Accepted Day 7 checkpoint

Current System-layout Archive/source verification365passed/0failed/0skipped, actual Strip1, both slices0owner-prefixes, exact privacy/resources, private matching dSYM and independent extraction PASS. Owner final Live regression and scoped launch/main/Menu Bar/normal Quit/reopen smoke PASS. Final native300sperformance completed: parentCPU PASS, RSS REVIEW (start/max100.48MB, average88.11MB, end79.48MB), stable one owned Codex child. No unconditional100MB target PASS or leak claim. Owner scoped final review completed for this local unsigned RC: RSS REVIEW ACCEPTED by Owner for this finite v0.1.0 RC observation. D7-01–D7-08 done after individual original-criterion review; subsequent PR #10 integration and main CI 37614072470 SUCCESS; current exact hashes and evidence are in the [Day7 report](../reports/day-7-release-closeout-2026-10-07.md) and [final report](../reports/FINAL.md). Prior accepted/failed checkpoints preserved.

Earlier build-product packages and their zero-path claims remain historical **SUPERSEDED** records: independent extraction reproduced178LC_SYMTAB debug-map references. The corrected scanner is current authority. Failed artifacts are preserved, not overwritten or manually stripped.

**Historical pre-publication scope:** The accepted candidate remained **UNSIGNED / UNNOTARIZED**. At this checkpoint, public tag / publication awaited final Owner authorization; browser/Gatekeeper observation and installed/signed Login Item verification were separate. The earlier NOT FOR PUBLIC DISTRIBUTION checkpoint predated the subsequently authorized unsigned Developer Preview preparation and public release. Current publication and browser observations are recorded above; signing and installed/signed Login Item validation remain unexecuted/deferred.

## B. Future Developer ID / notarization path (outside this phase)

**Plan only; NOT_RUN.** Owner must choose a stable `<PRODUCTION_BUNDLE_ID>`, `<DEVELOPMENT_TEAM>` and available `<DEVELOPER_ID_APPLICATION>` certificate. Do not guess values or read existing credential stores. Review hardened runtime and minimal required entitlements against subprocess/network behavior before enabling signing. Recheck real Login Item registration/unregistration only in the installed/signed environment, with explicit Owner action.

After those decisions, an authorized release operator can build/archive with signing enabled, for example:

```bash
xcodebuild -project MacSoul.xcodeproj -scheme MacSoul \
  -configuration Release -destination 'generic/platform=macOS' \
  -archivePath .artifacts/release/MacSoul.xcarchive \
  PRODUCT_BUNDLE_IDENTIFIER='<PRODUCTION_BUNDLE_ID>' \
  DEVELOPMENT_TEAM='<DEVELOPMENT_TEAM>' \
  CODE_SIGN_IDENTITY='<DEVELOPER_ID_APPLICATION>' \
  CODE_SIGNING_ALLOWED=YES ENABLE_HARDENED_RUNTIME=YES archive
```

This is an owner-reviewed starting command, not a tested signing recipe. Entitlements/export policy and nested executable signatures require review; do not apply `codesign --deep` as a repair shortcut. Verify the final signed App and signing identity/entitlements before packaging:

```bash
codesign --verify --strict --verbose=2 '<SIGNED_APP_PATH>'
codesign -dv --verbose=4 '<SIGNED_APP_PATH>'
codesign -d --entitlements :- '<SIGNED_APP_PATH>'
```

Use an Owner-managed notarytool profile or App Store Connect API-key setup. **OWNER ACTION / modifies Keychain:** creating a profile with `xcrun notarytool store-credentials '<NOTARY_PROFILE>'` is not performed by this guide or Agent. Never paste a real token/password into repository examples, logs or shell history. No credential query has been executed.

Only after separately authorized signing and packaging:

```bash
xcrun notarytool submit '<SIGNED_ZIP_PATH>' --keychain-profile '<NOTARY_PROFILE>' --wait
xcrun notarytool info '<SUBMISSION_ID>' --keychain-profile '<NOTARY_PROFILE>'
xcrun stapler staple '<SIGNED_APP_PATH>'
xcrun stapler validate '<SIGNED_APP_PATH>'
spctl --assess --type execute --verbose=2 '<SIGNED_APP_PATH>'
```

Require an Accepted notarization result; investigate rejected logs privately and sanitize any retained evidence. Staple and assess the final App, then recreate the final zip/DMG and calculate its SHA-256. Independently verify the downloaded artifact and real launch/quit/reopen. Formal signed-App Gatekeeper assessment remains NOT_RUN; the observed unsigned first-open block and Owner-applied per-App exception are recorded separately above, without a Gatekeeper PASS claim.

**Historical authorization boundary:** Day 7 did not create a tag, Release or DMG. The later preparation initially authorized only a DMG and unpublished draft, with public tag / publication separately gated. Owner subsequently authorized v0.1.0 publication, now completed as recorded at the top. Signing, notarization submission and repository-rule changes remain outside the authorized scope.

Official references: [Developer ID](https://developer.apple.com/developer-id/), [custom notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow). These describe signing/hardened runtime and notarytool/stapling; reading them does not constitute executing the signing plan.
