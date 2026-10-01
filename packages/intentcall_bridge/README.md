# intentcall_bridge

Entity open-envelope bridge for cross-app handoff over the
`<scheme>://invoke/...` protocol fallback.

Pigeon-generated Dart↔platform bindings (`intentcall_platform_bridge`)
carry the envelope an invoking agent hands to a host app: which entity
type, which identifier, and how the app should present it. The bridge is
the transport half — `intentcall_core` owns the registry and dispatch
semantics, `intentcall_platform` owns the host-side runners.

Pure Dart surface; the platform halves are federated in
`intentcall_platform_apple` / `intentcall_platform_android`.
