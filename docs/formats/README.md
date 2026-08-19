# Format Notes

Reverse-engineering notes for the LithTech Talon binary formats used by AvP2.
One document per format. Record structure layouts, version differences, and any
observed quirks, with the fixture that demonstrates them.

| Format | Purpose | Notes | Stage |
|---|---|---|---|
| REZ | Archive container | `rez.md` | 1 |
| DTX | Textures | `dtx.md` | 2 |
| DAT | Worlds (Talon v70) | `dat.md` | 3 |
| ABC | Models, skeletons, animation | `abc.md` | 6 |

## Provenance

These notes may be written from observation of files in a legally obtained
installation, from public documentation, or from permissively licensed
reference implementations. If a note is derived from restricted source, mark it
clearly and follow the clean-room process in `THIRD_PARTY.md`.

Do not paste original game data or source code into these documents.
