# MacSoul — Day 1 Product Design Lock

## Product sentence

MacSoul is a living developer control center for macOS: system health, network identity, AI coding quota, developer environment and explainable cleanup, expressed through a lightweight Soul personality.

## Day 1 scope

Day 1 is UI and product structure only. No real sensors or external integrations.

Required screens:
- Overview
- System
- Network
- AI Coding
- Dev
- Cleaner
- Settings

Required surfaces:
- Main SwiftUI window
- macOS Menu Bar popover

## Primary hierarchy

1. Soul status / current message
2. System health
3. AI Coding quota (5h + 1 week only)
4. Network identity
5. Developer environment
6. Cleaner summary

## Main window layout

- NavigationSplitView
- Left sidebar around 180–220 pt
- Content area uses a two-column adaptive card grid
- Overview is information-dense but not enterprise-dashboard styled
- Dark mode should feel first-class, but system appearance must be respected

## Overview modules

### Soul
Shows:
- mood: Calm / Busy / Stressed / Critical / Recovering
- short message
- one context action

### System
Shows:
- CPU
- RAM
- Disk
- Battery

### AI Coding
Shows only:
- Codex 5h / Week
- Claude Code 5h / Week
- reset hint when available

### Network
Shows:
- public IP
- region
- proxy
- VPN
- OpenAI / Anthropic / GitHub latency summary

### Dev
Shows:
- Java
- Node
- Python
- Go
- listening port count / examples

### Cleaner
Shows:
- reclaimable size
- developer cache categories
- risk labels

## Soul visual direction

- Minimal, dry, developer-oriented humor
- Not a pet game
- No emoji dependency in the final UI
- Use a simple abstract face glyph for Day 1

Example messages:
- CPU critical: 我的脑子要爆炸了。
- RAM critical: 我的胃快撑爆了。
- recovery: 呼……终于安静了。
- network change: 嗯？我们搬家了？
- Claude 5h > 95%: Claude 快不行了。

## Menu Bar

The Menu Bar is the universal entry point for all Macs.

Popover shows only:
- Soul message
- CPU
- RAM
- Codex 5h
- Claude 5h
- IP / Proxy
- Open MacSoul

Notch support is not part of Day 1.

## Non-goals for Day 1

- Real CPU/RAM polling
- Process scanning
- IP lookup
- Proxy detection
- Codex quota integration
- Claude quota integration
- Runtime discovery
- Port scan
- Cleaner scan
- Notifications
- Notch UI

## UI acceptance

The user should be able to launch the app and understand the full v0.1 product in under 10 seconds even though all data is mocked.
