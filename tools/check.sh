#!/usr/bin/env bash
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
mkdir -p .build-tools
test_log=.build-tools/check.log
timeout 45 godot --headless --path . --xr-mode off -- --smoke-test > "$test_log" 2>&1
cat "$test_log"
if ! rg -q '^SMOKE_OK:' "$test_log" || rg -q 'SCRIPT ERROR:|ERROR:' "$test_log"; then
    exit 1
fi
