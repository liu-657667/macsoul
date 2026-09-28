# Soul Engine

## Purpose
Convert technical state transitions into restrained human-readable reactions. The system is deterministic and local.

## Global states
`idle`, `calm`, `busy`, `stressed`, `critical`, `recovering`

Special contexts include `brainOverload`, `memoryFull`, `storageFull`, `lowEnergy`, `networkLost`.

## State transition rules
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

## Sample copy
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
