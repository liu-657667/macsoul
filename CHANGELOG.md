# Changelog

## [0.1.1-beta.1] - 2026-10-23

[Public GitHub Pre-release](https://github.com/liu-657667/macsoul/releases/tag/v0.1.1-beta.1), **not Latest**, published at **2026-10-23 17:22:30 Asia/Shanghai** (`2026-10-23T09:22:30Z`). Release ID **421589810**; App **0.1.1 / build 2**; **No Developer ID / Unnotarized Beta Developer Preview**.

### Merged improvements

- Codex compatibility ([#15](https://github.com/liu-657667/macsoul/issues/15), [PR #21](https://github.com/liu-657667/macsoul/pull/21)): validate each connection's handshake and first quota response instead of exact-version matching as the sole gate. Retain fixed CLI provenance, minimal read-only RPCs, applicable-window semantics, schema/ID checks and fail-closed behavior. Version metadata is diagnostic, not automatic compatibility approval.
- Launch at Login ([#16](https://github.com/liu-657667/macsoul/issues/16), [PR #23](https://github.com/liu-657667/macsoul/pull/23), [PR #24](https://github.com/liu-657667/macsoul/pull/24)): Settings uses a Native User LaunchAgent with explicit enable/disable; lifecycle and Refresh only observe. Install directly in `/Applications` or the current user's `~/Applications` first. Enabling configures the next login without an extra immediate launch; moving the App requires explicit reconfiguration. Retained SMAppService types do not constitute dual registration.
- Typography ([#17](https://github.com/liu-657667/macsoul/issues/17), [PR #22](https://github.com/liu-657667/macsoul/pull/22)): unify fonts, weights, spacing and hierarchy across Settings/System, Dev/AI, Network/Cleaner and Overview/Menu Bar/Sidebar; fix Overview background, Cleaner summary heading and content entering the title bar at minimum height.
- Network fallback ([#18](https://github.com/liu-657667/macsoul/issues/18), [PR #19](https://github.com/liu-657667/macsoul/pull/19)): IPinfo primary → ident.me fallback independently for IPv4/IPv6; primary success skips fallback, failure permits at most one fallback attempt. Retain Stale/Unavailable/Unsupported, actual source/time, HTTPS/TLS and strict response validation. Preview sends neither public-IP requests nor connectivity probes; the Connectivity probes switch does not disable Live public-IP queries.

### Integration and release validation

- [PR #25](https://github.com/liu-657667/macsoul/pull/25) integrated the Beta source and release validation. [PR #26](https://github.com/liu-657667/macsoul/pull/26) fixed annotated-Tag checkout normalization in CI; the release Tag is fixed at `66ce3719e232af0df1a8e1648efc61660750d6e1`.
- The earlier `v0.1.1-beta` annotated Tag was created, but its [real Tag CI 39880285031](https://github.com/liu-657667/macsoul/actions/runs/39880285031) **FAILED**. It was not published as a GitHub Release and remains unchanged. Beta.1 [real Tag CI 39916936993](https://github.com/liu-657667/macsoul/actions/runs/39916936993) **SUCCESS**, all **11 Gates PASS**; successful logs do not expose exact test counts.
- Phase 3E-R2 verified the anonymous public page and all three assets, sizes/SHA256/checksum contents, independent DMG mount/ZIP extraction and complete packaged App identity against the accepted Release Archive. Asset names, sizes, hashes and source identity are in the [current release guide](docs/RELEASE.md#current-v011-beta1-publication).
- **Code Signing FAIL / classification A**: arm64 linker ad-hoc, x86_64 unsigned; no Developer ID or Apple notarization. **Public-browser Gatekeeper PENDING_OWNER / NOT_RUN**; anonymous HTTP or local opening does not establish Gatekeeper PASS.
- Limited Apple Silicon UI/login events include the second MacBook Air M1 / macOS 27.0.1. Full controlled LaunchAgent attribution remains **PARTIAL_PASS**. #15 Limited Owner Acceptance; #16 LA-P3 PARTIAL / Accessibility OWNER_DEFERRED; #17 PASSED_WITH_SCOPE; #18 Owner Live/UI PARTIAL_PASS remain. [#20](https://github.com/liu-657667/macsoul/issues/20) is **OPEN**, planned after Beta. Intel/other macOS hardware, full Accessibility and some Live/Performance coverage remain incomplete; see [Beta.1 boundaries](docs/RELEASE.md#beta1-validation-boundaries).

## [0.1.1-beta] - Unreleased

> **Historical / superseded Phase 1 preparation snapshot — 2026-10-22.** The dated statements below are retained as that checkpoint, not the current release plan. The candidate later received a Tag with failed real Tag CI, never a public GitHub Release; the published successor is Beta.1 above.

Planned as a GitHub **Pre-release**. The changes below are merged into main; Beta packaging and public publication are not complete. As verified on 2026-10-22, there is no v0.1.1-beta Tag, Release or release asset. The publicly downloadable version remains [v0.1.0 Unsigned Developer Preview](https://github.com/liu-657667/macsoul/releases/tag/v0.1.0).

### Merged improvements

- Codex compatibility ([#15](https://github.com/liu-657667/macsoul/issues/15), [PR #21](https://github.com/liu-657667/macsoul/pull/21)): validate each connection's handshake and first quota response instead of exact-version matching as the sole gate. Retain fixed CLI provenance, minimal read-only RPCs, applicable-window semantics, schema/ID checks and fail-closed behavior. Version metadata is diagnostic, not automatic compatibility approval.
- Launch at Login ([#16](https://github.com/liu-657667/macsoul/issues/16), [PR #23](https://github.com/liu-657667/macsoul/pull/23), [PR #24](https://github.com/liu-657667/macsoul/pull/24)): Settings uses a Native User LaunchAgent with explicit enable/disable; lifecycle and Refresh only observe. Install directly in `/Applications` or the current user's `~/Applications` first. Enabling configures the next login without an extra immediate launch; moving the App requires explicit reconfiguration. Retained SMAppService types do not constitute dual registration.
- Typography ([#17](https://github.com/liu-657667/macsoul/issues/17), [PR #22](https://github.com/liu-657667/macsoul/pull/22)): unify fonts, weights, spacing and hierarchy across Settings/System, Dev/AI, Network/Cleaner and Overview/Menu Bar/Sidebar; fix Overview background, Cleaner summary heading and content entering the title bar at minimum height.
- Network fallback ([#18](https://github.com/liu-657667/macsoul/issues/18), [PR #19](https://github.com/liu-657667/macsoul/pull/19)): IPinfo primary → ident.me fallback independently for IPv4/IPv6; primary success skips fallback, failure permits at most one fallback attempt. Retain Stale/Unavailable/Unsupported, actual source/time, HTTPS/TLS and strict response validation. Preview sends neither public-IP requests nor connectivity probes; the Connectivity probes switch does not disable Live public-IP queries.

### Known limitations and validation boundaries

- #15: **Limited Owner Acceptance**, covering a finite standalone session with CLI `0.162.0-alpha.17.2` and limited App observation (**PARTIAL_PASS**). App CLI version/window categories were **NOT_RECORDED**; long-running behavior, Sleep/Wake, performance and full UI/Accessibility remain unverified. No promise covers all future CLI versions.
- #16: core Debug real-machine enable/disable **PASS**; original **LA-P3 PARTIAL** retained; Accessibility **OWNER_DEFERRED**. Tab/Shift+Tab **NOT_PASSED**, cause **UNCONFIRMED**; Space/VoiceOver **NOT_TESTED**. The old SMAppService system issue's root cause is not fully established; Debug acceptance does not validate Beta distribution.
- #17: Owner visual **PASSED_WITH_SCOPE**; VoiceOver/Keyboard **NOT_RUN**, Reduce Motion **NOT_FULLY_VERIFIED**, continuous Resize **NOT_RUN**. Minimum-height fixes do not establish all-size coverage.
- #18: implementation complete, Owner Live/UI **PARTIAL_PASS**. Open [#20](https://github.com/liu-657667/macsoul/issues/20) retains automatic fallback, dual-source failure → Stale, recovery → Fresh and Querying as **NOT_OBSERVED**; usable IPv6, actual network switching, Sleep/Wake and full interaction as **NOT_RUN**; complete before/after Refresh time comparison as **PARTIAL_PASS**. The Owner's current plan schedules #20 after Beta; these checks are not automatically all release blockers.
- Cross-macOS and Intel hardware coverage is incomplete. Beta package validation, signing, notarization, publication and public-download verification are **NOT_RUN**. Completed Issues denote accepted scope, not release approval. Cleaner remains read-only; Claude is unavailable without a verified source; no Notch, App Store, Homebrew or automatic updates.
- [Main CI 39743270528](https://github.com/liu-657667/macsoul/actions/runs/39743270528) succeeded at `66149decaec43f08b986ab2fa302aa9530d0d196` with `./scripts/verify-v0.1.1.sh`; its successful logs expose no test count. Historical v0.1.0 tests, Archive, hashes, performance and Owner decisions are not Beta evidence. Phase 1 performs documentation checks only; see the [release guide](docs/RELEASE.md#v011-beta-preparation--unreleased) for later authorization and dependencies.

## [0.1.0] - 2026-10-07

v0.1.0 Unsigned / Unnotarized Developer Preview was [publicly released](https://github.com/liu-657667/macsoul/releases/tag/v0.1.0) on 2026-10-07 as a **Pre-release, not Latest**. Distribution uses a precompiled Universal DMG with the accepted ZIP as an alternative, plus SHA256SUMS.txt; no Xcode is required for users.

### Features

- Shared live System snapshots: whole-system CPU, memory used/total and pressure events, root-volume disk usage, battery/power-source events, developer process CPU delta and RSS.
- Deterministic Soul with sustained thresholds, category cooldowns, priority and recovery.
- Network path, independent public IPv4/IPv6, redacted App/system proxy facts, tunnel hints and optional anonymous transport probes.
- Java/Node/Python/Go discovery with version-manager contexts; developer TCP listeners with grouped binds and clipboard-only actions.
- Codex quota integration for exactly verified CLI 0.160.0 / 0.160.1 / 0.162.0-alpha.2; applicable windows, remaining presentation, freshness and provider reset. Claude stays unavailable without a verified source.
- On-demand read-only Cleaner discovery, estimates, Content Preview/drill-down and local Docker logical usage.
- Shared Overview/Menu Bar, Developer Preview fixtures, Chinese/English, App appearance and accessibility improvements.

### Reliability

- Lifecycle-safe cancellation and shared collectors; sleep/wake and Preview/Live boundaries.
- Bounded literal child commands and cancellable pipe draining, including inherited-pipe regressions.
- Day 7 test readiness synchronization and explicit version/build metadata.
- Exact Codex 0.162.0-alpha.2 compatibility; unknown versions remain fail closed.
- Release testability, Archive stripping and private matching dSYM fix; distributed App owner-path scan passed for both slices.
- System page content starts at the top with separate metrics/process sections and scrolling.
- PR #10 merged; [main CI 37614072470](https://github.com/liu-657667/macsoul/actions/runs/37614072470) SUCCESS.

### Limitations

- No cleanup, Trash, process termination, port conflict detection, Notch or history.
- Estimated usage is not exact reclaimable space; transport reachability is not full service health.
- Unknown Codex versions fail closed. Real Claude subscription quota is not verified.
- Finite performance measurements are environment-specific; the current five-minute CPU result is PASS and original RSS result is REVIEW. RSS REVIEW ACCEPTED by Owner for this finite v0.1.0 RC observation; the 100 MB target / 150 MB investigation threshold remain unchanged.
- Unsigned, unnotarized; first opening may be blocked by macOS. Browser/quarantine and public anonymous download results are separate from local package validation; no Gatekeeper PASS claim.
- Minimum deployment target macOS 13.0; Universal arm64 + x86_64 is not Intel hardware validation.
- Signed/installed Login Item validation remains deferred. Signing/notarization and App Store Connect privacy validation are NOT_RUN; no App Store, Homebrew or automatic update distribution.
- The public [v0.1.0 Release](https://github.com/liu-657667/macsoul/releases/tag/v0.1.0) remains UNSIGNED / UNNOTARIZED. Browser-candidate reopen and Applications installation checks are NOT_RUN. See [release guide](docs/RELEASE.md).
