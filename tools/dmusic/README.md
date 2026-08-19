# DirectMusic rendering

AvP2's music is DirectMusic: SGT segments played through DLS instrument banks,
sequenced by the control files documented in
[`../../docs/formats/music-control.md`](../../docs/formats/music-control.md).

OpenAvP2 does not implement DirectMusic. It renders each segment to audio once,
during extraction, using [GothicKit/dmusic](https://github.com/GothicKit/dmusic)
(MIT, compatible with this project's licence). The runtime then plays ordinary
audio files and performs the sequencing itself from the control files, so the
score stays adaptive without any DirectMusic at runtime.

## The patch

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

`0001-band-download-tolerate-unresolvable-instruments.patch` scopes the result
to the individual instrument. It is a four-line change and worth sending
upstream.

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
| `m1theme` | 16 / 16 |
| `a2theme` | 34 / 35 |
| `p2theme` | 25 / 28 |
| `a1theme`, `a3s2test` | 22 / 23 each |
| `m2theme` | 21 / 31 |
| `p1theme` | 10 / 11 |
| **Total** | **150 / 167 (90%)** |

Verified audibly: an adaptive sequence assembled from the Marine theme, playing
`Ambient1` into `TransToMarch1` into `March1` and `March2`, then back through
`TransFromMarch2` to `Ambient1`, exactly as `M1Control.txt` specifies.

## Known remaining issues

- **17 segments abort with SIGFPE**, an integer division by zero inside the
  library, concentrated in `m2theme` and `p2theme`. Not yet diagnosed.
- Unresolvable instruments and the unparsed `mute` and `tims` chunks produce
  warnings but do not prevent playback.

### Case sensitivity

Segments reference their banks in the original mixed case, while OpenAvP2
extracts using canonicalised lowercase paths. On a case-sensitive filesystem the
resolver must normalise the requested name or every bank misses and the renderer
crashes on the resulting null collections. `render.c` lowercases before opening;
any other consumer of extracted content needs to do the same.
