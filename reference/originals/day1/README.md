# MacSoul Day 1 Starter

This pack locks the Day 1 product/UI direction and provides SwiftUI source files for a macOS app shell, Menu Bar popover, and Mock UI.

## What "Mock UI" means

Mock UI is the real interface built against fake local data instead of real system integrations. It lets us validate layout, navigation, information hierarchy, and product feel before touching Mach APIs, process scanning, IP providers, quota providers, etc.

Day 1 goal: the app should *look and behave* like MacSoul, but all numbers are mock values.

## Setup

1. In Xcode, create a new **macOS App** project named `MacSoul` using SwiftUI.
2. Set deployment target to macOS 13+.
3. Replace the generated source files with the `MacSoul/` folder in this starter pack.
4. Build and run.

Later Codex can replace each mock provider with real monitors while keeping the UI contracts intact.

## Day 1 acceptance

- Main window launches.
- Sidebar navigation works.
- Overview renders all core modules.
- Menu Bar icon is visible.
- Menu Bar popover shows Soul, system, AI quota and network summary.
- No real system scanning is performed yet.
