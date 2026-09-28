# MacSoul — 7-Day Release Plan

Points are relative effort/acceptance units, not hours. P0 is release-critical, P1 important, P2 stretch.

---
## Day 1 — Design lock + native skeleton (10 pts)
**Model route:** Sol/high main; Astra/high architect for design ambiguity; Luna/medium exploration/reporting.
**Goal:** Know exactly what the product looks like before real monitoring begins.

P0:
- [ ] (2) Create/open native SwiftUI macOS project + test target.
- [ ] (2) Implement Menu Bar shell + main window + navigation.
- [ ] (2) Implement typed mock snapshots and dependency injection.
- [ ] (2) Build complete mock Overview + AI/Network/Dev/System pages matching `DESIGN.md`.
- [ ] (1) Define reusable design tokens/components and Soul vector placeholder.
- [ ] (1) Build/tests pass; capture screenshot(s) for review.

Exit: app is navigable and visually coherent with mock data; no real sensors.

---
## Day 2 — System sensor hub + Soul core (12 pts)
**Model route:** Sol/high main; Luna/medium explorer; Sol/medium tester; Astra/high only for native API/concurrency blockers.
P0:
- [ ] (2) Central SensorHub / lifecycle-aware scheduling.
- [ ] (2) CPU native provider + shared snapshot.
- [ ] (2) Memory + pressure provider.
- [ ] (1) Disk + battery provider.
- [ ] (2) Top developer process summary.
- [ ] (2) Soul state machine: CPU/memory thresholds, hysteresis, cooldown, recovery.
- [ ] (1) Unit tests + real System/Overview/Menu Bar wiring.

Exit: real CPU/memory/system state; Soul reacts correctly without duplicate monitoring.

---
## Day 3 — Dev environment + network core (12 pts)
**Model route:** Sol/high main; Luna/medium exploration; Sol/medium tests; Astra/high only for architecture/security/lifecycle ambiguity.
P0:
- [ ] (2) Safe cancellable ShellRunner.
- [ ] (2) Java/Node/Python/Go detection + cache.
- [ ] (2) Listening ports + process/PID mapping.
- [ ] (2) Network path + public IP adapter.
- [ ] (2) shell/system proxy + tunnel/VPN hints.
- [ ] (1) connectivity probes with backoff/disable.
- [ ] (1) tests/fixtures + Overview wiring.

P1:
- [ ] developer-friendly mismatch warnings.

Exit: Dev and Network pages are useful and failure tolerant.

---
## Day 4 — Real-time AI quota + Menu Bar polish (11 pts)
**Model route:** Sol/high main; Astra/high architect for quota integration uncertainty; Luna/medium fixtures/docs; Sol/medium tests.
P0:
- [ ] (3) Codex app-server quota adapter: initial read + update path, 5h/week mapping.
- [ ] (1) Codex reconnect/stale/unavailable handling + fixtures.
- [ ] (2) Claude Code stable-source spike and adapter boundary.
- [ ] (1) If supported source exists: 5h/week parser/bridge; otherwise honest unavailable state.
- [ ] (2) AI Coding page + Menu Bar live quota summary.
- [ ] (1) 95% deduplicated notifications/Soul events.
- [ ] (1) provider tests.

P2:
- [ ] 80% optional threshold.

Exit: quota UX is real-time/event-first where possible, never fabricated.

---
## Day 5 — Cleaner Lite + adaptive performance + scope freeze (11 pts)
**Model route:** Sol/high main; Luna/medium scoped cache work; Astra/high review for performance/safety; Sol/medium tests.
P0:
- [ ] (2) On-demand Cleaner scan framework; no background recursive scans.
- [ ] (2) At least 3 useful developer cache categories with size/risk/explanation.
- [ ] (2) Adaptive sampling: menu-bar-only vs visible page rates.
- [ ] (2) sleep/wake/network lifecycle cancellation/restart review.
- [ ] (2) first Instruments/performance pass and fixes.
- [ ] (1) integration tests / manual failure-state checklist.

P2:
- [ ] safe delete for clearly regenerable category with confirmation.

**Scope freeze at end of Day 5.**

---
## Day 6 — Release candidate + optional Notch (10 pts)
**Model route:** Sol/high fixes; Astra/high full release review; Luna/medium regression/docs/reporting.
P0:
- [ ] (2) Run reviewer across architecture/privacy/performance/tests.
- [ ] (2) Fix all critical/high findings.
- [ ] (1) accessibility + Reduce Motion + keyboard pass.
- [ ] (1) offline, provider unavailable, malformed data validation.
- [ ] (1) Launch at Login/settings polish.
- [ ] (1) sustained idle/menu-bar performance validation.
- [ ] (2) README/install/privacy/limitations/screenshots draft.

P2 only if schedule GREEN:
- [ ] Notch presentation prototype using only stable/public mechanisms; must fallback to Menu Bar.

Exit: release candidate. No new modules.

---
## Day 7 — Ship v0.1 (10 pts)
**Model route:** Sol/high release fixes; Luna/medium release docs/checklists; Astra/high only for final high-risk review/blocker.
P0:
- [ ] (2) full clean build + tests.
- [ ] (2) regression pass on System/Soul/Network/Dev/AI/Cleaner.
- [ ] (1) final performance sanity check.
- [ ] (1) final privacy/log scan.
- [ ] (1) version/license/changelog/contributing.
- [ ] (1) release build packaging/signing/notarization plan or completed path available to the owner.
- [ ] (1) final README/GIF/screenshots.
- [ ] (1) write `reports/FINAL.md` with shipped/deferred/known limitations/next v0.2 items.

No P2 feature work on Day 7.

Exit: releasable v0.1 repository/build and truthful documentation.
