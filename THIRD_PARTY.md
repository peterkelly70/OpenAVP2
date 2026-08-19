# Third-Party Code and Provenance

Required by the Technical Design Document, section 24. This file exists from the
first commit and must be updated **before** any third-party code is merged.

## Policy

OpenAvP2 is licensed **GPL-3.0-or-later**. That determines what may be
incorporated: MIT, BSD and Apache-2.0 code can be brought in, GPL-2.0-only
code cannot, and unlicensed code cannot be used at all.

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

Licences verified 19 August 2026 via the GitHub API. Re-verify before any reuse:
a repository's licence can change, and the absence of a licence file means **all
rights reserved**, not "public domain".

| Project | Intended use | Licence | Inbound to GPL-3.0-or-later? |
|---|---|---|---|
| [gorez](https://github.com/K4rian/gorez) | REZ archive parsing reference | MIT | **Yes** — reuse permitted with attribution |
| [godot-dtx-reader](https://github.com/haekb/godot-dtx-reader) | DTX decoding | MIT | **Yes** — reuse permitted with attribution |
| [godot-abc-reader](https://github.com/haekb/godot-abc-reader) | ABC model parsing | MIT | **Yes** — reuse permitted with attribution |
| [godot-dat-reader](https://github.com/haekb/godot-dat-reader) | DAT / Talon v70 world parsing | **None declared** | **No** — all rights reserved; behaviour reference only unless the author grants a licence |
| [io_scene_lithtech](https://github.com/haekb/io_scene_lithtech) | ABC / model structure reference | GPL-2.0, no "or later" election found | **No** — GPL-2.0-only is incompatible with GPL-3.0. Behaviour and documentation reference only |
| [DAT-Reader](https://github.com/burmaraider/DAT-Reader) | World viewing / export research | **None declared** | **No** — all rights reserved; behaviour reference only |
| [Released AvP2 source](https://github.com/realforce212/AVP) | Architecture / behaviour reference | **None declared**, restrictive | **No** — do not copy. See the clean-room policy above |

### Notes

**Facts are not expression.** Studying any of the above to learn a file format,
a field layout, or an observed behaviour is not copying. Reproducing code
structure, comments, identifiers, or the shape of an implementation is. Where a
project is marked reference-only, record format findings in `docs/formats/` in
your own words and implement from those notes.

**The DAT path is the constrained one.** Both DAT references are unlicensed,
which makes world parsing (roadmap stage 3) the subsystem most likely to need
either an author's permission or genuinely independent work. Requesting an
explicit licence from the `godot-dat-reader` author is worth doing early.

**ABC is not constrained.** `godot-abc-reader` is MIT and covers the same format
as the GPL-2.0 `io_scene_lithtech`, so ABC support has a usable source.

## Reuse log

Record every reused library, format reader, or tool here: project, commit or
version, licence, where it is used, and who verified it.

_(empty)_
