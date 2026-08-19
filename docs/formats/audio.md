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

### The game source does not contain the answer

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

### Tested against AvP2, and it fails

Built `dmusic` and rendered `M1Theme/March1.sgt` with its instrument banks
extracted from `AVP2.REZ`. Results:

- The segment parses and all referenced DLS banks resolve; nothing is missing.
- Instrument binding fails: `Instrument patch 0:0 not found in band 'Rumble'`,
  and similarly for two patches in `Gongs`.
- Two chunk types are not fully parsed: `mute` and `tims`.
- Forcing playback past the binding failure segfaults.

### Why AvP2 breaks it when Gothic does not

The formats are identical. AvP2 simply uses more of DirectMusic than Gothic
does, and `dmusic` is verified only against Gothic.

| Feature | AvP2 (`M1Theme`) | Consequence |
|---|---|---|
| DLS collections per theme | **18 files**, 44 instruments between them | Instrument lookup must pick the right collection |
| Bank addressing | Bank LSB is significant (`0:1`, `1:1`) | Program number alone is not a unique key |
| Drum kits | Yes — `OrchPerc.dls`, bank `0x80000001` | Bit 31 of the bank field must be honoured |
| Segment tracks | Includes `mute` and `tims` | Unhandled chunk types |

Analysis of the failing case, from the raw data:

- The band requests `dwPatch = 0x80000100`: drum flag set, bank LSB 1,
  program 0.
- `OrchPerc.dls` provides exactly that instrument: `ulBank = 0x80000001`,
  `ulInstrument = 0`.
- So the instrument **is present**. But `dmusic` reported it missing from the
  band named `Rumble`, and `Rumble.dls` contains a single unrelated melodic
  instrument, bank 1 program 82.

The instrument is therefore being looked up in the wrong collection. With
eighteen collections loaded, resolving a band instrument to its collection has
to be exact; Gothic's content has far less to disambiguate, so the defect would
not show up there.

This is a specific, reportable bug rather than a missing feature, which makes
fixing it upstream realistic.

### Options

1. **Fix `dmusic` upstream.** It is MIT, active, and already most of the way
   there: the segment loads and every bank resolves. The gap is collection
   resolution for band instruments, drum-kit bank handling, and two chunk
   types. The analysis above is enough to open a useful issue, and the fix
   looks small.
2. **Ship without music initially.** Nothing blocks the campaign; the 4,185
   effect and speech files carry the game. Music is additive.
3. **Pre-render segments individually** and sequence them in OpenAvP2. Preserves
   adaptivity if each segment and transition is rendered separately, but depends
   on option 1 working first, since rendering is what currently fails.

Option 2 is the immediate stance and option 1 is the goal. Music must not gate
the first playable mission.
