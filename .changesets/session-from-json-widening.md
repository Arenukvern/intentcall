---
'intentcall_session': patch
---

Widen the published `from_json_to_json` constraint to `^0.6.0` (main
already declared it; the published 1.2.1 artifact predates the
widening). Aligns intentcall_session with the oka 0.12 family and
unblocks flutter_mcp_toolkit_server's hosted resolution.
