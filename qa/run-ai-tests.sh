#!/bin/bash
# Run from any directory. All build products and optional UI snapshots stay outside the repository.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$(mktemp -d "${TMPDIR:-/tmp}/sovext-ai-tests.XXXXXX")"
trap 'rm -rf "$BUILD"' EXIT
SRC="$ROOT/SovietExtension/SovietExtension"
xcrun --sdk macosx clang -isysroot "$(xcrun --sdk macosx --show-sdk-path)" \
    -fobjc-arc -fmodules -Wall -Wextra -Werror -Wno-unused-parameter \
    -framework Foundation -framework AppKit -framework Security -I "$SRC" \
    "$ROOT/qa/ai_tests.m" "$SRC/YMAIService.m" "$SRC/YMAIPromptStore.m" "$SRC/YMAISettings.m" "$SRC/YMAIWindowController.m" \
    -o "$BUILD/ai-tests"
if [[ "${1:-}" == "--ui" ]]; then
    OUT="${2:?Usage: bash qa/run-ai-tests.sh --ui /absolute/output/directory}"
    mkdir -p "$OUT"
    "$BUILD/ai-tests" "$OUT"
else
    "$BUILD/ai-tests"
fi
