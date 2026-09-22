# 0029. Local discovery for web, CLI, macOS, and MCP

Date: 2026-09-23

## Status

Accepted. Extends [ADR 0028](0028-surface-link-no-redraw.md).

## Context

Web, CLI, macOS, and MCP can call one `AgentRegistry` only when they already
share a process or already know a URL. Nothing published that URL. A browser
cannot read a filesystem directory. A CLI cannot see a page's
`document.modelContext`. Siri cannot see an MCP stdio session.

The screen still must not redraw because a peer connected or a call finished.
Discovery only exchanges addresses and invocations.

## Decision

The process that owns the registry may publish an `AgentLinkAnnouncement`.

1. **Dart peers** (CLI, macOS, MCP) read
   `~/.intentcall/links/<protocolScheme>.json`. `find` confirms the record
   with `GET /agent/discover` on that host. A dead process does not match.
2. **Browser peers** cannot read that directory. The same server answers
   `GET /agent/discover` and `POST /agent/invoke`, and upgrades
   `/agent/link` to the WebSocket from ADR 0028. A page that knows the origin,
   including one the CLI opened, uses those paths. A page that does not know
   the origin can try the record's `discover` URL only if something local
   handed it that URL.
3. **Tool list** is `{"op":"list"}` on the WebSocket. The answer is
   `{"op":"listed","tools":[...]}` from the owner's registry. MCP serve
   `--scheme` builds a proxy registry from that list and forwards each
   `tools/call` over the socket. It does not copy handler code.
4. **CLI** `link discover` and `link call` use the directory. **Flutter**
   publishes only when `IntentCallFlutterHost.bindRegistry` is called with
   `publishSurfaceLink: true` and a protocol scheme. The default stays off.
5. **Redraw** is unchanged. Discovery and `watch` do not touch UI state.

WebMCP remains optional and in-page. It is not how these peers find each other.

## Consequences

Good:

- A CLI can find a running Mac app, list its tools, and call one.
- A page served beside the link, or pointed at its origin, can call the same
  registry without WebMCP.
- An MCP client can attach to that owner with `intentcall mcp serve --scheme`.

Tradeoffs:

- The directory is local to the user account. It is not a network registry.
- `find` treats a failed discover request as absence. A slow owner looks down.
- Two live owners for one scheme: the newer file wins, then HTTP must agree.
- Publishing opens a localhost port. Apps that do not pass
  `publishSurfaceLink: true` do not listen.
- This is not a proof that Siri, a browser, and a CLI are connected on one
  machine at once. The tests use loopback peers.

## References

- [ADR 0027](0027-agent-usable-projection-results.md)
- [ADR 0028](0028-surface-link-no-redraw.md)
