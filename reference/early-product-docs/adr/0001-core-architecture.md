# ADR 0001 — Native local-first modular architecture

Status: Accepted

## Context
MacSoul samples system state frequently, touches macOS-specific APIs, lives in the menu bar, and should consume very few resources. It also integrates with external CLI/provider data that may change over time.

## Decision
- Build a native Swift/SwiftUI macOS app.
- Separate domain services from provider implementations.
- Keep external integrations behind protocols.
- Use local deterministic Soul rules.
- Do not introduce a backend service for MVP.

## Consequences
Positive:
- native menu-bar/window behavior
- lower runtime overhead
- stronger privacy story
- provider changes are isolated

Costs:
- macOS-only code
- some system APIs require lower-level Swift/C interop
- provider integration requires careful compatibility handling
