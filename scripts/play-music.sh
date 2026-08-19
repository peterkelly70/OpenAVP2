#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Plays a music track straight out of an AvP2 REZ archive.
#
#   scripts/play-music.sh <archive.rez> [logical/path.wav]
#
# With no track given, plays the longest track under Music/WaveTracks.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"

if [ $# -lt 1 ]; then
    echo "usage: $(basename "$0") <archive.rez> [logical/path.wav]" >&2
    echo "example: $(basename "$0") '/path/to/Aliens vs. Predator 2/AVP2.REZ'" >&2
    exit 2
fi

exec "$GODOT" --path "$ROOT" --audio-driver PulseAudio demo/music_test.tscn -- "$@"
