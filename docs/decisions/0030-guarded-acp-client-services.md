# 0030. Capability-derived ACP client services

Date: 2026-10-13

## Status

Accepted for implementation. Supports harness ADR 0091 without transferring workspace mutation authority into this transport library.

## Context

The ACP client has an inbound request-handler seam, but initializes with filesystem and terminal capabilities disabled. Arbitrarily advertising capabilities without handlers creates protocol failures; routing requests through a broad handler can expose undeclared effects.

## Decision

Add an optional `AcpClientServices` binding. Filesystem capabilities derive from separately bound read/write handlers. Terminal capability derives only from binding all five standard terminal methods. Every service request requires a nonempty session ID and a live caller-supplied scope authorization predicate. Defaults remain disabled. Unbound standard service methods refuse, even when a generic extension handler exists.

The owner supplies authorized candidate reads, proposed writes, and process lifecycle implementations. This library performs no filesystem mutation, starts no terminal, grants no authority, and does not treat ACP permission approval as workspace promotion. Session authorization and native apply/recovery remain owner responsibilities.

## Consequences

Clients can negotiate actual services while preserving deny-by-default behavior. Existing clients retain their baseline protocol. Capability availability is not evidence of sandboxing, external-agent compatibility or semantic correctness.
