# MacSoul MVP Execution Plan

This file is both backlog and state handoff for coding agents. Update checkboxes and the `Current focus` section as work progresses.

## Current focus
**Milestone 0 — Repository + app foundation**

## Milestone 0 — Foundation
- [ ] Create native macOS Xcode project named `MacSoul`.
- [ ] Add unit-test target.
- [ ] Establish source folders from `ARCHITECTURE.md`.
- [ ] Implement menu-bar item/popover shell.
- [ ] Implement main window with Overview/System/Network/AI Coding/Dev/Settings navigation.
- [ ] Add typed mock snapshots and inject them into views.
- [ ] Build mocked Overview matching `UI-SPEC.md`.
- [ ] Add localization resources for UI/Soul text.
- [ ] Confirm build and tests.

**Exit:** app launches, popover works, navigation works, Overview renders mock data, no real monitors yet.

## Milestone 1 — System monitoring
- [ ] Aggregate CPU provider.
- [ ] Memory + pressure provider.
- [ ] Disk provider.
- [ ] Battery provider.
- [ ] Process summary provider.
- [ ] System page and Overview wiring.
- [ ] Unit tests for formatters/provider transformations.

**Exit:** real System telemetry works without blocking UI.

## Milestone 2 — Soul v1
- [ ] Soul domain models.
- [ ] CPU sustained-threshold + hysteresis logic.
- [ ] Memory-pressure states.
- [ ] Disk/battery states.
- [ ] Cooldown/deduplication.
- [ ] Recovery transitions.
- [ ] Localized message catalog.
- [ ] Soul header/popover integration.
- [ ] Unit tests for state machine.

**Exit:** machine reacts to transitions without spam.

## Milestone 3 — Dev environment
- [ ] Safe cancellable command runner.
- [ ] Java provider.
- [ ] Node provider.
- [ ] Python provider.
- [ ] Go provider.
- [ ] Runtime caching.
- [ ] Listening-port provider.
- [ ] Dev page.
- [ ] Terminate/force-kill confirmations.
- [ ] Parser tests with fixtures.

**Exit:** active runtimes and listening ports are useful from one page.

## Milestone 4 — Network
- [ ] NWPathMonitor integration.
- [ ] PublicIPProvider abstraction + first provider.
- [ ] Optional IP metadata provider.
- [ ] Environment proxy inspection.
- [ ] macOS system proxy inspection.
- [ ] Tunnel-interface hints.
- [ ] Connectivity probes.
- [ ] Network page + Overview wiring.
- [ ] IP-change/network-loss Soul events.

**Exit:** IP/proxy/connectivity state is truthful and failure tolerant.

## Milestone 5 — AI quota
### Codex
- [ ] Detect Codex installation.
- [ ] Implement app-server transport adapter.
- [ ] Read rate-limit buckets.
- [ ] Select 5h and weekly windows by duration/semantics.
- [ ] Render reset times and unavailable states.
- [ ] Fixture-based tests.

### Claude Code
- [ ] Detect Claude Code installation.
- [ ] Perform documented-integration spike.
- [ ] Record chosen stable source or explicitly record "quota unavailable" for this release.
- [ ] If source is supported, implement adapter + fixtures/tests.

### Common
- [ ] AI Coding page.
- [ ] Overview summary.
- [ ] 95% optional notifications.
- [ ] Soul quota messages.

**Exit:** no invented quota values; Codex uses supported source; Claude degrades honestly when unsupported.

## Milestone 6 — Release hardening
- [ ] Settings behavior.
- [ ] Launch at login.
- [ ] Offline/unavailable review.
- [ ] Accessibility pass.
- [ ] Reduce Motion pass.
- [ ] Sleep/wake and cancellation review.
- [ ] Idle CPU/memory profiling.
- [ ] README screenshots/GIF.
- [ ] LICENSE + CONTRIBUTING + changelog.
- [ ] Release build/signing plan documented.

**Exit:** v0.1 is something the author can leave running daily.

## Deferred explicitly
- Cleaner
- Timeline/history
- Daily report
- Project mapping
- Docker deep management
- token/cost analytics
- AI model routing/advice
