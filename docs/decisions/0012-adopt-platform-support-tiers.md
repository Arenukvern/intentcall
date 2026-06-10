---
status: accepted
date: 2026-06-10
decision-makers: IntentCall maintainers
consulted:
informed:
---

# Adopt platform support tiers for IntentCall

## Context and Problem Statement

IntentCall's public promise is "Register intents. Call them everywhere." The repo already has a real registry/runtime foundation, MCP and WebMCP adapters, and platform artifact emitters for Flutter's web, Android, iOS, macOS, Linux, and Windows targets.

Platform reality is not flat. Apple App Intents, Android AppFunctions, Android App Actions, WebMCP, Windows App Actions, Windows protocol activation, Linux desktop URI handlers, and AAIF ecosystem projects expose different levels of semantic intent support. Treating all of them as equivalent would overclaim current implementation and obscure the fallback path that actually keeps apps callable across devices.

## Decision Drivers

* **Honesty** - document what is implemented now versus roadmap.
* **Portability** - preserve one intent model and one fallback invocation contract.
* **Platform fit** - use native semantic action/tool systems where they exist.
* **Pre-release clarity** - keep `0.1.x` docs ambitious without implying false parity.

## Considered Options

* **Flat "works everywhere" claim** - rejected because it hides the difference between native semantic APIs and protocol launch routing.
* **Native-only scope** - rejected because Linux and some Windows/Android paths need protocol fallback while native support matures.
* **Explicit support tiers** - chosen because it preserves the product vision while keeping implementation claims falsifiable.

## Decision Outcome

IntentCall will describe platform support in tiers:

| Tier | Meaning |
|---|---|
| Native semantic | Platform-recognized tool/action models that preserve intent metadata and structured invocation semantics. |
| Assistant / shortcut fulfillment | Assistant, shortcut, or launcher declarations that route user-visible actions into app intent handling. |
| Protocol fallback | Stable URI/protocol invocation when native semantic support is unavailable or not implemented. |
| Ecosystem alignment | Compatibility with agent ecosystem conventions without claiming an OS-level integration contract. |

Current implementation includes MCP/WebMCP adapters, Apple App Intents artifacts, Android shortcut/deep-link artifacts, web/PWA artifacts, Windows protocol activation artifacts, and Linux `x-scheme-handler/intentcall` artifacts.

Roadmap targets include Android AppFunctions, richer Android App Actions capability generation, Windows App Actions / Agent Launchers, WebMCP `document.modelContext` compatibility, and AAIF ecosystem alignment where relevant.

### Consequences

* Good, because docs can say what exists without shrinking the long-term vision.
* Good, because app authors get a predictable fallback contract: `intentcall://invoke/...`.
* Neutral, because every new platform adapter must declare its support tier.
* Bad, if tier labels drift from implementation; mitigated by keeping `docs/NORTH_STAR.mdx`, `docs/DESIGN_FAQ.mdx`, and platform package READMEs aligned.

## Links

* [NORTH_STAR.md](../NORTH_STAR.mdx)
* [DESIGN_FAQ.md](../DESIGN_FAQ.mdx)
* [PRE_RELEASE.md](../../PRE_RELEASE.md)
