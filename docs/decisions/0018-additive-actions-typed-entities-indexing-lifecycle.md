# 0018. Additive Actions, Typed Entities, and Indexing Lifecycle

Date: 2026-06-29

## Status

Accepted

## Context

ADR 0016 defines how generated platform surfaces dispatch work to Dart or an
inline runtime. ADR 0017 defines the first Apple inline runtime tracks. The next
platform lane needs to cover richer discovery: user-facing actions, typed app
entities, and the lifecycle that keeps indexed or donated records fresh.

This must stay additive. IntentCall's behavior source of truth remains Dart:
`AgentRegistry` owns actions and handlers, while app-owned Dart code owns the
domain data used to create snapshots. Platform projections may publish metadata,
entity identifiers, display data, and indexing records, but they must not become
the canonical application database.

Apple is the first concrete projection because App Intents has typed entity and
query concepts and can participate in Shortcuts, Siri, Spotlight, and related
system discovery. The core model should remain neutral so later Android,
Windows, web, or agent ecosystem projections can reuse the same source concepts
without inheriting Apple-only names.

Apple query and indexing code can be called while Flutter is cold. It therefore
cannot depend on a live Flutter engine or synchronous Dart registry call for
entity lookup. The native side needs a durable app-owned cache derived from
Dart-owned snapshots.

## Decision

IntentCall treats L3 as an additive projection lane:

- Actions remain normal registry entries. Platform-specific publication hints
  decide whether an action appears in a shortcut, assistant, index, or protocol
  artifact.
- Typed app entities are projections of app-owned Dart domain data. Dart emits a
  snapshot with stable ids, type names, display fields, search/index fields, and
  the minimal payload needed to route later actions.
- Indexing and donation are lifecycle operations over those snapshots. Dart owns
  refresh, delete, and prune decisions; platform code stores the latest
  projection in a durable native cache.
- Native query/indexing implementations read the native cache first because the
  Dart runtime may be unavailable. They may route selected actions back through
  existing dispatch modes, but they must not treat native cache data as the
  product source of truth.
- Projection metadata is additive to the current manifest and registry model. It
  does not replace `dispatchMode`, `surfaces`, `AgentRegistry`, or app-owned
  authorization policy.

For Apple, this means generated artifacts may introduce App Intents entity,
query, shortcut, and indexing/donation scaffolds that read the durable native
cache and route executable actions through the existing open-app or inline
runtime contracts. Apple remains the first projection, not the core vocabulary.

## Consequences

Good:

- Entity-aware discovery can be documented without changing the current action
  execution contract.
- Dart remains the source of truth for snapshots and app behavior.
- Apple entity/query/indexing code can work when Flutter is cold by reading a
  durable native projection cache.
- The same neutral lifecycle can later map to non-Apple surfaces.

Tradeoffs:

- Apps must implement a snapshot refresh lifecycle rather than relying on live
  Dart during native query callbacks.
- Native caches introduce freshness and pruning responsibilities.
- Generated entity schemas and cache files increase the amount of artifact
  surface that must be kept synchronized and tested.
- Indexing/donation proof requires app-level evidence; repository tests can only
  prove emitted shapes and local cache behavior.

Neutral:

- This decision does not require every action to have typed entities.
- This decision does not promote every registry entry into a user-visible
  shortcut, Siri phrase, Spotlight result, or indexed action.

## Proof Boundary

Current and future repository proof may cover schema shape, generated artifacts,
native cache read/write behavior, projection pruning, and local SDK typechecks.
That proof is not live Spotlight, Siri, Shortcuts, or product proof.

Generated entity schemas, generated App Intents artifacts, native cache rows,
and indexing/donation helper APIs do not prove:

- that the app was signed and installed correctly,
- that the system accepted donations or indexed records,
- that Siri, Spotlight, or Shortcuts discover the actions or entities,
- that ranking, freshness, privacy, or deletion behavior is product-ready,
- that Flutter consumed a selected action after system invocation.

Donation or indexing proof must come from a signed consuming app installed on
the target OS, or from AppIntentsTesting where that API covers the scenario. A
credible proof also needs to observe the expected query/index result or system
invocation and, for Dart-owned actions, the app/Flutter side consuming the
resulting invocation.

Native cache storage is a projection cache. It is not secure storage, not
exactly-once delivery, not result transport, and not the product database.

## More Information

- [ADR 0016. Dispatch Mode Handoff Contract](0016-dispatch-mode-handoff-contract.md)
- [ADR 0017. Apple Inline Runtime Tracks](0017-apple-inline-runtime-tracks.md)
- [Platform support](/start_here/platform_support)
- [How IntentCall Works](/start_here/how_it_works)
