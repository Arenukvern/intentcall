---
'intentcall_schema': minor
---

Wire encode + Dart-literal recovery (ADR 0031): complex tool arguments now
round-trip the string-only service-extension wire. New exports
`wireArgumentsForServiceExtension` / `wireValueForServiceExtension` encode
maps and lists to JSON text before an extension call (Flutter's binding
flattens parameters via `toString()`, which mangled them); coercion decodes
JSON first and recovers Dart `toString()` shapes with the conservative
`tryDecodeDartMap` / `tryDecodeDartList` / `tryDecodeDartLiteral` parsers
instead of throwing `FormatException` out of object- and array-typed
arguments — undecodable text now passes through for an honest validation
refusal. Also fixes `_parseWireJsonMap` decoding the JSON codec constant
instead of the string it was given, so open-object string entries actually
decode.
