# Daily Close Review

Act as release owner, not implementer first.

Read today's plan, `docs/STATUS.md`, git diff/status, test results, and today's report.

Verify:
- claimed tasks actually meet acceptance,
- build/tests evidence exists,
- no hidden P0 remains,
- performance/privacy constraints were not violated,
- schedule color is correct,
- carry-over is correctly prioritized.

Use the reviewer subagent for a targeted read-only audit if the change is non-trivial.

Then update `docs/STATUS.md` and today's report. If YELLOW/RED, apply `docs/PROGRESS-PROTOCOL.md` and explicitly prepare tomorrow's catch-up queue.
