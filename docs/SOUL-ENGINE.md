# Soul Engine

## Current implementation versus design examples

Current `MacSoul/Models/SoulEngine.swift` evaluates only CPU and native memory pressure, using `observing`, `calm`, `stressed`, `brainOverload`, `memoryWarning`, `memoryCritical`, `recovering`. CPU >85% for 15s / >95% for 20s, <60% for 30s recovery, memory-pressure priority and 30m category cooldown are implemented. Unknown pressure stays unknown; no used-RAM health inference. Memory warning/critical comes from native pressure events, not a newly imposed sustained timer. Quota eligibility/copy is a separate fresh-applicable-window path, with canonical usedPercent >=95; real critical / quota95% events remain NOT_OBSERVED.

The broader states/contexts, disk, battery, port conflict, network loss/recovery and country-change copy below are **design examples**, not shipped SoulEngine transitions. Low-battery/resting artwork can be previewed using Mock fixtures without implying Live triggers. Region remains NOT_COLLECTED; a listener alone is never a conflict. [Release](RELEASE.md) and dated [System/Soul report](../reports/day-2-system-soul-memory-closeout-2026-09-29.md) retain the actual acceptance scope.

## Purpose
Convert technical state transitions into restrained human-readable reactions. The system is deterministic and local.

## Global states — design vocabulary
`idle`, `calm`, `busy`, `stressed`, `critical`, `recovering`

Special contexts include `brainOverload`, `memoryFull`, `storageFull`, `lowEnergy`, `networkLost`.

## State transition rules — design examples and implemented subset above
Never trigger on one noisy sample. Use sustained thresholds + hysteresis.

Examples:
- CPU > 85% for 15s → stressed
- CPU > 95% for 20s → brainOverload
- recovery only after CPU < 60% for 30s
- memory pressure warning/critical is more important than raw used %
- disk > 95% → storageFull
- battery < 5% and not charging → critical lowEnergy

## Anti-spam
- Same event category: default 30m cooldown.
- Sustained critical state does not repeat.
- Recovery can fire once when returning to safe state.
- Only one top-priority Soul message at a time.

## Sample copy — design examples, not all implemented
CPU critical: `我的脑子要爆炸了。`
CPU recovery: `呼……终于安静了。`
Memory critical: `我的胃快撑爆了。`
Memory recovery: `好多了，终于能消化一下了。`
Disk critical: `我已经快没地方下脚了。`
Battery 5%: `你真的准备让我死在这里吗？`
Port collision: `8080 这扇门已经有人占了。`
Network loss: `我看不到外面的世界了。`
Network recovery: `回来了。`
IP country change: `嗯？我们搬家了？`
Codex 5h >=95% when that window is fresh and applicable: `你快把 Codex 榨干了。`
Claude 5h >=95% when that window is fresh and applicable: `Claude 快不行了。`

## Tests required
Threshold timing, hysteresis, cooldown, priority, recovery, repeated samples, clock/reset handling.

## Evidence guardrails
AI Coding stays quota-only; no agent-session sensor is required for Soul. A listening port alone cannot trigger a conflict claim. Memory pressure, not used RAM %, determines the memory-critical message.
Quota Soul copy and notifications may read only fresh, applicable numeric 5h/Week windows. A Week-only account has no 5h countdown or 5h warning; unreported, failed and stale windows cannot trigger quota copy. This is an eligibility rule, not a claim that live alerts already exist in the Mock App.
