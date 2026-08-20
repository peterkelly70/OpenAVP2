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
| [godot-dat-reader](https://github.com/haekb/godot-dat-reader) | DAT / Talon v70 world parsing | **None declared** | **Not for copying** — study freely, implement independently |
| [io_scene_lithtech](https://github.com/haekb/io_scene_lithtech) | ABC / model structure reference | GPL-2.0, no "or later" election found | **Not for copying** — GPL-2.0-only is incompatible with GPL-3.0; study freely |
| [DAT-Reader](https://github.com/burmaraider/DAT-Reader) | World viewing / export research | **None declared** | **Not for copying** — study freely, implement independently |
| [Released AvP2 source](https://github.com/realforce212/AVP) | Architecture / behaviour reference | **None declared**, restrictive | **No** — do not copy. See the clean-room policy above |

### What "reference only" does and does not mean

It does **not** mean the code is off limits to read. All of these projects are
published publicly and may be studied by anyone without permission.

**Formats are facts, not expression.** A file layout, a field meaning, a
compression scheme, a bit flag, an algorithm — none of these are protected by
copyright, and reimplementing them is the entire premise of a compatibility
runtime. Reverse engineering for interoperability is well-established:
*Sega v. Accolade*, *Sony v. Connectix*, *Google v. Oracle*.

What a licence controls is **expression**: the specific source text. Copying
functions, identifier names, comment text, file structure, or the order and
shape of an implementation requires a compatible licence. Learning from a
reference and writing your own implementation does not.

So "reference only" means: read it, understand it, write down what you learned,
implement it yourself. It does not mean avoid it.

### Working method for reference implementations

The practical risk is not reading; it is reading closely and then writing your
version immediately afterwards, when structure and naming carry over without
your noticing.

1. Study the reference and any file dumps until the format is understood.
2. Write the findings into `docs/formats/` **in your own words**: field tables,
   offsets, types, version differences, observed quirks. Facts, not code.
3. Implement from those notes, in OpenAvP2's own architecture and naming.
4. Verify against real data from an installation, not against the reference's
   source text.

Step 2 is what makes step 3 defensible, and it produces documentation the
project needs regardless. Where a reference is permissively licensed (gorez,
godot-dtx-reader, godot-abc-reader) direct porting is also allowed, with
attribution recorded in the reuse log below.

### The AvP2 source is the one genuine exception

The released game source is treated more strictly than the community projects,
because its provenance is unclear and its rights holders are commercial. For any
subsystem where it is consulted, follow the clean-room process in the policy
above and record the boundary here.

## Reuse log

Record every reused library, format reader, or tool here: project, commit or
version, licence, where it is used, and who verified it.

| Project | Version | Licence | Use | Distributed? |
|---|---|---|---|---|
| [GUT](https://github.com/bitwes/Gut) | v9.6.1 | MIT (`addons/gut/LICENSE.md`) | GDScript test framework | No — development only, fetched by `scripts/setup-dev.sh`, not committed |
| [Chakra Petch](https://fonts.google.com/specimen/Chakra+Petch) | Bold | SIL Open Font Licence 1.1 | Interface display face | Yes — `assets/fonts/` |
| [Rajdhani](https://fonts.google.com/specimen/Rajdhani) | Medium, Bold | SIL Open Font Licence 1.1 | Interface body face | Yes — `assets/fonts/` |
| [Share Tech Mono](https://fonts.google.com/specimen/Share+Tech+Mono) | Regular | SIL Open Font Licence 1.1 | Readouts and counters | Yes — `assets/fonts/` |

Fonts are shipped rather than looked up on the host, so the interface renders
identically everywhere. The Open Font Licence permits this; each family's
licence text is kept beside it in `assets/fonts/`.

GUT is a development dependency and is not part of any OpenAvP2 release, so it
imposes no obligation on distributed builds. It is recorded here anyway because
the policy is to record everything.

No third-party code has been incorporated into `src/`.

### Artwork

`assets/ui/` holds OpenAvP2's own interface artwork, produced for this project
by an image generation model rather than derived from any existing game asset.
It is the project's own work and is distributed under the same licence as the
code.

The game's own artwork is **never** redistributed. The menus can be told to use
it instead, in which case it is read from the user's installation at runtime,
exactly as world and audio content is.

### Studied, not copied

| Project | Licence | What was learned | Where recorded |
|---|---|---|---|
| [godot-dat-reader](https://github.com/haekb/godot-dat-reader) | None declared | DAT world model and surface layout, from the 010 Editor binary templates in its `Research` directory, which are a format specification rather than an implementation | [`docs/formats/dat.md`](docs/formats/dat.md) |
| [godot-abc-reader](https://github.com/haekb/godot-abc-reader) | **MIT** | ABC section chain, header, piece, level of detail, node and socket layouts | [`docs/formats/abc.md`](docs/formats/abc.md) |

`godot-abc-reader` is MIT and so may be reused directly with attribution, unlike
the unlicensed projects above. The implementation here is written in OpenAvP2's
own architecture rather than copied, but the attribution stands either way:
Copyright © 2020 HeyThereCoffeee, MIT.

The layout was written into our own notes and implemented in OpenAvP2's own
architecture. No source was copied, which the absence of a licence requires.
