# Third-Party Code and Provenance

Required by the Technical Design Document, section 24. This file exists from the
first commit and must be updated **before** any third-party code is merged.

## Policy

1. Prefer MIT / BSD / Apache-2.0 or otherwise clearly compatible sources for any
   code reused directly.
2. Treat repositories with missing or unclear licenses as **behavioural and format
   research only** until permission is established in writing.
3. The released AvP2 game source is **not** assumed to be reusable open source.
   Restrictive licensing applies. Do not copy its code or code expressions into
   this repository.
4. If restricted source is consulted for a subsystem, record the legal boundary
   here and consider a clean-room workflow: one party writes behaviour and format
   notes, a different party implements from those notes without reading source.
5. Never commit original AvP2 assets, extracted levels, textures, models, sounds,
   or other copyrighted game content.

## Status

No third-party code has been reused yet. Nothing in this repository is derived
from any source listed below.

## Candidate references (TDD section 25)

Each entry must have its licence verified and recorded before any reuse.

| Project | Intended use | Licence | Status |
|---|---|---|---|
| [gorez](https://github.com/K4rian/gorez) | REZ archive parsing reference | *unverified* | Reference only |
| [godot-dtx-reader](https://github.com/haekb/godot-dtx-reader) | DTX decoding | *unverified* | Reference only |
| [godot-dat-reader](https://github.com/haekb/godot-dat-reader) | DAT / Talon v70 world parsing | *unverified* | Reference only |
| [godot-abc-reader](https://github.com/haekb/godot-abc-reader) | ABC model parsing | *unverified* | Reference only |
| [io_scene_lithtech](https://github.com/haekb/io_scene_lithtech) | ABC / model structure reference | *unverified* | Reference only |
| [DAT-Reader](https://github.com/burmaraider/DAT-Reader) | World viewing / export research | *unverified* | Reference only |
| [Released AvP2 source](https://github.com/realforce212/AVP) | Architecture / behaviour reference | Restrictive | **Research only — do not copy** |

## Reuse log

Record every reused library, format reader, or tool here: project, commit or
version, licence, where it is used, and who verified it.

_(empty)_
