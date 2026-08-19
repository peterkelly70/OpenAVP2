# DirectMusic rendering

AvP2's music is DirectMusic: SGT segments played through DLS instrument banks,
sequenced by the control files documented in
[`../../docs/formats/music-control.md`](../../docs/formats/music-control.md).

OpenAvP2 does not implement DirectMusic. It renders each segment to audio once,
during extraction, using [GothicKit/dmusic](https://github.com/GothicKit/dmusic)
(MIT, compatible with this project's licence). The runtime then plays ordinary
audio files and performs the sequencing itself from the control files, so the
score stays adaptive without any DirectMusic at runtime.

## The patches

`dmusic` as released fails on AvP2 with `DmResult_NOT_FOUND`. The cause is in
`DmBand_download`:

```c
rv = DmLoader_getDownloadableSound(loader, &instrument->reference, &instrument->dls);
if (rv != DmResult_SUCCESS || instrument->dls == NULL) {
    continue;
}
...
return rv;
```

An instrument whose collection cannot be resolved is deliberately skipped, but
`rv` still holds the failure and is returned once the loop ends. A single
unresolvable instrument therefore fails the whole band, and the segment with it.

AvP2 hits this because its bands legitimately reference collections that are not
present. `March1.sgt` has 48 band instruments, of which seven name no collection
at all and one asks `Rumble.dls` for a drum kit at bank 0 program 0 that it does
not contain. Real DirectMusic falls back to the synthesiser's default General
MIDI set or leaves the channel silent. Gothic's content does not exercise this,
which is why the defect went unnoticed.

The fix scopes the result to the individual instrument.

### 2. Modulo by zero on parts with no variations

`DmPattern_generateMessages` computes

```c
variation_id = 1 << (variation_id % DmPart_getValidVariationCount(part));
```

and `DmPart_getValidVariationCount` returns 0 for a part whose first variation
choice is empty. The modulo then aborts the process with `SIGFPE`. A part with
no valid variations has nothing to contribute, so it is skipped, which is
already how the surrounding code treats an unresolvable part reference.

Both fixes are in
`0001-tolerate-unresolvable-instruments-and-empty-parts.patch`, together about a
dozen lines, and both belong upstream.

### Not a library bug: sentinel segment lengths

Some segments report a length of roughly 3,355,446 seconds, a sentinel meaning
"loop until told otherwise" rather than a real duration. A renderer must cap
this instead of trying to allocate it; `render.c` caps at 120 seconds, which is
ample since the runtime loops the segment anyway.

## Reproducing

```
git clone https://github.com/GothicKit/dmusic
cd dmusic && git apply /path/to/OpenAvP2/tools/dmusic/0001-*.patch
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build
```

## Rendering the whole soundtrack

    DMUSIC=/path/to/dmusic scripts/render-music.sh \
        '/path/to/Aliens vs. Predator 2/AVP2.REZ' /path/to/output

Extracts the music with `tools/extract.gd`, builds `render.c`, and renders one
WAV per segment. Segments are rendered **individually**, never concatenated:
sequencing happens at runtime from the control files, so the score stays
adaptive.

## Results

Across all six themes, 167 segments:

| Theme | Rendered |
|---|---|
| `a1theme` | 23 / 23 |
| `a2theme` | 35 / 35 |
| `a3s2test` | 23 / 23 |
| `m1theme` | 16 / 16 |
| `m2theme` | 31 / 31 |
| `p1theme` | 10 / 11 |
| `p2theme` | 27 / 28 |
| **Total** | **165 / 167 (98.8%)** |

Verified audibly: an adaptive sequence assembled from the Marine theme, playing
`Ambient1` into `TransToMarch1` into `March1` and `March2`, then back through
`TransFromMarch2` to `Ambient1`, exactly as `M1Control.txt` specifies.

## Known remaining issues

Two segments of 167 still fail and are not yet diagnosed:

- `p1theme/cruise2` does not terminate, still running after five minutes.
- `p2theme/ambienta` segfaults.

Unresolvable instruments and the unparsed `mute` and `tims` chunks produce
warnings but do not prevent playback.

### Case sensitivity

Segments reference their banks in the original mixed case, while OpenAvP2
extracts using canonicalised lowercase paths. On a case-sensitive filesystem the
resolver must normalise the requested name or every bank misses and the renderer
crashes on the resulting null collections. `render.c` lowercases before opening;
any other consumer of extracted content needs to do the same.
