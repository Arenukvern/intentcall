# Task runner for IntentCall

# List available commands
default:
    @just --list

# Run tests for all packages in the workspace
test:
    dart test packages/intentcall_schema packages/intentcall_core packages/intentcall_mcp packages/intentcall_webmcp packages/intentcall_gemma packages/intentcall_apple packages/intentcall_android packages/intentcall_platform packages/intentcall_codegen packages/intentcall_testing

# Analyze the Dart code in the workspace
analyze:
    dart analyze .

# Dry-run publishing all packages in order (default)
publish-dry-run:
    dart run tool/intentcall/bin/intentcall.dart publish-all

# Execute publishing all packages (requires credentials)
publish-execute:
    dart run tool/intentcall/bin/intentcall.dart publish-all --execute

# Check for path dependencies pointing to intentcall/packages
check-path-deps:
    dart run tool/intentcall/bin/intentcall.dart check-path-deps

# Print hosted dependencies block for a specific version
print-hosted-deps version="0.1.0":
    dart run tool/intentcall/bin/intentcall.dart print-hosted-deps --version {{version}}
