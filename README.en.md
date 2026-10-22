<p align="center">
  <img src="MacSoul/Resources/MacSoulBrand.xcassets/MacSoulAppIcon.appiconset/icon_128x128@2x.png" width="96" height="96" alt="MacSoul spirit icon">
</p>

<h1 align="center">MacSoul</h1>

<p align="center"><strong>A macOS developer companion with a little attitude.</strong><br>Your Mac knows what you're building.</p>

<p align="center">Native SwiftUI · Menu bar · System health · AI quotas · Soul</p>

<p align="center"><a href="README.md">简体中文</a> · English</p>

MacSoul aims to bring system health, AI coding quotas, network information and your local development environment into one native macOS app. A small spirit turns states worth noticing into a short reaction:

> - Sustained CPU overload: “My brain is about to explode.”
> - Critical memory pressure: “My stomach is about to burst.”
> - Recovery: “Phew… finally quiet again.”

**Personality gets your attention. Clear, trustworthy information is the point.**

> **MacSoul v0.1.0 Unsigned Developer Preview was publicly released on 2026-10-07.** Download the precompiled Universal DMG or ZIP from the [GitHub Release](https://github.com/liu-657667/macsoul/releases/tag/v0.1.0); no Xcode or compilation is required. This release is unsigned and unnotarized, so macOS may block first opening. See the installation instructions and validation limits below.

> **Current main includes four v0.1.1 improvements; the planned v0.1.1-beta is in preparation and unreleased.** Beta packages and public publication await separately authorized later phases; downloads still provide v0.1.0. Main was verified at `66149dec` on 2026-10-22, with [post-merge CI](https://github.com/liu-657667/macsoul/actions/runs/39743270528) SUCCESS. Successful logs expose no test count; historical local counts are not reused, and CI success does not approve the Beta release.

![MacSoul product concept artwork, not a screenshot of the current app](assets-source/reference/macsoul-product-hero.png)

> This is early product artwork, **not a current app screenshot or acceptance evidence**. Its VPN status, latency and cleanup buttons are not implemented; the pictured metric layout does not represent the current live UI.

## v0.1.0 Developer Preview screenshots

These preserved v0.1.0 Developer Preview captures use bundled mock data and do not establish UI acceptance for current main or Beta. AI quota and reset-time values are synthetic Developer Preview data. Cleaner shows the not-scanned state; Settings shows the upper section. Privacy review and Owner screenshot review passed for this historical set. Concept artwork is not an App screenshot.

![MacSoul v0.1.0 Developer Preview overview with mock data](docs/screenshots/v0.1/overview.png)

![MacSoul AI Coding Developer Preview with mock quota and reset times](docs/screenshots/v0.1/ai-coding.png)

*AI Coding — Developer Preview. Quota and reset time are Developer Preview mock data and do not represent a real account.*

![MacSoul Cleaner Developer Preview: read-only, Mock, not scanned](docs/screenshots/v0.1/cleaner.png)

![MacSoul Menu Bar Developer Preview with mock data and relative countdowns](docs/screenshots/v0.1/menu-bar.png)

Additional view: [Settings, upper section (Developer Preview)](docs/screenshots/v0.1/settings.png).

*Settings — v0.1.0 unsigned Developer Preview. Unavailable Launch at Login belongs to that historical RC, not current main. Settings now uses a Native User LaunchAgent; core Debug enable/disable behavior has real-machine acceptance, while the Beta distribution package remains unvalidated.*

## Features and implementation status

| Module | Intended use | Current default branch |
|---|---|---|
| **Soul** | Concise reactions and recovery | Deterministic local rules: sustained CPU thresholds, memory pressure, cooldown/recovery; static artwork, no LLM |
| **System** | CPU, memory, storage, power and developer processes | Native CPU, memory used/total, pressure events, root-volume disk, power-source state, process CPU delta/RSS; natural warning observed, critical not observed |
| **AI quotas** | Applicable Codex / Claude Code windows | Current main validates compatibility through each connection's handshake and first quota response; limited real validation accepted under #15; shared remaining percentages and provider resets; Claude unavailable without verified source |
| **Network** | Egress IP, proxy hints, transport checks | NWPath, independent IPv4/IPv6, IPinfo primary → ident.me fallback, App/system proxy context, tunnel hints and optional anonymous HEAD probes; Region not collected |
| **Dev environment** | Runtime contexts and developer TCP listeners | Java/Node/Python/Go, SDKMAN/NVM/pyenv/goenv, cache/refresh; developer filtering plus full-list disclosure; stop command is copy-only |
| **Dev storage** | Explain estimates and inspect contents | Read-only Xcode/Gradle/Maven/npm/Homebrew Preview/drill-down, local Docker logical usage without VM traversal; no cleanup |


The main window provides detail; the **menu bar is the universal quick-access surface**. A notched display is not required. Notch presentation is outside the current scope.

### Quotas that reflect the available windows

MacSoul is designed to display the windows actually reported for an account, not guess limits from a subscription name. Live and Mock share the same window contract:

| Data | Presentation |
|---|---|
| Week exists and 5h is explicitly not applicable | Show Week in summaries; do not invent a 5h bar |
| Both 5h and Week exist | Show both |
| A valid window reports 0% used | Show 100% remaining; do not treat it as missing |
| Unreported, failed or stale data | Show that state; never turn it into “unlimited” or fresh usage |

Both surfaces consume the same state. The AI module does not manage agent sessions, analyze token costs or automatically select models. It concerns **Codex / Claude Code quotas**, not a combined view of ChatGPT chat limits.

Settings can switch MacSoul between Follow macOS, Light and Dark, and between Simplified Chinese and English. These choices do not change macOS system settings.

### Merged v0.1.1 improvements and validation boundaries

- **Codex** ([#15](https://github.com/liu-657667/macsoul/issues/15), [PR #21](https://github.com/liu-657667/macsoul/pull/21)): validation of the current connection's handshake and first quota response replaces exact-version matching as the sole admission gate. Fixed CLI provenance, minimal read-only RPCs, applicable-window semantics, schema/ID checks and fail-closed behavior remain. Version metadata is diagnostic, not a guarantee of unverified future compatibility. Limited Owner Acceptance covers a finite standalone protocol session with then-current CLI `0.162.0-alpha.17.2` and limited App observation across three surfaces (PARTIAL_PASS). The App's CLI version and window categories were not recorded; long-running behavior, Sleep/Wake, performance and full UI/Accessibility remain unverified.
- **Launch at Login** ([#16](https://github.com/liu-657667/macsoul/issues/16), [PR #23](https://github.com/liu-657667/macsoul/pull/23), [PR #24](https://github.com/liu-657667/macsoul/pull/24)): Settings now uses a Native User LaunchAgent. Only explicit user enable/disable changes configuration; lifecycle events and Refresh only observe. Install directly in `/Applications` or the current user's `~/Applications` first. Enabling configures the next login without immediately launching another App instance; moving the App requires explicitly disabling the old configuration and enabling again. Core Debug real-machine enable/disable is PASS; original LA-P3 PARTIAL remains, Accessibility is OWNER_DEFERRED, and Beta package validation is outstanding. Retained legacy SMAppService types do not mean dual registration; the old system issue's root cause remains unconfirmed.
- **Typography and layout** ([#17](https://github.com/liu-657667/macsoul/issues/17), [PR #22](https://github.com/liu-657667/macsoul/pull/22)): consistent fonts, weights, spacing and hierarchy across Settings/System, Dev/AI, Network/Cleaner and Overview/Menu Bar/Sidebar. Fixes cover the Overview background, Cleaner summary heading and content entering the title bar at minimum window height. Owner visual acceptance is PASSED_WITH_SCOPE; full accessibility, continuous Resize and all window sizes are not verified.
- **Network fallback** ([#18](https://github.com/liu-657667/macsoul/issues/18), [PR #19](https://github.com/liu-657667/macsoul/pull/19)): IPinfo primary → ident.me fallback, independently for IPv4/IPv6. Primary success skips the fallback; failure allows at most one fallback attempt. Implementation is complete; Owner Live/UI is PARTIAL_PASS. [#20](https://github.com/liu-657667/macsoul/issues/20) retains unobserved/unexecuted checks and is planned after Beta under the Owner's current sequence.

Completed means only the accepted scope. See [Beta preparation and validation boundaries](docs/RELEASE.md#v011-beta-preparation--unreleased) for exact keyboard, VoiceOver, Reduce Motion, Network and cross-macOS / Intel coverage limits. Outstanding checks are not automatically all release blockers.

### A personality, not a notification machine

Normal, busy, overloaded, too full, low energy and resting are expressions of the same spirit. Their images and copy can currently be explored through mock scenarios.

Live Soul behavior uses local rules, sustained thresholds, cooldowns and recovery rather than an LLM generating comments. A momentary CPU spike does not directly change Soul state.

## Precompiled App: v0.1.0 is publicly available

Download these public assets from the [v0.1.0 GitHub Release](https://github.com/liu-657667/macsoul/releases/tag/v0.1.0); this is a **Pre-release, not Latest**. The precompiled App does not require Xcode or compilation.

- [Universal DMG (recommended)](https://github.com/liu-657667/macsoul/releases/download/v0.1.0/MacSoul-v0.1.0-macos-universal-unsigned.dmg)
- [ZIP (alternative)](https://github.com/liu-657667/macsoul/releases/download/v0.1.0/MacSoul-v0.1.0-unsigned.zip)
- [SHA256SUMS.txt (checksums)](https://github.com/liu-657667/macsoul/releases/download/v0.1.0/SHA256SUMS.txt)

The minimum deployment target is macOS 13.0. Universal contains arm64 and x86_64; it does not claim Intel hardware testing or coverage of every macOS version. Download the package and checksums and verify SHA-256, then open the DMG and drag MacSoul to Applications; alternatively extract the ZIP and copy the App. Normally quit other MacSoul instances first. After launch, confirm or choose Developer Preview / mock data in Settings; existing preferences may retain the previous mode. Explicitly choose Live System when real system information is wanted.

**UNSIGNED / UNNOTARIZED: macOS may block first opening.** Only after trusting the source and checksums, follow [Apple's per-App opening guidance](https://support.apple.com/en-us/102445): attempt opening, then System Settings → Privacy & Security → Open Anyway, if offered. Do not disable global protection or remove quarantine. Initial **BLOCKED_OBSERVED** is retained. After personally applying a per-App security exception, Owner confirmed the browser candidate's mock main window, clear mock label, menu bar and normal Quit. Reopen and Applications installation checks for that candidate remain **NOT_RUN**; no Gatekeeper PASS is claimed. Damage or abnormal exit needs separate investigation. No App Store, Homebrew or automatic updates. See the [release guide](docs/RELEASE.md) for steps and validation boundaries.

## Run the developer preview from source

You need macOS, full Xcode (including the Swift toolchain) and Python 3. The project's deployment target is macOS 13; that is not a claim that every macOS / Xcode combination has been tested. See the [development guide](docs/DEVELOPMENT.md) for tooling and verification records. Codex, Claude Code and AI API keys are not required to try the preview.

```bash
git clone https://github.com/liu-657667/macsoul.git
cd macsoul

./scripts/doctor.sh
./scripts/verify-v0.1.1.sh
./scripts/run-mock.sh
```

Or open the project in Xcode:

```bash
open MacSoul.xcodeproj
```

Quit any running MacSoul instance before using the preview script. The app starts with mock data. Choose **Settings → System data source → Live System** for live System/Dev/Network and verified AI providers. Back in Developer Preview, try `Codex: Week only`, high CPU and memory-pressure scenarios. These fixtures neither alter a real subscription nor place the machine under load.

The commands above are for source development; use the public download links above to try the v0.1.0 precompiled App without running these commands.

## Privacy and boundaries

Local-first does not mean zero network traffic. Published v0.1.0 Live Network queries ipify for observed IPv4/IPv6 egress addresses. **Current main (intended for the unreleased v0.1.1-beta)** uses IPinfo plain-text endpoints. Primary success skips the fallback; failure allows at most one ident.me attempt. IPv4/IPv6 are independent, with at most two queries and a 10-second total timeout budget per family per refresh. HTTPS/TLS and strict status-code, response-size and IP-family validation remain; certificate validation is not bypassed. Enabled Connectivity probes send anonymous HTTPS HEAD requests to GitHub/OpenAI/Anthropic without API tokens, credentials or project data. OFF disables probes, not IP lookups. Preview starts neither. No SSID/BSSID, location or Region collection; no proxy/VPN/DNS/route mutation.

Public IP services can observe the requester’s public egress IP. Only IP text is parsed: no GPS, country, city, ASN, physical device location, real account data or project content is collected. Real public IPs, raw HTTP responses and proxy credentials are not persisted. If both sources fail, only the last valid address and its provenance are retained as Stale; without a successful history the state is Unavailable, and an unsupported address family is Unsupported. Current Network details separate last success, last attempt, actual successful source, checking state and latest failure. Owner Live/UI is only PARTIAL_PASS. Full service reachability, target-device proxy/TLS/IPv6 and interaction require separate validation; another machine's or terminal's reachability does not prove automatic App fallback.

Codex on current main starts only the fixed ChatGPT.app bundled CLI app-server. Version metadata comes from that same executable for diagnostics; each connection must pass handshake and first-read validation, sending only initialize, initialized and account/rateLimits/read and consuming minimal rate-limit fields. No account profile, prompts/threads, inference, login or quota mutation. Canonical usedPercent is preserved; numeric UI/bars show remaining. Only verified machine-readable capability can classify absent 5h as not applicable; absence alone is insufficient. Claude currently checks executable/version only; installation does not prove a subscription.

Cleaner reads resolved cache roots without uploading paths/content, skips symlinks and constrains Preview traversal. Docker queries local Engine logical usage only; remote contexts are excluded, with no Docker.raw/VM traversal. Current Launch at Login uses a user LaunchAgent and changes configuration only through explicit user action. Accepted Debug real-machine enable/disable does not replace later Beta distribution validation.

### Limitations

- Provider-reported quotas are not an official SLA. Codex validates the current session; unsupported methods or incompatible responses still fail closed. Limited real validation under #15 does not guarantee every future CLI, long-running behavior or full UI/Accessibility. Claude is unavailable without a verified source.
- Estimated usage is not exact reclaimable bytes. APFS clones/shared blocks, sparse files, hard links and purgeable space differ. Docker logical usage is not VM physical usage.
- Listening ports are not conflicts. Copying `kill -TERM <PID>` does not execute it; verify current PID ownership before running it yourself.
- Connected NWPath is not internet health. HTTP 401/405 proves transport reachability, not authentication or full service health; tunnel hints do not prove VPN routing.
- No v0.1 cleanup/Trash, Notch or history timeline; no artificial memory/quota exhaustion for acceptance.

### Historical v0.1.0 performance

The following Day 5–7 data belongs only to v0.1.0, not current main or Beta performance evidence. Day 5 measured Mac14,9, 12 logical CPUs, 16 GiB, macOS 27.0.1 / Xcode 27, unsigned Release with Codex 0.160.1. Supported menu-bar-only five-minute run: MacSoul average CPU about 0.0057%; RSS average about 53.4 MB / peak about 63.0 MB, with the Codex child measured separately. See [method and limits](reports/day-5-performance-hardening-2026-10-04.md). The longer Day 6 run is recorded in the [historical report](reports/day-6-review-hardening-2026-10-07.md); unexecuted measurements are not PASS.

The v0.1.0 Day 7 five-minute run measured CPU avg / p95 / max: 0.012488% / 0.039502% / 0.063822%; RSS start / end / avg / max: 100.483 / 79.479 / 88.107 / 100.483 decimal MB. The original results are CPU PASS and RSS REVIEW; the Owner decision is **RSS REVIEW ACCEPTED by Owner for this finite v0.1.0 RC observation.** The 100 MB target and 150 MB investigation threshold remain unchanged; RSS was not below 100 MB throughout.

Finite runs do not guarantee <0.5% on every machine or prove that future leaks are impossible.

## Roadmap

| Stage | Focus |
|---|---|
| **Completed: v0.1.0 core integrations** | System / Dev / Network / Codex, read-only Cleaner; Day 6 review, accessibility, Settings and sustained-performance acceptance closed within the scope recorded for v0.1.0 |
| **Publicly released: v0.1.0** | [Unsigned Developer Preview](https://github.com/liu-657667/macsoul/releases/tag/v0.1.0) published on 2026-10-07; Pre-release, not Latest; public Universal DMG / ZIP and checksums; still unsigned and unnotarized |
| **In preparation: v0.1.1-beta** | Four improvements merged into main; currently a Phase 1 documentation candidate, with Beta packaging and publication awaiting separately authorized later phases |
| **After Beta: Network Live/UI** | Progress [#20](https://github.com/liu-657667/macsoul/issues/20) under the Owner's current plan, retaining NOT_OBSERVED, NOT_RUN and partial results |
| **v0.2.0 plans** | Separately design Cleaner cleanup/Trash/confirmation, Maven/Gradle Build Tools and Docker extensions; not current capabilities |

[Task status](docs/STATUS.md) is the progress entry. Screenshots, automated tests, real features, performance and full interaction acceptance are separate. In the v0.1.0 historical record, the small menu icon remains DRAFT; the [Day 6 safe Preview screenshot checklist](reports/day-6-review-hardening-2026-10-07.md) is accepted; real Preview screenshots have been collected and privacy checked for D7-07; Owner screenshot approval passed, never replaced by concept artwork. GIF is optional.

## v0.1.0 public release and historical RC acceptance

The 365 tests, Archive, package hashes and Owner acceptance in this section belong to v0.1.0. They are neither Beta evidence nor rerun in this phase.

The local unsigned 0.1.0 / build 1 Release, zip, extraction/resources and SHA-256 checks passed; Owner screenshot approval passed; final Owner Live regression PASS, CPU PASS and RSS REVIEW ACCEPTED for this local unsigned RC; [PR #10](https://github.com/liu-657667/macsoul/pull/10) merged normally; [main CI 37614072470](https://github.com/liu-657667/macsoul/actions/runs/37614072470) SUCCESS. This CI is distinct from the earlier local 365 tests / 0 failures / 0 skips; successful CI logs did not expose test counts. Build, test, package, signing, notarization and publication are tracked separately. See the [release guide](docs/RELEASE.md), [final report](reports/FINAL.md) and [changelog](CHANGELOG.md). The [v0.1.0 Release](https://github.com/liu-657667/macsoul/releases/tag/v0.1.0) is public. Anonymous downloads of all three assets, sizes, SHA256 and checksum contents passed; the DMG mounts and all 7 App files in DMG / ZIP match the accepted Archive. Publication does not expand the finite existing RC acceptance scope. No signed installer or Gatekeeper PASS is claimed.

## Contributing

Reproducible bug reports, macOS / Xcode compatibility feedback, readability improvements and live integration work are welcome through [Issues](https://github.com/liu-657667/macsoul/issues) and Pull Requests. Include the environment, branch or commit, and reproduction steps; remove sensitive information from logs and screenshots first.

[Contributing guide](CONTRIBUTING.md) · [Development guide](docs/DEVELOPMENT.md) · [Product design](docs/DESIGN.md) · [Architecture](docs/ARCHITECTURE.md) · [Task status](docs/STATUS.md)

For agent-assisted development, start with [AGENTS.md](AGENTS.md) and the current task. Trying the app does not require reading sprint plans, audit reports or model configurations.

## License

Original code that MacSoul is entitled to license is under the [MIT License](LICENSE), with `Copyright (c) 2026 liu-657667`. The Cleaner broom icon comes from Phosphor Icons; its original copyright and license are included with the app in [ThirdPartyNotices.txt](MacSoul/Resources/ThirdPartyNotices.txt). Other third-party content retains its own notices and terms; see [asset sources](docs/ASSET-SOURCES.md). Historical inputs, reference images and third-party materials are not automatically relicensed by the root license.
