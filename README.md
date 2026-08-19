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
| Host engine | Godot 4.6 |
| Language | C# (`net8.0`), C++ GDExtension only where measured need appears |
| Platforms | Windows x86-64, Linux x86-64, macOS ARM64 / x86-64 |
| Dedicated server | Headless Windows and Linux |
| First target | AvP2 (2001), patched retail data |
| Later target | AvP2: Primal Hunt |

## Repository layout

```
src/OpenAvP2/       Core runtime, platform, VFS
src/LithTech/       Format layer: Rez, Dat, Dtx, Abc, World, Entities
src/Game/           Gameplay: AI, characters, weapons, objectives, multiplayer
src/Server/         Headless dedicated server
tools/              reztool, datdump, dtxdump, abcdump
tests/              Parser, golden-asset and compatibility tests
docs/               Design, format notes, entity notes, compatibility notes
```

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

## Building

Requires the .NET 8 SDK and Godot 4.6 (.NET build). The solution is scaffolding
and does not yet produce a running game.

```
dotnet restore OpenAvP2.sln
dotnet build   OpenAvP2.sln
dotnet test    OpenAvP2.sln
```

## Contributing

Read [`THIRD_PARTY.md`](THIRD_PARTY.md) first. Provenance rules are not optional:
the released AvP2 source is a behavioural reference only and must not be copied
into this project, and no game asset may ever be committed.

## Licence

[MIT](LICENSE) for OpenAvP2 source code. No rights to AvP2 game data are granted
or implied. Aliens vs. Predator 2 is the property of its respective rights
holders; this project is unaffiliated with them.
