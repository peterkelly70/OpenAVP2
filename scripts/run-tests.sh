#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Runs the GDScript test suite headlessly.
#
# Every script is loaded before the suite runs. A script that fails to parse is
# skipped by the test runner with a warning, not failed, so without this check
# a broken helper can silently remove whole test files from the run while the
# run still reports success.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"

"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1

# Fails, naming the offending files, if anything does not parse.
"$GODOT" --headless --path "$ROOT" --script tools/check_scripts.gd

exec "$GODOT" --headless --path "$ROOT" \
    -s addons/gut/gut_cmdln.gd \
    -gdir=res://tests -gprefix=test_ -gexit
