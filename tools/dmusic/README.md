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

## Result

With the patch, every segment of the Marine theme renders. Extracted from
`AVP2.REZ` and rendered at 44.1 kHz stereo:

| Segments | Result |
|---|---|
| 16 of 16 | rendered, no failures |
| `Silence.sgt` | renders silent, as its name promises |
| `March1`–`March5`, `Ambient1`–`Ambient3` | audio present, peak near full scale |
| `TransToMarch1/2`, `TransFromMarch1`–`4`, `TransFromPulse` | render, so transitions are usable |

The remaining warnings, unresolvable instruments and the unparsed `mute` and
`tims` chunks, are not fatal and do not prevent playback.
