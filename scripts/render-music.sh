#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Extracts AvP2's music from a REZ archive and renders every DirectMusic
# segment to a WAV file, one file per segment.
#
#   scripts/render-music.sh <archive.rez> <out-dir>
#
# Requires a patched GothicKit/dmusic; see tools/dmusic/README.md. The output is
# copyrighted game data and must never enter the repository.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
DMUSIC="${DMUSIC:?set DMUSIC to a built, patched dmusic checkout}"

if [ $# -lt 2 ]; then
    echo "usage: $(basename "$0") <archive.rez> <out-dir>" >&2
    exit 2
fi

archive="$1"
out="$2"
cache="$out/extracted"
rendered="$out/segments"

echo "==> extracting music from $(basename "$archive")"
"$GODOT" --headless --path "$ROOT" --script tools/extract.gd -- "$archive" "$cache" music

echo "==> building renderer"
cc -O2 -o "$out/render" "$ROOT/tools/dmusic/render.c" \
    -I"$DMUSIC/include" -L"$DMUSIC/build" -ldmusic -lm

echo "==> rendering segments"
ok=0; failed=0
for theme in "$cache"/music/*/; do
    name="$(basename "$theme")"
    compgen -G "$theme"'*.sgt' >/dev/null || continue
    mkdir -p "$rendered/$name"
    for segment in "$theme"*.sgt; do
        seg="$(basename "$segment" .sgt)"
        if LD_LIBRARY_PATH="$DMUSIC/build" timeout 180 \
                "$out/render" "$theme" "$seg.sgt" "$rendered/$name/$seg.wav" >/dev/null 2>&1; then
            ok=$((ok + 1))
        else
            failed=$((failed + 1))
            echo "    failed: $name/$seg"
        fi
    done
done

echo "==> $ok segments rendered, $failed failed -> $rendered"
