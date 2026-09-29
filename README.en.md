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

> **Developer preview.** The default branch runs a Mock App with bundled sample data. You can explore the main window, menu bar, Soul artwork, appearance settings and quota scenarios. Live system metrics, account quotas, network probes and environment detection are not connected yet. This is not a daily-use monitoring tool. The table below separates the preview from planned work.

![MacSoul product concept artwork, not a screenshot of the current app](assets-source/reference/macsoul-product-hero.png)

> This is early product artwork, **not a current app screenshot or acceptance evidence**. Its live metrics, VPN status, latency and cleanup buttons are not implemented.

## Features and implementation status

| Module | Intended use | Current default branch |
|---|---|---|
| **Soul** | React to machine state with expressions and concise messages, including recovery, without repeated interruptions | Six character images and scenario copy are integrated; live state transitions are planned |
| **System** | CPU, memory pressure, disk, battery and resource-consuming processes | Metric UI uses sample data; native collection and process analysis are planned |
| **AI quotas** | Codex / Claude Code usage and reset times for applicable 5h / Week windows | Dynamic windows, Week-only, 0%, missing, failed and stale scenarios are previewable; live accounts are not connected |
| **Network** | Public IP, proxy hints and service connectivity | UI preview; real detection is planned |
| **Dev environment** | Runtime versions, executable paths and listening ports | UI and sample ports; real detection is planned |
| **Dev storage** | Explain storage usage and the risks of cleaning development caches | UI preview; scanning is not implemented and nothing is deleted |

The main window provides detail; the **menu bar is the universal quick-access surface**. A notched display is not required. Notch presentation is outside the current scope.

### Quotas that reflect the available windows

MacSoul is designed to display the windows actually reported for an account, not guess limits from a subscription name. The Mock App already previews these cases:

| Data | Presentation |
|---|---|
| Week exists and 5h is explicitly not applicable | Show Week in summaries; do not invent a 5h bar |
| Both 5h and Week exist | Show both |
| A valid window reports 0% used | Show 0%; do not treat it as missing |
| Unreported, failed or stale data | Show that state; never turn it into “unlimited” or fresh usage |

Both surfaces consume the same state. The AI module does not manage agent sessions, analyze token costs or automatically select models. It concerns **Codex / Claude Code quotas**, not a combined view of ChatGPT chat limits.

Settings can switch MacSoul between Follow macOS, Light and Dark, and between Simplified Chinese and English. These choices do not change macOS system settings.

### A personality, not a notification machine

Normal, busy, overloaded, too full, low energy and resting are expressions of the same spirit. Their images and copy can currently be explored through mock scenarios.

The live design uses local rules, sustained thresholds, cooldowns and recovery events rather than an LLM generating comments. A momentary CPU spike should not produce a stream of alerts.

## Run the Mock App from source

You need macOS, full Xcode and Python 3. The project's deployment target is macOS 13; that is not a claim that every macOS / Xcode combination has been tested. See the [development guide](docs/DEVELOPMENT.md) for tooling and verification records. Codex, Claude Code and AI API keys are not required to try the preview.

```bash
git clone https://github.com/liu-657667/macsoul.git
cd macsoul

./scripts/doctor.sh
./scripts/verify.sh
./scripts/run-mock.sh
```

Or open the project in Xcode:

```bash
open MacSoul.xcodeproj
```

Quit any running MacSoul instance before using the preview script. In the app's **Settings → developer preview** section, try `Codex: Week only`, high CPU and memory-pressure scenarios. These controls neither alter a real subscription nor place the machine under load.

These instructions are for a source preview, not a promise of an available production installer.

## Privacy and boundaries

Local-first is a design principle. The current preview uses bundled samples, with no live account or system integration. Future network checks must distinguish local inspection from external requests: a public-IP lookup contacts an external service and is not “offline.”

MacSoul does not write code, provide antivirus or firewall protection, or equate occupied storage with safely reclaimable storage. The current app has no automatic cleanup and does not delete real development data.

## Roadmap

| Stage | Focus |
|---|---|
| **Now: runnable preview** | Native window and menu bar, Soul assets, mock scenarios, build and test entry points |
| **Next: live system** | CPU / memory → shared snapshot → UI and Soul; then disk, battery and processes |
| **Later: live integrations** | Codex / Claude Code quotas, network, runtimes and ports |
| **Later: expansion and distribution** | Read-only storage analysis, performance validation and packaging according to the task ledger |

This is direction, not a completed-feature checklist or a delivery-date promise. [Task status](docs/STATUS.md) tracks development. Visual acceptance, real-data validation and performance remain separate checks.

Phase A visual acceptance is still partial. The small menu bar icon remains DRAFT; full interaction of the revised UI, performance and live providers have not been accepted. See the [phase report](reports/phase-a-visual-closeout-2026-09-28.md) for completed checks and open items.

## Contributing

Reproducible bug reports, macOS / Xcode compatibility feedback, readability improvements and live integration work are welcome through [Issues](https://github.com/liu-657667/macsoul/issues) and Pull Requests. Include the environment, branch or commit, and reproduction steps; remove sensitive information from logs and screenshots first.

[Development guide](docs/DEVELOPMENT.md) · [Product design](docs/DESIGN.md) · [Architecture](docs/ARCHITECTURE.md) · [Task status](docs/STATUS.md)

For agent-assisted development, start with [AGENTS.md](AGENTS.md) and the current task. Trying the app does not require reading sprint plans, audit reports or model configurations.

## License

Original code that MacSoul is entitled to license is under the [MIT License](LICENSE), with `Copyright (c) 2026 liu-657667`. The Cleaner broom icon comes from Phosphor Icons; its original copyright and license are included with the app in [ThirdPartyNotices.txt](MacSoul/Resources/ThirdPartyNotices.txt). Other third-party content retains its own notices and terms; see [asset sources](docs/ASSET-SOURCES.md). Historical inputs, reference images and third-party materials are not automatically relicensed by the root license.
