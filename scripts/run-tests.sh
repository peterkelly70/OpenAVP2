#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Runs the GDScript test suite headlessly.
#
# Fails if any test script could not be loaded. GUT skips an unparseable script
# with a warning and still reports success, so without this check the suite can
# silently shrink and a green run means nothing.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
OUTPUT="$(mktemp)"
trap 'rm -f "$OUTPUT"' EXIT

"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1

set +e
"$GODOT" --headless --path "$ROOT" \
    -s addons/gut/gut_cmdln.gd \
    -gdir=res://tests -gprefix=test_ -gexit 2>&1 | tee "$OUTPUT"
status="${PIPESTATUS[0]}"
set -e

# A script that fails to parse is skipped, not failed. Treat it as a failure.
if grep -qE 'Failed to load script|Ignoring script|Parse Error' "$OUTPUT"; then
    echo
    echo "FAIL: one or more scripts did not load, so part of the suite did not run:"
    grep -E 'Failed to load script|Ignoring script|Parse Error' "$OUTPUT" | sed 's/^/  /'
    exit 1
fi

# A run that collected nothing would otherwise look like success.
if ! grep -qE '^Tests +[0-9]+' "$OUTPUT"; then
    echo
    echo "FAIL: the runner reported no test count."
    exit 1
fi

exit "$status"
