# Format Notes

> Archives are extracted once up front rather than read at runtime; see
> [`../decisions.md`](../decisions.md). Format readers are therefore import-time
> code, and clarity matters more than throughput.

Reverse-engineering notes for the LithTech Talon binary formats used by AvP2.
One document per format. Record structure layouts, version differences, and any
observed quirks, with the fixture that demonstrates them.

| Format | Purpose | Notes | Stage |
|---|---|---|---|
| REZ | Archive container | [`rez.md`](rez.md) — header verified, directory pending | 1 |
| DTX | Textures | [`dtx.md`](dtx.md) — verified, reader implemented | 2 |
| DAT | Worlds (Talon v70) | [`dat.md`](dat.md) — header and objects verified; geometry pending | 3 |
| ABC | Models, skeletons, animation | `abc.md` | 6 |
| WAV, SGT/DLS/STY | Audio and music | [`audio.md`](audio.md) — inventoried; rendering blocked | 13 |
| Control files | Adaptive music sequencing | [`music-control.md`](music-control.md) — fully documented | 13 |

## Method

These documents are the deliverable that makes independent implementation both
possible and defensible. Study whatever references help — all of the projects in
`THIRD_PARTY.md` may be read freely — then record what you learned **here, in
your own words**, and implement from these notes rather than from someone else's
source.

A format document should contain:

- Header layout: offsets, types, endianness, magic values.
- Version differences, and which AvP2 data actually exercises them.
- Field meanings, including flags and enumerations.
- Quirks, with the file that demonstrates each one.
- Anything still unknown, stated as unknown.

Formats are facts and are not owned by anyone. Source text is. Do not paste code
from a reference implementation into these notes or into `src/` unless that
reference is permissively licensed and recorded in the reuse log.

## Provenance

Notes may be written from observation of files in a legally obtained
installation, from public documentation, or from any reference implementation.
If a note is derived from the released AvP2 source, mark it clearly and follow
the clean-room process in `THIRD_PARTY.md`.

Never paste original game data into these documents.
