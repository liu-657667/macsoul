# START HERE

This repository is a **7-day Codex-first implementation harness** for MacSoul.

## First action
If the repository contains no app code yet, give Codex this instruction:

> Read `AGENTS.md`, `START-HERE.md`, `docs/STATUS.md`, `docs/DESIGN.md`, `docs/ARCHITECTURE.md`, and `docs/7-DAY-PLAN.md`. Then read `prompts/KICKOFF.md` and execute Day 1 only. Do not implement later days. Update status and the Day 1 report before finishing.

After Day 1, use the corresponding `prompts/DAY-0N.md` each day.

## The release target
By the end of Day 7, MacSoul v0.1 should provide:
- Menu Bar quick view + native dashboard.
- System: CPU, memory pressure, disk, battery, top developer processes.
- Soul: state transitions, cooldown, recovery messages.
- Network: public IP, proxy/VPN hints, basic connectivity.
- Dev: Java/Node/Python/Go active versions + listening ports.
- AI quota: Codex and Claude Code 5h + 1-week windows when verifiably available.
- Cleaner Lite: on-demand developer cache scan/explanation.
- Performance and release hardening.

## Universal vs Notch UI
**Menu Bar is mandatory and universal.**
A MacBook notch presentation is a P2 enhancement. If implemented, it mirrors existing state and must gracefully disappear on unsupported displays. It cannot own unique functionality.

## Do not ask the AI to "build everything"
Run one day/milestone at a time. The harness deliberately forces checkpoints because fast agentic coding can create architecture debt faster than a human can review it.
