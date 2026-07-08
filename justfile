# Task runner for IntentCall

# List available commands
default:
    @just --list

# Run tests for all packages in the workspace
test:
    dart test packages/intentcall_schema packages/intentcall_core packages/intentcall_session packages/intentcall_mcp packages/intentcall_webmcp packages/intentcall_gemma packages/intentcall_apple packages/intentcall_android packages/intentcall_platform_sync packages/intentcall_hooks packages/intentcall_codegen packages/intentcall_cli packages/intentcall_platform packages/intentcall_testing tool/intentcall

# Manifest freshness gate (build_runner catalog + export --check)
manifest-export-check:
    cd packages/intentcall_codegen/example && dart pub get && dart run build_runner build
    dart run intentcall_cli:intentcall manifest export --check --project-dir packages/intentcall_codegen/example
    cd packages/intentcall_cli/test/fixtures/codegen_dart_project && dart pub get && dart run build_runner build
    dart run intentcall_cli:intentcall manifest export --check --project-dir packages/intentcall_cli/test/fixtures/codegen_dart_project
    cd packages/intentcall_cli/test/fixtures/flutter_project && dart pub get && dart run build_runner build
    dart run intentcall_cli:intentcall manifest export --check --project-dir packages/intentcall_cli/test/fixtures/flutter_project
    cd packages/intentcall_cli/test/fixtures/jaspr_web_project && dart pub get && dart run build_runner build
    dart run intentcall_cli:intentcall manifest export --check --project-dir packages/intentcall_cli/test/fixtures/jaspr_web_project

# ADR 0019 validation gates
adr-gates:
    just manifest-export-check
    just manifest-parity
    just platform-sync-check

# Phase 1 hook spine gate (ADR 0024)
platform-hooks-check:
    dart test packages/intentcall_platform_sync/test/platform_hook_templates_test.dart
    dart test packages/intentcall_platform_sync/test/platform_hooks_init_test.dart
    dart test packages/intentcall_cli/test/command_runner_test.dart

# Layer 5 projection pipeline gate (ADR 0022/0023/0024)
projection-pipeline-check:
    dart test packages/intentcall_platform_sync/test/manifest_merger_test.dart
    dart test packages/intentcall_platform_sync/test/dense_manifest_test.dart
    dart test packages/intentcall_codegen/example/test/manifest_projection_test.dart
    dart test packages/intentcall_platform_sync/test/native_emitters_test.dart
    dart test packages/intentcall_platform_sync/test/projection_alignment_test.dart
    dart test packages/intentcall_platform_sync/test/apple_surface_matrix_test.dart
    dart test packages/intentcall_platform_sync/test/partial_defaults_platform_scope_test.dart
    dart test packages/intentcall_platform_sync/test/ios_shortcuts_opt_in_test.dart
    dart test packages/intentcall_platform_sync/test/platform_sync_layout_test.dart
    dart test packages/intentcall_platform_sync/test/webmcp_bootstrap_surface_test.dart
    dart test packages/intentcall_cli/test/manifest_entity_export_test.dart
    cd packages/intentcall_codegen/example && dart pub get && dart run build_runner build
    cd packages/intentcall_codegen/example && dart run ../../intentcall_cli/bin/intentcall.dart manifest export --check
    cd packages/intentcall_codegen/example && dart run ../../intentcall_cli/bin/intentcall.dart platform sync --platform web --check

# Manifest export must not emit package-wide intentcall:// resource URIs.
manifest-resource-uri-check:
    dart test packages/intentcall_platform_sync/test/manifest_resource_uri_policy_test.dart

# Verify platform artifact sync on fixture projects
platform-sync-check:
    dart run intentcall_cli:intentcall platform sync --project-dir packages/intentcall_cli/test/fixtures/flutter_project --platform web --check
    dart run intentcall_cli:intentcall platform sync --project-dir packages/intentcall_cli/test/fixtures/jaspr_web_project --platform web --check
    dart run intentcall_cli:intentcall platform sync --project-dir packages/intentcall_cli/test/fixtures/codegen_dart_project --platform web --check

# Apple Swift drift + AppSetGreetingIntent proof against sibling mcp_flutter
mcp-flutter-apple-sync-check:
    dart test packages/intentcall_platform_sync/test/mcp_flutter_apple_sync_test.dart

# Manifest/registry parity gate
manifest-parity:
    dart test packages/intentcall_cli/test/manifest_registry_parity_test.dart

# Analyze the Dart code in the workspace
analyze:
    dart analyze .

# Typecheck the Apple AppIntentsTesting import against a full Xcode toolchain.
# This proves the local Xcode SDK/framework shape only; live runtime proof still
# requires a signed consuming app and an XCTest UI-test target.
apple-appintents-testing-typecheck xcode_app="/Applications/Xcode-beta.app":
    dart run intentcall_cli:intentcall apple-appintents-testing typecheck --xcode "{{xcode_app}}"

# Generate an XCTest UI-test scaffold for AppIntentsTesting runtime proof.
apple-appintents-testing-generate manifest bundle_id output:
    dart run intentcall_cli:intentcall apple-appintents-testing generate-tests --manifest "{{manifest}}" --bundle-id "{{bundle_id}}" --output "{{output}}"

# Generate starter JSON fixtures for AppIntentsTesting sample arguments/entities.
apple-appintents-testing-fixtures manifest sample_arguments_output entity_fixtures_output:
    dart run intentcall_cli:intentcall apple-appintents-testing generate-fixtures --manifest "{{manifest}}" --sample-arguments-output "{{sample_arguments_output}}" --entity-fixtures-output "{{entity_fixtures_output}}"

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

# Check release train metadata without requiring pub resolution
check-release-train:
    dart tool/intentcall/bin/release_train.dart check

# Synchronize release train versions, internal floors, and native podspecs
sync-release-train:
    dart run tool/intentcall/bin/intentcall.dart sync-release-train

# Synchronize release train metadata to a specific version
sync-release-train-version version:
    dart run tool/intentcall/bin/intentcall.dart sync-release-train --version {{version}}

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
    dart test packages/intentcall_testing/test/adapter_contract_test.dart packages/intentcall_mcp/test/mcp_adapter_contract_test.dart packages/intentcall_webmcp/test/webmcp_adapter_contract_test.dart packages/intentcall_gemma/test/gemma_adapter_contract_test.dart packages/intentcall_platform_sync/test/intentcall_invocation_test.dart packages/intentcall_platform_sync/test/web_emitters_test.dart packages/intentcall_platform_sync/test/agent_web_mcp_bootstrap_test.dart packages/intentcall_platform_sync/test/native_emitters_test.dart packages/intentcall_platform_sync/test/native_platform_sync_test.dart packages/intentcall_platform/test/intentcall_flutter_host_test.dart packages/intentcall_platform/test/intentcall_entity_index_test.dart packages/intentcall_platform/test/pigeon_bridge_contract_test.dart

# Regenerate and verify Pigeon bridge outputs are committed (Phase 3 gate)
pigeon-codegen-check:
    cd packages/intentcall_bridge && dart run pigeon --input pigeons/intentcall_platform_bridge.dart
    cp packages/intentcall_platform/ios/intentcall_platform/Sources/intentcall_platform/IntentCallPlatformBridge.g.swift packages/intentcall_platform/macos/intentcall_platform/Sources/intentcall_platform/IntentCallPlatformBridge.g.swift
    git diff --exit-code packages/intentcall_bridge/lib/src/intentcall_platform_bridge.g.dart packages/intentcall_platform/ios/intentcall_platform/Sources/intentcall_platform/IntentCallPlatformBridge.g.swift packages/intentcall_platform/macos/intentcall_platform/Sources/intentcall_platform/IntentCallPlatformBridge.g.swift packages/intentcall_platform/android/src/main/kotlin/dev/intentcall/intentcall_platform/IntentCallPlatformBridge.g.kt

# List custom agent skills defined in this repository
list-skills:
    @echo "Available Custom Agent Skills:"
    @echo "  - register-intents: Guide to manual and codegen intent registration (skills/register-intents/SKILL.md)"
    @echo "  - write-adapter: Guide to implementing custom platform/transport adapters (skills/write-adapter/SKILL.md)"

# Validate docs.page config and internal doc links
docs-check:
    pnpm run docs:check
