# Task runner for IntentCall

# List available commands
default:
    @just --list

# Run tests for all packages in the workspace
test:
    dart test packages/intentcall_schema packages/intentcall_core packages/intentcall_session packages/intentcall_mcp packages/intentcall_webmcp packages/intentcall_gemma packages/intentcall_apple packages/intentcall_android packages/intentcall_platform packages/intentcall_codegen packages/intentcall_testing tool/intentcall

# Analyze the Dart code in the workspace
analyze:
    dart analyze .

# Dry-run publishing all packages in order (default)
publish-dry-run:
    dart run tool/intentcall/bin/intentcall.dart publish-all

# Diagnostic package archive validation. Ignores pub warnings such as dirty git,
# but still fails real archive/content validation errors.
publish-dry-run-ignore-warnings:
    dart run tool/intentcall/bin/intentcall.dart publish-all --ignore-warnings

# Check release cleanliness and pub.dev credentials before publishing
publish-preflight:
    dart run tool/intentcall/bin/intentcall.dart publish-preflight

# Check first-publish readiness, including pub.dev package name availability
publish-preflight-first:
    dart run tool/intentcall/bin/intentcall.dart publish-preflight --first-publish

# Execute publishing all packages (requires credentials)
publish-execute:
    dart run tool/intentcall/bin/intentcall.dart publish-all --execute

# Dry-run the package selected by a release tag, for example intentcall_core-v0.1.1
publish-tag-dry-run tag:
    dart run tool/intentcall/bin/intentcall.dart publish-tag --tag {{tag}} --skip-existing

# Publish the package selected by a release tag (CI-only in normal release flow)
publish-tag-execute tag:
    dart run tool/intentcall/bin/intentcall.dart publish-tag --tag {{tag}} --execute --skip-existing

# Check for local IntentCall path dependencies in publishable packages
check-path-deps:
    dart run tool/intentcall/bin/intentcall.dart check-path-deps

# Print hosted dependencies block for the synchronized package train
print-hosted-deps:
    dart run tool/intentcall/bin/intentcall.dart print-hosted-deps

# Print hosted dependencies block for a specific version
print-hosted-deps-version version:
    dart run tool/intentcall/bin/intentcall.dart print-hosted-deps --version {{version}}

# Check docs and skills for hardcoded IntentCall train versions
check-doc-versions:
    dart run tool/intentcall/bin/intentcall.dart check-doc-versions

# Check developer environment health
doctor:
    dart run tool/intentcall/bin/intentcall.dart doctor

# Validate path dependencies and version consistency
validate:
    dart run tool/intentcall/bin/intentcall.dart validate

# Run the shared native adapter and platform bridge contract tests
adapter-contract-test:
    dart test packages/intentcall_testing/test/adapter_contract_test.dart packages/intentcall_mcp/test/mcp_adapter_contract_test.dart packages/intentcall_webmcp/test/webmcp_adapter_contract_test.dart packages/intentcall_gemma/test/gemma_adapter_contract_test.dart packages/intentcall_platform/test/intentcall_invocation_test.dart packages/intentcall_platform/test/web_emitters_test.dart packages/intentcall_platform/test/agent_web_mcp_bootstrap_test.dart packages/intentcall_platform/test/native_emitters_test.dart packages/intentcall_platform/test/native_platform_sync_test.dart packages/intentcall_platform/test/intentcall_flutter_host_test.dart packages/intentcall_platform/test/intentcall_entity_index_test.dart

# List custom agent skills defined in this repository
list-skills:
    @echo "Available Custom Agent Skills:"
    @echo "  - register-intents: Guide to manual and codegen intent registration (skills/register-intents/SKILL.md)"
    @echo "  - write-adapter: Guide to implementing custom platform/transport adapters (skills/write-adapter/SKILL.md)"

# Validate docs.page config and internal doc links
docs-check:
    pnpm run docs:check
