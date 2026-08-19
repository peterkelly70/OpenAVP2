# Music Control Files

AvP2's adaptive music is **data-driven**, not compiled into the game. Each theme
ships a `<Theme>Control.txt` alongside its segments, and Monolith left the format
documented in comments inside the files themselves.

Files: `Music/M1Theme/M1Control.txt`, `M2Control.txt`, `A1Control.txt`,
`A2Control.txt`, `P1Control.txt`, `P2Control.txt`, plus `A3s2Test/A1Control.txt`.
There is also a 31 KB `ATTRIBUTES/MUSIC.txt` in `AVP2P5.REZ`.

Each file opens with the header `LithTech DirectMusic Level Control File`.

## Why this matters

The hard part of recreating adaptive music is knowing which segment plays in
which game state and how transitions are chosen. That logic is **here**, in
plain text, not in the game's compiled code. Reproducing it needs no access to
the game source; it needs a parser for this file and a music state machine.

That splits the music problem cleanly in two:

1. **Sequencing** — intensities, transitions, timing. Fully specified by these
   files. Implementable now.
2. **Rendering** — turning an SGT segment plus its DLS banks into audio. Blocked
   on the `dmusic` defect described in [`audio.md`](audio.md).

## Directives

### Synthesiser configuration

| Directive | M1Theme value | Meaning |
|---|---|---|
| `NUMINTENSITIES` | 10 | Number of intensity levels defined |
| `INITIALINTENSITY` | 1 | Intensity to start at; 0 means none |
| `INITIALVOLUME` | 0 | Volume in decibels, may be negative |
| `VOLUMEOFFSET` | -500 | Additional offset |
| `PCHANNELS` | 256 | Performance channels |
| `VOICES` | 64 | Simultaneous voices |
| `SYNTHSAMPLERATE` | 44100 | Synthesiser rate |
| `REVERB` | ON | Reverb enable |
| `REVERBINGAIN` | 0.0 | Input gain, dB |
| `REVERBMIX` | -10.0 | Wet/dry mix, dB; 0 is fully wet |
| `REVERBTIME` | 3200.0 | Decay, milliseconds |
| `REVERBHIGHFREQRTRATIO` | 0.001 | HF to global reverb time ratio |

### Resource declarations

    STYLE     <file.sty>
    BAND      <style name> <band name>
    CHORDMAP  <file.crd>
    SECONDARYSEGMENT <segment> [default enact time]
    MOTIF     <style name> <motif name> [default enact time]

Any number of each may appear. A `DLS` directive also exists for downloadable
sound banks, though M1Theme declares none and relies on the banks the segments
reference.

### Intensities

    INTENSITY <number> <times to loop> <intensity when finished> [segments...]

`-1` loops forever; a finish target of `0` stops. M1Theme:

| Intensity | Segment | Loops | Then |
|---|---|---|---|
| 1 | `Silence.sgt` | 0 | 1 |
| 2, 3, 4 | `Ambient1`–`Ambient3` | 0 | cycles 2 → 3 → 4 → 2 |
| 5–9 | `March1`–`March5` | 0 | cycles 5 → 6 → … → 9 → 5 |
| 10 | `Silence.sgt` | 0 | 10 |

So the score is two loops, calm and combat, plus two silence states. The game
raises and lowers intensity; the file decides what that sounds like.

### Transitions

    TRANSITION <from> <to> <when> <AUTOMATIC|MANUAL> [segment] [chordmap]

`when` is one of `SEGMENT`, `MEASURE`, `BEAT`, `IMMEDIATE`, `GRID` or `DEFAULT`
(taken from the segment). `AUTOMATIC` uses DirectMusic's own transition
machinery; `MANUAL` plays a named bridge segment, or simply starts the new
intensity when none is given.

Only transitions that are not plain `MEASURE MANUAL` need declaring. M1Theme
defines about 25, for example:

    TRANSITION 1 5  IMMEDIATE MANUAL TransToMarch1.sgt
    TRANSITION 3 1  MEASURE   MANUAL TransFromPulse.sgt
    TRANSITION 7 2  MEASURE   MANUAL TransFromMarch3.sgt
    TRANSITION 9 10 IMMEDIATE MANUAL

Two patterns are worth noting. Entering combat from any calm state routes
through a `TransToMarch` bridge, and leaving combat routes through the
`TransFromMarch` matching the *current* March segment, so the exit is musically
continuous. Transitions into intensity 10, the hard stop, are always
`IMMEDIATE`.

## Implementation note

A control file parser and the intensity state machine are worth building before
the rendering problem is solved. They are independent of it, they are testable
against these files without any audio output, and having them means that when
segment rendering works the music system is already correct.
