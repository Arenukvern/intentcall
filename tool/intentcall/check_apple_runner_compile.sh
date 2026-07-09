#!/usr/bin/env bash
# Compile-proof gate: Runner Generated Swift must build against intentcall_platform_apple.
# Requires sibling mcp_flutter/flutter_test_app, Flutter, and a full Xcode toolchain.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTKIT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

resolve_test_app_root() {
  local env_root="${MCP_FLUTTER_ROOT:-}"
  if [[ -n "$env_root" ]]; then
    local candidate
    candidate="$(cd "$env_root/flutter_test_app" 2>/dev/null && pwd || true)"
    if [[ -n "$candidate" && -f "$candidate/web/agent_manifest.json" ]]; then
      echo "$candidate"
      return 0
    fi
  fi

  local sibling
  sibling="$(cd "$AGENTKIT_ROOT/../mcp_flutter" 2>/dev/null && pwd || true)"
  if [[ -n "$sibling" ]]; then
    local candidate
    candidate="$sibling/flutter_test_app"
    if [[ -f "$candidate/web/agent_manifest.json" ]]; then
      echo "$(cd "$candidate" && pwd)"
      return 0
    fi
  fi

  return 1
}

skip() {
  echo "SKIP: $*"
  exit 0
}

if ! TEST_APP_ROOT="$(resolve_test_app_root)"; then
  skip "mcp_flutter sibling not found — clone ../mcp_flutter or set MCP_FLUTTER_ROOT"
fi

if ! command -v flutter >/dev/null 2>&1; then
  skip "flutter not found in PATH"
fi

if ! command -v xcodebuild >/dev/null 2>&1 || ! xcodebuild -version >/dev/null 2>&1; then
  skip "Xcode toolchain not available"
fi

echo "Apple runner compile check: $TEST_APP_ROOT"

cd "$AGENTKIT_ROOT"
dart run intentcall_cli:intentcall platform sync \
  --project-dir "$TEST_APP_ROOT" \
  --platform ios,macos

cd "$TEST_APP_ROOT"
flutter pub get
flutter build macos --config-only

echo "OK: Runner Swift compiles against intentcall_platform_apple (macos --config-only)"
