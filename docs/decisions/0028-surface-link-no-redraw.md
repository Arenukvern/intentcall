# 0028. Surface link, default WebSocket, no transport redraw

Date: 2026-09-23

## Status

Accepted. Builds on [ADR 0027](0027-agent-usable-projection-results.md). Does not
supersede it.

## Context

A coding agent, a browser page, and an OS agent can each call the same
`AgentRegistry`, but only inside one process. `McpPublishAdapter` is the
coding-agent wire. `POST /agent/invoke` is the page wire when the browser has
no WebMCP. `awaitApp` is the Apple wire when the Mac or iOS app owns the
registry. Those are request/response calls.

They do not form a mesh. A page does not hear a CLI call unless the page made
the request. A CLI MCP server does not hear Siri. Nothing forwards an
invocation id across processes.

The screen must not repaint because a message arrived. A call changes pixels
only when the tool handler runs the app's normal state update, the same path a
button uses. The transport does not call `setState`, patch the DOM, or schedule
a Flutter frame.

WebMCP stays an optional in-page projection for browsers that implement
`document.modelContext`. It is not the bus between web, CLI, and macOS.

## Decision

One process owns the registry. Other surfaces are clients of that process.

1. **`AgentSurfaceLink`** is the composition API:
   - `invoke` sends an `IntentCallInvocationEnvelope` and returns `AgentResult`.
   - `watch` is a stream of `AgentCallObservation` (envelope plus result) for
     every completed call on that link.
2. **`AgentInvocationHub`** is the in-process link. It executes through
   `IntentCallNativeBridge` and records the observation. `observe` records a
   call that some other adapter already executed, so MCP can be included
   without invoking twice.
3. **Default cross-process link** is a WebSocket on the owner process,
   `AgentWebSocketSurface` in `intentcall_platform_sync/io.dart`. Frames are
   JSON: `invoke` with an envelope, `observed` with the envelope and the HTTP
   result shape (`ok`, data or `code`/`message`). Apps that want another
   protocol implement `AgentSurfaceLink` themselves.
4. **The page** keeps `POST /agent/invoke?name=` for browsers without WebMCP.
   `AgentHttpInvoke.through` sends that call through the link, so watchers see
   it. The direct bridge constructor remains for a server that does not mount
   a link.
5. **Redraw** is not part of the link. Handlers update app state or they do
   not. The link never imports Flutter or `dart:html`.
6. **Not claimed.** Web, CLI, and macOS do not discover each other. Hosting
   the hub inside the Mac app, then pointing the CLI and the page at its
   WebSocket, is how those pairs share one registry. This ADR does not start
   that socket from `IntentCallFlutterHost`, and it does not route Siri into a
   page or a page into Siri by itself. Flutter MCP Toolkit's VM service
   remains a debug attach, not this link.

## Consequences

Good:

- An app can observe every call that went through the hub, including HTTP and,
  when wired, MCP, without a UI rebuild.
- Browsers without WebMCP still call the registry over HTTP.
- A custom transport replaces the WebSocket by implementing the same two
  methods.

Tradeoffs:

- `watch` is a broadcast stream. Listeners that subscribe after a call miss
  that call.
- MCP calls appear on the hub only when the host passes `onToolCall` into
  `McpPublishAdapter` and forwards it to `observe`. The adapter does not take
  a hub dependency.
- The WebSocket library imports `dart:io`. Web clients import the core link
  types from `intentcall_platform_sync` and talk to the server as a WebSocket
  peer. They do not import `io.dart`.
- Opening the default socket is opt-in. An app calls `AgentWebSocketSurface.serve`.

## Proof boundary

Unit tests cover the hub, the HTTP route through the hub, the WebSocket
round trip, MCP observation forwarded into the hub, and a handler that leaves
an app counter unchanged. They do not prove a browser, a signed Mac app, or a
live three-process web-cli-macos session.

## References

- [ADR 0015](0015-dart-first-native-bridge.md) opt-in WebMCP network fallback.
- [ADR 0027](0027-agent-usable-projection-results.md) result-bearing projections.
