# Audio Formats

Findings from a patched retail installation. TDD section 13 deferred audio
decoder requirements until a real installation could be inventoried; this is
that inventory.

## Sound effects and speech: WAV, but only 30% plain PCM

4,185 WAV files in `SOUNDS.REZ`, by container format tag:

| Format | Count | Share | Godot support |
|---|---|---|---|
| MP3 in a RIFF/WAVE container | 1,869 | 44.7% | Payload can feed `AudioStreamMP3` |
| PCM | 1,256 | 30.0% | `AudioStreamWAV.load_from_buffer` directly |
| IMA ADPCM | 1,060 | 25.3% | Needs decoding to PCM |

Verified: `AudioStreamWAV.load_from_buffer` loads the PCM third unchanged, and
rejects the rest with "Format not supported for WAVE file (not PCM)".

So an audio converter is required for roughly 70% of the game's sounds. Both
remaining cases are tractable and neither needs a third-party library:

- **MP3 in WAV** is an MP3 bitstream inside a RIFF container. Locate the `data`
  chunk and hand its contents to `AudioStreamMP3`.
- **IMA ADPCM** is a simple, well-documented 4-bit codec. Godot has an
  `AudioStreamWAV` IMA ADPCM format, so it may be possible to construct the
  stream directly rather than decoding by hand; that needs testing.

This work belongs in the extraction step rather than at runtime, consistent with
[`../decisions.md`](../decisions.md): convert once on import, store PCM or Ogg.

## Music: DirectMusic, and it does not currently work

320 music files: SGT segments, DLS instrument banks, STY styles. This is not a
codec but Microsoft's interactive composition runtime, which assembles music at
playback time from segments according to authored rules.

The segment names show the game uses that adaptivity rather than playing linear
tracks. `M1Theme` alone contains `Silence`, `Ambient1`–`Ambient3`,
`March1`–`March5`, and transition segments `TransToMarch1`, `TransFromMarch2`,
`TransFromPulse`. Music follows game tension. **Pre-rendering the score to flat
audio tracks would destroy this**, so any solution must preserve per-segment
playback and the transitions between segments.

### The sequencing logic is in the data, not in code

Each theme ships a control file, `Music/<Theme>/<Theme>Control.txt`, defining
intensity levels, the segments that play at each, and every transition between
them, with Monolith's own documentation in the comments. See
[`music-control.md`](music-control.md).

This means the sequencing half of adaptive music can be implemented now, from
the data alone, independently of the rendering problem below.

### The game source does not contain the decoder

DirectMusic was a Microsoft DirectX component. Games drove it through COM
interfaces such as `IDirectMusicPerformance`, `IDirectMusicSegment` and
`IDirectMusicLoader`, while the segment parsing and DLS synthesis lived in
Microsoft's `dmusic.dll` and `dmsynth.dll`, shipped with DirectX.

So the released AvP2 source would show which segment plays in which game state,
and how transitions are chosen. It would not contain a decoder, because the game
never had one. For decoding questions the useful references are the public DLS
Level 1/2 specification and Wine's `dmusic`/`dmsynth`, which is LGPL-2.1-or-later
and therefore compatible with this project's licence.

### Prior art

| Project | Licence | State |
|---|---|---|
| [libdmusic](https://github.com/libdmusic/libdmusic) | MIT | Archived since 2019 |
| [GothicKit/dmusic](https://github.com/GothicKit/dmusic) | MIT (Modern Variant) | Active, a full implementation including DLS synthesis to PCM |

GothicKit's `dmusic` is a genuine reimplementation, not a parser: it sequences
segments and renders PCM. Its licence is compatible with GPL-3.0, so it could be
used directly rather than only read.

### Tested against AvP2: one defect, now fixed

Built `dmusic`, extracted `M1Theme` from `AVP2.REZ`, and rendered its segments.
It failed with `DmResult_NOT_FOUND`, for a reason that turned out to be small.

`DmBand_download` skips any instrument whose DLS collection cannot be resolved,
but assigns the failure to the shared `rv`, which is returned after the loop. A
single unresolvable instrument therefore fails the entire band, and the segment
with it.

AvP2 triggers this because its bands legitimately reference collections that are
absent. `March1.sgt` declares 48 band instruments; seven name no collection, and
one asks `Rumble.dls` for a drum kit at bank 0 program 0 that it does not hold.
Real DirectMusic falls back to the default General MIDI set or leaves the channel
silent. Gothic's content does not exercise this, which is why it was not caught.

Scoping the result to the individual instrument fixes it. The patch and the
reasoning are in [`../../tools/dmusic/`](../../tools/dmusic/).

**With that change every segment renders.** All 16 segments of the Marine theme
produce audio at 44.1 kHz stereo, `Silence.sgt` correctly renders silent, and
every transition segment renders, so the adaptive score is fully reproducible.

The remaining warnings are benign: unresolvable instruments are skipped as real
DirectMusic would, and the unparsed `mute` and `tims` chunks do not affect
playback.

### Options

**Render each segment to audio at extraction time, and sequence them at runtime
from the control files.** The game tells DirectMusic what to play, not how; the
what is in the control files and the how is now solved, so OpenAvP2 needs no
DirectMusic at runtime at all. Segments and transitions are rendered
individually, which preserves the adaptivity completely: rendering the score to
a single flat track is what would destroy it.

The patch should go upstream so that others do not have to rediscover it.
