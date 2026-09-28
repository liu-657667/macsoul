# Soul Engine Specification

## Purpose
Soul makes system telemetry memorable without reducing diagnostic accuracy. It reacts to meaningful state transitions and always yields to the Utility layer for details.

## 1. Global states
Base states:
- calm
- busy
- stressed
- critical
- recovering

Special presentations may include:
- brainOverload
- memoryFull
- lowEnergy
- storageFull
- networkLost
- agentArmy (optional/P1)

The domain should avoid an explosion of mutually-exclusive enums. Prefer independent subsystem states plus a presentation-priority resolver.

## 2. Metaphors
- CPU → brain
- memory → stomach
- disk → home
- battery → energy
- network → world connection
- ports → doors
- AI quota → partner energy

## 3. Threshold model
Thresholds are defaults and must be constants/config, not scattered magic numbers.

### CPU
- <70%: normal
- 70–85% sustained: busy
- 85–95% for ~15s: stressed
- >=95% for ~20s: critical
- recover when <60% for ~30s

Use hysteresis; a 94↔95 oscillation must not spam state changes.

### Memory
Primary signal is memory pressure:
- green/normal → normal
- warning/yellow → full/stressed
- critical/red sustained ~15s → memoryFull

Used-percent can influence wording but must not override healthy pressure by itself.

### Disk
- <85% used: normal
- 85–95%: crowded
- >=95%: storageFull

### Battery
- <=20%: tired
- <=10%: exhausted
- <=5%: critical
- charging transition after low battery may emit a recovery message

### Network
- path unavailable → networkLost after debounce
- restored after networkLost → recovery
- public IP country/ASN change may create an in-app event, not a native alert

### AI quota
For each 5h/week window when available:
- <80% normal
- >=80% tired
- >=95% exhausted

AI quota never drives recommendations about provider/model choice.

## 4. Priority resolver
Suggested presentation priority:
1. system-critical safety/usability state (battery critical, memory critical, disk critical)
2. network lost
3. CPU critical
4. quota exhausted
5. stressed/busy
6. calm

If multiple critical states exist, show one in the Soul header and show all actual metrics in their cards.

## 5. Cooldowns
- Same subsystem + severity message: minimum 30-minute cooldown by default.
- A state that remains critical does not repeatedly message.
- Recovery may speak once after a prior stressed/critical state.
- Native notifications have their own stricter deduplication.

## 6. Message catalog
Messages should be stored by localization key and category.

Examples (Chinese copy; English should be localized separately):

### CPU critical
- `我的脑子要爆炸了。`
- `谁在拿我的 CPU 烤东西？`

### CPU recovery
- `呼……终于安静了。`

### Memory warning
- `我吃得有点多……`

### Memory critical
- `我的胃快撑爆了。`
- `Chrome、Docker、IDE……你是不是觉得我有三个胃？`

### Memory recovery
- `好多了，我终于能消化一下了。`

### Disk critical
- `家里已经快没地方下脚了。`

### Battery critical
- `我真的需要充电了。`
- `你真的准备让我死在这里吗？`

### Charging recovery
- `啊……活过来了。`

### Network lost / restored
- `我看不到外面的世界了。`
- `回来了。`

### IP changed
- `嗯？我们搬家了？`

### Codex quota >=95%
- `你快把 Codex 榨干了。`

### Claude quota >=95%
- `Claude 快不行了。`

## 7. Actions
Soul presentation may carry one semantic action:
- viewCPU
- viewMemory
- viewDisk
- viewBattery
- viewNetwork
- viewAIQuota
- viewPorts

The UI maps semantic actions to navigation. The domain engine must not know SwiftUI navigation types.

## 8. Anti-patterns
Do not:
- randomly speak without a state change
- generate a new message every sample
- call an LLM for every reaction
- use guilt/manipulation to force behavior
- hide actual diagnostics behind jokes
- show multiple simultaneous speech bubbles
