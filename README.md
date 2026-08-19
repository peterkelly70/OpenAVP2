# OpenAvP2

Cross-platform replacement runtime for **Aliens vs. Predator 2** (2001).

OpenAvP2 loads your own original AvP2 installation, translates LithTech Talon
assets and world data into modern runtime objects, and recreates the game on top
of **Godot 4.6** — natively on Windows, Linux and macOS, without Wine and without
the original `lithtech.exe`.

> **Status: pre-alpha scaffold.** Nothing is playable yet. This repository
> currently contains the project structure, the technical design document, and
> the provenance policy. See the roadmap below.

## You must own the game

OpenAvP2 ships **no** AvP2 content. No archives, levels, textures, models or
sounds. You need a legally obtained, patched retail installation; OpenAvP2 asks
you to locate it on first run and reads it read-only through a virtual
filesystem. Original game files are never modified.

## Design

The full Technical Design Document is in [`docs/TECHNICAL_DESIGN.md`](docs/TECHNICAL_DESIGN.md)
(generated from [`OpenAvP2_Technical_Design_Document.docx`](OpenAvP2_Technical_Design_Document.docx) with `pandoc -f docx -t gfm`).

Godot is the **host engine**, not the compatibility contract. It provides
rendering, audio, input, windowing, networking and headless execution. OpenAvP2
provides the LithTech-compatible data layer, world and entity semantics,
gameplay, and the dedicated server. Any subsystem whose behaviour must match
Talon is routed through an OpenAvP2 abstraction so that behaviour stays
measurable.

| | |
|---|---|
| Host engine | Godot 4.6 (standard build) |
| Language | GDScript, C++ GDExtension only where measured need appears |
| Platforms | Windows x86-64, Linux x86-64, macOS ARM64 / x86-64 |
| Dedicated server | Headless Windows and Linux |
| First target | AvP2 (2001), patched retail data |
| Later target | AvP2: Primal Hunt |

## Repository layout

```
src/platform/       Filesystem port and platform services
src/vfs/            Path canonicalisation, mount precedence
src/installation/   Installation discovery and validation
src/inventory/      Format inventory scan (stage 0)
src/composition/    Composition root: builds every object graph
tools/              Headless command line tools
tests/              GUT test suite
docs/               Design, format notes, entity notes, compatibility notes
scripts/            Development setup and test runner
```

Services take their dependencies through `_init` and are built in
`src/composition/services.gd`. Nothing constructs its own collaborators, which
is what lets every test run against an in-memory filesystem with no game data.

## Roadmap

21 stages (TDD section 22). The gating milestone is **stage 13**: play the first
Marine campaign mission end to end. Alien, Predator, multiplayer and any
remaster work stay behind that gate.

| Stage | Milestone |
|---|---|
| 0 | Installation inventory |
| 1 | REZ archives + virtual filesystem |
| 2 | DTX textures |
| 3 | DAT v70 world geometry |
| 4 | Materials and lightmaps |
| 5 | Collision and blockers |
| 6–7 | ABC models and animation |
| 8–9 | Entities and world interaction |
| 10–12 | Marine player, weapons, AI |
| **13** | **First complete Marine level** |
| 14–16 | Alien, Predator, campaign completion |
| 17–18 | Multiplayer and dedicated server |
| 19–20 | Primal Hunt, enhanced renderer and modding |

## Development

Requires Godot 4.6 (the standard build; the .NET build is not needed). Nothing
is playable yet.

```
./scripts/setup-dev.sh     # fetches the GUT test framework into addons/
./scripts/run-tests.sh     # imports the project and runs the suite headlessly
```

Scan a real installation:

```
godot --headless --script tools/installinventory.gd -- /path/to/avp2 --out inventory.json
```

## Contributing

Read [`THIRD_PARTY.md`](THIRD_PARTY.md) first.

Existing LithTech projects may be studied freely — formats are facts, and
reimplementing them is the point of a compatibility runtime. What a licence
governs is source text, so findings go into [`docs/formats/`](docs/formats/) in
your own words and the implementation is written from those notes. Direct
porting is fine from the permissively licensed references, with attribution
recorded in the reuse log.

Two rules are absolute: never copy from the released AvP2 game source, and never
commit game assets.

## Licence

**GNU General Public License, version 3 or later** ([LICENSE](LICENSE)).

    OpenAvP2 -- cross-platform Aliens vs. Predator 2 replacement runtime
    Copyright (C) 2026 Peter Kelly

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation, either version 3 of the License, or (at your option)
    any later version.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
    Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <https://www.gnu.org/licenses/>.

Copyleft is deliberate. The valuable output of this project is reverse-engineered
format knowledge contributed by volunteers; the GPL keeps improvements flowing
back and is the established norm for engine reimplementations such as OpenMW,
OpenRA, ScummVM and OpenRCT2. Version 3 or later is chosen so that MIT, BSD and
Apache-2.0 code can be incorporated; see [THIRD_PARTY.md](THIRD_PARTY.md).

This licence covers OpenAvP2 source code only. **No rights to Aliens vs. Predator 2
game data are granted or implied.** Aliens vs. Predator 2 is the property of its
respective rights holders; this project is unaffiliated with them and distributes
none of their content.
