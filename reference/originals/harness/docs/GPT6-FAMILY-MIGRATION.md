# GPT-6 Family Harness Migration

Updated: 2026-09-23

This harness supersedes the earlier Astra + GPT-5.6 Terra worker strategy.

## What changed

Previous routing:
- Astra = main implementation
- GPT-5.6 Terra = explorer/tester
- Astra = reviewer

Current routing:
- **GPT-6 Sol = default main implementation**
- **GPT-6 Luna = focused/high-volume explorer + reporting work**
- **GPT-6 Astra = architect, hard-blocker escalation, and release reviewer**
- **GPT-6 Sol = tester where code-writing judgment matters**

## What did not change

No product scope reset is required. Keep:
- the 7-day release target;
- Menu Bar as universal primary surface;
- optional Notch experience as P2;
- System/Soul/Network/Dev/AI Quota/Cleaner boundaries;
- Codex and Claude quota scope limited to 5-hour + 1-week windows;
- event-first / adaptive monitoring architecture;
- daily progress reports and catch-up protocol;
- Day 5 scope freeze.

## Why

The new family creates a cleaner division of labor: Sol is optimized for complex coding and agentic workflows, Luna for focused high-volume work, and Astra remains the strongest option for ambiguous end-to-end reasoning and release-critical judgment.
