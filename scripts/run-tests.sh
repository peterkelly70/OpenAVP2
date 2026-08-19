#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Runs the GDScript test suite headlessly.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"

"$GODOT" --headless --path "$ROOT" --import
"$GODOT" --headless --path "$ROOT" \
    -s addons/gut/gut_cmdln.gd \
    -gdir=res://tests -gprefix=test_ -gexit
