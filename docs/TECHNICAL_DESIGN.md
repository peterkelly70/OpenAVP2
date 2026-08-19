**OpenAvP2**

**Cross-Platform Aliens vs. Predator 2 Engine Reimplementation**

Technical Design Document

**Version 0.1**

19 August 2026

*Working design for a portable replacement runtime that loads the original AvP2 game data and recreates gameplay on modern operating systems.*

**Target platforms: Windows x86-64, Linux x86-64, macOS ARM64/x86-64**

# Document Status

| **Item**                        | **Value**                                                                                 |
|---------------------------------|-------------------------------------------------------------------------------------------|
| Project                         | OpenAvP2                                                                                  |
| Document                        | Technical Design Document                                                                 |
| Version                         | 0.1                                                                                       |
| Primary engine                  | Godot 4.6                                                                                 |
| Primary implementation language | C#                                                                                        |
| Target platforms                | Windows x86-64, Linux x86-64, macOS ARM64/x86-64                                          |
| Dedicated server                | Headless Windows and Linux, with macOS kept buildable where practical                     |
| Asset model                     | Original AvP2 installation required; no copyrighted game assets distributed with OpenAvP2 |
| Initial compatibility target    | Aliens vs. Predator 2 (2001), patched retail data                                         |
| Later compatibility target      | Aliens vs. Predator 2: Primal Hunt                                                        |

# 1. Executive Summary

**OpenAvP2 is a cross-platform replacement runtime for Aliens vs. Predator 2 (AvP2).** The project will load the user's original AvP2 installation data, translate LithTech Talon assets and world structures into modern runtime objects, and recreate the game's behavior on top of Godot 4.6. The project will not distribute AvP2 assets or depend on the original lithtech.exe executable.

The proposed implementation uses Godot as a portability and systems layer rather than attempting to restore the proprietary Talon engine. Godot supplies modern rendering, input, audio, windowing, networking primitives, platform abstraction, packaging, and headless execution. OpenAvP2 supplies the LithTech-compatible data layer, world/entity semantics, gameplay systems, compatibility behavior, and dedicated server.

| **Primary success criterion:** OpenAvP2 can locate an original AvP2 installation, load the first Marine campaign level, and play that level from beginning to end with sufficiently accurate geometry, materials, collision, entities, AI, weapons, objectives, audio, save/load behavior, and scripted events. |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

# 2. Goals and Non-Goals

## 2.1 Goals

- Run AvP2 natively on modern Windows, Linux, and macOS without Wine or the original Talon executable.

- Load original AvP2 content directly from the user's installation, including REZ archives, DAT worlds, DTX textures, ABC models, animations, sounds, and configuration data.

- Reproduce original gameplay closely enough that the retail campaigns remain completable and recognizable in behavior.

- Provide a portable dedicated server with no renderer, no audio stack, and no GUI dependency.

- Use a new OpenAvP2 multiplayer protocol initially, allowing OpenAvP2 clients on all supported platforms to play together.

- Preserve modding as a first-class concern through a virtual filesystem and deterministic content override order.

- Keep the architecture extensible enough to support Primal Hunt after AvP2 compatibility is mature.

- Separate compatibility behavior from engine implementation so improved rendering and quality-of-life features can be optional rather than destructive to original behavior.

## 2.2 Non-Goals for Initial Releases

- Redistributing Monolith, Sierra, Fox, or other copyrighted AvP2 game assets.

- Recreating the LithTech Talon source code or binary implementation internally.

- Supporting the original AvP2 network protocol or allowing original retail clients to join OpenAvP2 servers in the first release.

- Providing a full modern remaster before baseline compatibility is achieved.

- Supporting Primal Hunt before the base AvP2 campaign and multiplayer systems are stable.

- Replacing every Godot subsystem with custom low-level platform code unless compatibility or performance requires it.

# 3. Design Principles

| **Principle**                        | **Implication**                                                                                                                           |
|--------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| Compatibility first                  | Prefer correct AvP2 behavior over visually impressive changes during the compatibility phase.                                             |
| Cross-platform by construction       | No subsystem may assume Win32 paths, DirectX-only rendering, Windows registry access, case-insensitive filesystems, or x86-only behavior. |
| Original assets stay external        | OpenAvP2 should be distributable without AvP2 data and should ask the user to locate a valid installation on first run.                   |
| Data-driven recreation               | Parse and preserve as much original world and object data as possible instead of hard-coding campaign-specific behavior.                  |
| Compatibility boundaries             | Wrap Godot rendering, physics, audio, and networking behind OpenAvP2 abstractions where Talon behavior matters.                           |
| Unknown data must degrade gracefully | Unsupported objects should be logged and preserved where possible rather than causing the map loader to fail.                             |
| Server authority                     | Multiplayer and co-op capable systems should be designed around an authoritative simulation even before multiplayer is complete.          |
| Test formats independently           | REZ, DAT, DTX, ABC, animation, material, and entity parsing should have standalone tools and regression tests.                            |

# 4. High-Level Architecture

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>OpenAvP2 Game Layer<br />
|<br />
+-----------------+------------------+<br />
| |<br />
Gameplay / Entities LithTech Compatibility<br />
| |<br />
AI - Weapons - Objectives REZ - DAT - DTX - ABC - Audio<br />
| |<br />
+-----------------+------------------+<br />
|<br />
OpenAvP2 Runtime API<br />
|<br />
+-------------------+-------------------+<br />
| | |<br />
Rendering Physics Audio<br />
| | |<br />
+---------------- Godot 4.6 ------------+<br />
|<br />
Windows / Linux / macOS</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

**Godot is treated as the modern host engine.** OpenAvP2 does not attempt to expose Godot directly to all gameplay code. Systems whose behavior must mimic Talon are routed through OpenAvP2 compatibility interfaces. This keeps replacement behavior measurable and prevents Godot-specific assumptions from spreading through the project.

# 5. Technology Stack

| **Area**               | **Choice**                                                           | **Rationale**                                                                                            |
|------------------------|----------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------|
| Host engine            | Godot 4.6                                                            | Portable desktop engine, modern renderer, headless mode, audio, input, packaging, and active tooling.    |
| Primary language       | C#                                                                   | Typed binary parsing, maintainable large gameplay codebase, tooling reuse, and strong testing ecosystem. |
| Performance extensions | C++ GDExtension when required                                        | Reserved for format decoding, geometry building, or hot simulation paths that show measured need.        |
| Rendering              | Godot Forward+/Compatibility as appropriate                          | Baseline portability first; compatibility materials recreate Talon assumptions.                          |
| Networking             | OpenAvP2 protocol over Godot/ENet-compatible transport or equivalent | Cross-platform native protocol with dedicated server support.                                            |
| Tests                  | .NET unit tests plus Godot integration tests                         | Binary format fixtures can be tested without booting the full game.                                      |
| Build/CI               | GitHub Actions or equivalent                                         | Automated Windows, Linux, and macOS build validation.                                                    |

# 6. Installation Discovery and Asset Ownership

OpenAvP2 should never assume a fixed install path. On first launch it should detect common locations where possible, then allow the user to browse to the AvP2 installation directory.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>OpenAvP2 - First Run<br />
<br />
Locate Aliens vs. Predator 2 installation:<br />
[ /games/avp2/ ]<br />
<br />
Validation:<br />
[OK] base game archives<br />
[OK] patched game data<br />
[OK] maps<br />
[OK] textures<br />
[OK] models<br />
<br />
[ Start ]</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

- Validation should identify the game version and known patch state.

- The selected installation path is stored in OpenAvP2 configuration, not written into original game files.

- OpenAvP2 cache files, converted resources, shaders, logs, and saves are stored under OpenAvP2-owned platform directories.

- The runtime must tolerate case differences and normalize internal LithTech paths to avoid Linux/macOS filesystem failures.

# 7. Virtual Filesystem and REZ Archives

All game content access should pass through a virtual filesystem (VFS). The VFS hides whether a resource came from a REZ archive, an official patch, a mod package, or a loose override file.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>VFS mount precedence, lowest to highest priority:<br />
<br />
1. Base AvP2 archives<br />
2. Official patch archives<br />
3. Expansion archives, when enabled<br />
4. OpenAvP2 compatibility content<br />
5. Installed mods<br />
6. User loose-file overrides</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

Core API concept:

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>Vfs.Open("Worlds/SinglePlayer/Marine/m1s1.dat");<br />
Vfs.Open("Textures/Characters/Marine.dtx");<br />
Vfs.Open("Models/Characters/Alien.abc");</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

- REZ parsing lives in a standalone LithTech.Rez library with no dependency on the game scene tree.

- Archive indexes should be cached after validation.

- Resource paths should be canonicalized once at VFS boundaries.

- The VFS should expose metadata such as source archive, mod source, file size, and content hash for diagnostics.

# 8. LithTech Asset Compatibility Layer

## 8.1 DTX Textures

DTX decoding should produce a neutral LithTexture representation before creation of Godot ImageTexture resources. The loader must support the DTX variants and compression modes actually used by AvP2, including palettized and DXT-compressed content where present.

- Preserve alpha-test versus alpha-blend semantics.

- Preserve texture flags and material-relevant metadata.

- Cache decoded textures using a content hash and loader version.

- Allow texture overrides through the VFS without rebuilding the original archives.

## 8.2 DAT v70 Worlds

The DAT loader is the central compatibility subsystem. It should parse Talon v70 world data into neutral structures before creating Godot nodes or meshes. Geometry loading alone is not sufficient; world models, blockers, volumes, portals, lightmap relationships, and entity/object records must be retained.

| **DAT domain**         | **Required output**                                                                                |
|------------------------|----------------------------------------------------------------------------------------------------|
| World geometry         | Vertices, indices, surfaces, texture coordinates, surface flags                                    |
| BSP/world organization | Nodes, leaves, visibility/portal data where required                                               |
| Lightmaps              | Lightmap images, UV relationships, material bindings                                               |
| World models           | Movable or separately addressed geometry used by doors, lifts, destructibles, and scripted objects |
| Collision/blockers     | Collision surfaces and non-rendered blockers                                                       |
| Volumes                | Water, damage, fog, gravity, ladder, trigger, and other region semantics where encoded             |
| Objects/entities       | Class name, transform, property collection, links/references                                       |

## 8.3 ABC Models and Animation

ABC decoding should produce a neutral model structure containing meshes, skeleton, bones, sockets, LODs, skins/material references, and animation tracks. Runtime conversion then creates Godot MeshInstance3D, Skeleton3D, AnimationLibrary, and BoneAttachment3D structures.

- Sockets must be preserved because AvP2 weapons, attachments, effects, and character equipment depend on them.

- Animation event markers must be identified if they drive sound, damage, footstep, or effect timing.

- Model version differences should be isolated behind version-specific readers.

- Animation output should be deterministic so regression tests can compare track counts, durations, node transforms, and event markers.

# 9. Entity and World Object System

The first point at which OpenAvP2 becomes a game rather than a content viewer is the entity system. DAT object records should be converted into typed OpenAvP2 entities through a registry/factory layer.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>LithEntityFactory.Create("Door", properties)<br />
LithEntityFactory.Create("AI", properties)<br />
LithEntityFactory.Create("Trigger", properties)<br />
LithEntityFactory.Create("WorldModel", properties)</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

| **Initial entity family** | **Examples**                                                          |
|---------------------------|-----------------------------------------------------------------------|
| World interaction         | Doors, lifts, moving world models, breakables, switches               |
| Scripting                 | Triggers, relays, counters, timers, objectives, mission state         |
| Characters                | Player starts, NPCs, enemies, scripted characters                     |
| Navigation                | AI nodes, patrol nodes, path hints, jump/climb hints where applicable |
| Items                     | Weapons, ammunition, armor, health, pickups                           |
| Environment               | Lights, fog, sound emitters, particle emitters, volumes               |
| Presentation              | Cameras, dialogue triggers, scripted effects, cinematics              |

| **Failure behavior:** Unknown entity classes must be logged with class name, position, and properties. The map should continue loading unless the unknown object is structurally required for world integrity. |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

# 10. Gameplay Layer

Gameplay is implemented independently of the proprietary Talon executable. The gameplay layer consumes the neutral world/entity representation and exposes reusable simulation components.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>src/Game/<br />
AI/<br />
Characters/<br />
Marine/<br />
Alien/<br />
Predator/<br />
Weapons/<br />
Projectiles/<br />
Damage/<br />
Inventory/<br />
Objectives/<br />
Interaction/<br />
SaveGame/<br />
Multiplayer/</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

## 10.1 Marine

- Conventional FPS movement, crouch, jump, ladders, interaction, and use actions.

- Health and armor behavior.

- Weapon switching, ammunition types, reload behavior, recoil/spread, projectiles and hitscan behavior.

- Flashlight and motion tracker.

- Objective progression and scripted mission events.

## 10.2 Alien

- Surface-relative gravity and orientation for floor, wall, and ceiling traversal.

- Claw, tail, pounce, and head-bite behavior.

- Alien vision and species-specific HUD presentation.

- Character controller must not assume world-down is always the gravity direction.

## 10.3 Predator

- Cloaking and energy management.

- Vision modes and species-specific target presentation.

- Wrist blades, spear, plasma caster, disc and other weapon behaviors.

- Healing/utility equipment and associated energy/resource rules.

# 11. Rendering Compatibility

The baseline renderer should reproduce Talon-era material intent rather than immediately reinterpret all content as physically based rendering. OpenAvP2 should provide a LithMaterial abstraction capable of creating appropriate Godot materials and shaders.

| **Compatibility feature** | **Required behavior**                                                                                      |
|---------------------------|------------------------------------------------------------------------------------------------------------|
| Lightmapped surfaces      | Combine base material and lightmap without changing authored brightness relationships more than necessary. |
| Vertex lighting           | Preserve per-vertex lighting where used.                                                                   |
| Alpha test                | Correct cutout threshold behavior for foliage, grates, decals, and similar assets.                         |
| Alpha blending            | Transparent and semi-transparent materials with expected sort behavior.                                    |
| Additive blending         | Weapon effects, particles, glow-like effects.                                                              |
| Environment/detail layers | Support legacy secondary texture stages where used.                                                        |
| Fog                       | World and volume fog compatible with map data.                                                             |
| Animated textures         | Frame/sequence driven materials where used.                                                                |
| Sky/sprites/particles     | Compatibility implementations for Talon presentation primitives.                                           |

Later render profiles may include Original, Enhanced, and Remastered modes. The compatibility profile remains the behavioral reference.

# 12. Physics, Collision, and Movement

Godot physics should be used as an implementation foundation, but not exposed directly as the compatibility contract. OpenAvP2 should isolate player movement, ray tests, mover behavior, projectiles, and world collision through its own APIs.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>LithWorldCollision<br />
LithCharacterController<br />
LithRaycast<br />
LithMover<br />
LithProjectileQuery</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

- Marine movement should be tuned against reference behavior rather than generic Godot defaults.

- Alien traversal requires arbitrary gravity direction and smooth local orientation changes.

- Doors, lifts, moving world models, ladders, crouch clearance, and projectile collision require targeted regression scenes.

- Multiplayer prediction should use the same character movement core as single-player to avoid divergent behavior.

# 13. Audio System

Audio files and metadata should be inventoried from a real AvP2 installation before finalizing decoder requirements. Runtime audio is mapped to Godot AudioStreamPlayer and AudioStreamPlayer3D through a compatibility manager.

- 3D position and attenuation radius.

- Looping behavior and priorities.

- Pitch and volume controls.

- Environment/occlusion behavior where practical.

- Logical resource names so mods can replace audio through the VFS.

# 14. AI and Navigation

AI should be recreated around the authored navigation and trigger data in the original maps. The design should avoid replacing AvP2 encounters with generic modern pathfinding if doing so changes scripted behavior.

| **Subsystem** | **Design**                                                                                               |
|---------------|----------------------------------------------------------------------------------------------------------|
| Perception    | Sight, hearing, target memory, faction/species filtering                                                 |
| Navigation    | Authored AI nodes plus runtime path search; navmesh may be generated as an implementation aid            |
| Combat        | Weapon selection, firing windows, melee, cover/position decisions where relevant                         |
| Scripting     | Mission triggers and designer-authored AI state changes take precedence over autonomous behavior         |
| Debugging     | Optional overlays for nodes, current target, current state, path, sensory events, and trigger activation |

# 15. Multiplayer and Dedicated Server

Initial multiplayer should use an OpenAvP2-native protocol rather than emulate the original retail protocol. The authoritative server owns world state, damage, inventory, objective state, and entity simulation.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>openavp2 # graphical client<br />
openavp2-server # headless dedicated server<br />
<br />
openavp2-server --map dm_alley --port 27888 --players 16</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

| **Concern**     | **Approach**                                                                        |
|-----------------|-------------------------------------------------------------------------------------|
| Authority       | Server authoritative simulation                                                     |
| Transport       | Portable reliable/unreliable channels using ENet-compatible or equivalent transport |
| Prediction      | Client prediction for local movement, reconciliation from server snapshots          |
| Replication     | Interest-based entity snapshots and event messages                                  |
| Cross-platform  | Wire protocol uses explicit sizes/endianness and versioned schemas                  |
| Server runtime  | No renderer, audio or GUI dependencies                                              |
| Legacy protocol | Deferred until OpenAvP2 networking is stable and only if worthwhile                 |

# 16. Save Games, Configuration, and User Data

- Use OpenAvP2-owned save formats rather than writing into original game directories.

- Save game schema should be versioned and migration-aware.

- Store the original installation path, render profile, audio/input settings, enabled mods, and compatibility flags in portable configuration.

- Keep deterministic campaign state identifiers so save compatibility can survive internal refactors where feasible.

- Provide exportable diagnostics containing engine version, data version, mod list, platform, renderer, and relevant log excerpts.

# 17. Modding Model

Mod support follows naturally from the VFS. Mods should be declarative packages with explicit dependencies and load order rather than requiring users to edit original REZ files.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>mods/<br />
coop/<br />
mod.json<br />
scripts/<br />
maps/<br />
textures/<br />
<br />
hd-textures/<br />
mod.json<br />
textures/</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>{<br />
"name": "AVP2 HD",<br />
"version": "1.0",<br />
"game": "avp2",<br />
"load_after": ["base"]<br />
}</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

- Mods may override resources by logical path.

- Script extensibility should be added only after stable gameplay APIs exist.

- Server should advertise required mods/content hashes to connecting clients.

- Compatibility flags should permit mods that intentionally rely on original quirks.

# 18. Primal Hunt Extension Strategy

Primal Hunt should be accounted for in interfaces from the start but not implemented until the base game is stable. Game-specific rules should live behind a module boundary.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>IGameModule<br />
+-- AvP2Game<br />
+-- PrimalHuntGame</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

Runtime selection can remain explicit:

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>openavp2 --game avp2<br />
openavp2 --game primalhunt</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

# 19. Tools and Developer Workflow

Format reverse engineering and compatibility development will be substantially faster if each major binary format has an independent inspection tool.

| **Tool**    | **Purpose**                                                                                                  |
|-------------|--------------------------------------------------------------------------------------------------------------|
| reztool     | List, inspect, extract, hash, and validate REZ archive content                                               |
| datdump     | Dump DAT headers, geometry, BSP/world model structures, entities, properties, and references                 |
| dtxdump     | Inspect texture metadata and export decoded images for comparison                                            |
| abcdump     | Inspect model versions, bones, sockets, skins, LODs, animation tracks, and events                            |
| worldviewer | Load a DAT map with free camera, material modes, collision overlays, entity labels, and lightmap debug views |
| entitytrace | Record trigger/entity state transitions while playing a level                                                |

# 20. Repository Structure

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>OpenAvP2/<br />
├── README.md<br />
├── LICENSE<br />
├── OpenAvP2.sln<br />
├── src/<br />
│ ├── OpenAvP2/<br />
│ ├── LithTech/<br />
│ │ ├── Rez/<br />
│ │ ├── Dat/<br />
│ │ ├── Dtx/<br />
│ │ ├── Abc/<br />
│ │ ├── World/<br />
│ │ └── Entities/<br />
│ ├── Game/<br />
│ │ ├── AI/<br />
│ │ ├── Characters/<br />
│ │ ├── Weapons/<br />
│ │ ├── Objectives/<br />
│ │ ├── Multiplayer/<br />
│ │ └── AvP2Game.cs<br />
│ └── Server/<br />
├── tools/<br />
│ ├── reztool/<br />
│ ├── datdump/<br />
│ ├── dtxdump/<br />
│ └── abcdump/<br />
├── tests/<br />
│ ├── Rez/<br />
│ ├── Dat/<br />
│ ├── Dtx/<br />
│ ├── Abc/<br />
│ └── Compatibility/<br />
└── docs/<br />
├── formats/<br />
├── entities/<br />
├── gameplay/<br />
└── compatibility/</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

# 21. Testing and Compatibility Validation

The project needs objective compatibility tests from the beginning. A large replacement engine can appear functional while silently misreading asset flags or executing mission logic incorrectly.

| **Test layer**       | **Examples**                                                                                            |
|----------------------|---------------------------------------------------------------------------------------------------------|
| Binary parser tests  | Known headers, file counts, dimensions, bone counts, object counts, property values                     |
| Golden asset tests   | Hash decoded textures, compare mesh statistics, compare animation durations and socket transforms       |
| World tests          | Expected spawn locations, collision checks, door travel, trigger activation, volume entry/exit          |
| Gameplay tests       | Damage values, ammo consumption, weapon cadence, objective state transitions                            |
| Campaign smoke tests | Automated or semi-automated checkpoint traversal through representative missions                        |
| Network tests        | Snapshot serialization, version mismatch rejection, prediction/reconciliation, dedicated-server startup |
| Platform CI          | Build and run parser/integration tests on Windows, Linux, and macOS                                     |

# 22. Development Roadmap

| **Stage** | **Milestone**               | **Scope**                                                                                                                                | **Exit criterion**                          |
|-----------|-----------------------------|------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------|
| 0         | Installation inventory      | Scan a real installation and enumerate every archive, extension, model version, texture type, audio type, and world version encountered. | Format inventory report and sample fixtures |
| 1         | REZ VFS                     | Read archives through one virtual filesystem and resolve override precedence.                                                            | reztool plus VFS unit tests                 |
| 2         | DTX                         | Decode and display AvP2 textures.                                                                                                        | Texture viewer and cache                    |
| 3         | DAT geometry                | Load Talon v70 world geometry into Godot.                                                                                                | Free-camera world viewer                    |
| 4         | Materials/lightmaps         | Reproduce baseline world appearance.                                                                                                     | Compatibility material layer                |
| 5         | Collision                   | Walk through original levels with correct blockers and volumes.                                                                          | Playable free movement                      |
| 6         | ABC models                  | Load static and skinned models, skeletons and sockets.                                                                                   | Model viewer                                |
| 7         | Animations                  | Play original character and object animations.                                                                                           | Animation viewer/regression tests           |
| 8         | Entities                    | Parse object records and instantiate typed entities.                                                                                     | Entity labels and factory                   |
| 9         | World interaction           | Doors, movers, triggers, lights, sounds and basic mission scripting.                                                                     | Interactive level shell                     |
| 10        | Marine player               | Movement, interaction, HUD foundations.                                                                                                  | Controllable Marine                         |
| 11        | Weapons/combat              | Weapons, ammo, projectiles, damage and pickups.                                                                                          | Combat sandbox                              |
| 12        | AI                          | Navigation, perception and combat behavior.                                                                                              | Representative enemy encounters             |
| 13        | First complete Marine level | Finish all systems required to play one retail mission end to end.                                                                       | Critical project milestone                  |
| 14        | Alien                       | Surface-relative movement and Alien combat/vision.                                                                                       | Playable Alien mission                      |
| 15        | Predator                    | Energy, cloak, vision modes and Predator weapons.                                                                                        | Playable Predator mission                   |
| 16        | Campaign completion         | Resolve remaining scripting and compatibility gaps.                                                                                      | Base campaigns completable                  |
| 17        | Multiplayer                 | OpenAvP2 client/server protocol and game modes.                                                                                          | Cross-platform multiplayer                  |
| 18        | Dedicated server            | Harden headless hosting and administration.                                                                                              | Portable server release                     |
| 19        | Primal Hunt                 | Add expansion-specific formats, entities and gameplay.                                                                                   | Expansion compatibility                     |
| 20        | Enhanced renderer/modding   | Optional modern visuals, QoL and expanded mod APIs.                                                                                      | Post-compatibility feature phase            |

# 23. Risks and Mitigations

| **Risk**                                       | **Severity** | **Mitigation**                                                                                                                                 |
|------------------------------------------------|--------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| Entity semantics are incompletely understood   | High         | Build datdump/entitytrace early; log unknown classes/properties; implement by frequency and mission criticality.                               |
| Animation/event details differ by ABC version  | High         | Use version-specific readers and golden model fixtures; separate decode from runtime conversion.                                               |
| Godot physics differs from Talon               | High         | Own the movement/collision compatibility layer and tune against reference scenarios.                                                           |
| Map scripts contain undocumented coupling      | High         | Prioritize complete-level vertical slices rather than implementing isolated systems indefinitely.                                              |
| Restrictive released source licensing          | High         | Do not copy restricted code into the open implementation. Maintain clear provenance and, if needed, a formal clean-room specification process. |
| Cross-platform case/path bugs                  | Medium       | Canonicalize VFS paths and continuously test on case-sensitive filesystems.                                                                    |
| Mod load-order incompatibility                 | Medium       | Deterministic VFS precedence, dependency metadata, content hashes and diagnostics.                                                             |
| Renderer differences alter original atmosphere | Medium       | Keep a compatibility render profile and add enhancements as optional modes.                                                                    |
| Scope expansion before first playable mission  | High         | Treat the first complete Marine level as the gating milestone for broader species, multiplayer and remaster work.                              |

# 24. Licensing and Provenance Strategy

OpenAvP2 should keep a written provenance policy from the first commit. The existence of released AvP2 game source is useful for understanding the original architecture, but its restrictive license means the open project must not treat it as freely reusable source code.

- Maintain a THIRD_PARTY.md file containing every reused library, format reader, tool, and license.

- Prefer MIT/BSD/Apache or otherwise compatible reference implementations for directly reusable code.

- Treat repositories with missing or unclear licenses as behavioral/format research only until permission is established.

- If restricted source is consulted, document the legal boundary and consider a formal clean-room workflow for affected systems: one party produces behavior/specification notes and another party implements from those notes without copying source expressions.

- Do not commit original AvP2 assets, extracted levels, textures, models, sounds, or other copyrighted game content to the public repository.

# 25. Existing Research and Candidate References

The following projects materially reduce the amount of format work required. Before code is reused, the specific version and license should be verified and recorded in THIRD_PARTY.md.

| **Project**               | **Use to OpenAvP2**                                 | **Current design assumption**                                                          |
|---------------------------|-----------------------------------------------------|----------------------------------------------------------------------------------------|
| gorez                     | LithTech REZ archive parsing reference              | Useful reference for REZ/VFS implementation; licensing to be recorded before reuse.    |
| godot-dtx-reader          | LithTech DTX import/decoding                        | Strong starting point for DTX support; port concepts to Godot 4/C# as appropriate.     |
| godot-dat-reader          | LithTech DAT parsing including Talon v70 world data | Strong starting point for geometry/world parsing; entity support remains a major task. |
| godot-abc-reader          | LithTech ABC model parsing                          | Starting point for model/skeleton/animation support.                                   |
| io_scene_lithtech         | Blender importer for LithTech model formats         | Additional behavior/reference for ABC and related model structures.                    |
| DAT-Reader                | Independent AvP2 world viewing/export research      | Useful for comparison; code reuse only if licensing permits.                           |
| Released AvP2 game source | Architecture and gameplay behavior reference        | Not assumed to be open-source reusable code; provenance restrictions apply.            |

Reference URLs:

- https://github.com/K4rian/gorez

- https://github.com/haekb/godot-dtx-reader

- https://github.com/haekb/godot-dat-reader

- https://github.com/haekb/godot-abc-reader

- https://github.com/haekb/io_scene_lithtech

- https://github.com/burmaraider/DAT-Reader

- https://github.com/realforce212/AVP

# 26. Definition of the First Major Release

**OpenAvP2 0.1 should not be defined as "the parsers compile."** It should be defined by a vertical slice that proves the architecture: installation discovery, VFS, original data loading, rendering, collision, entities, gameplay, AI, audio, objectives, and saving all operate together in an original retail mission.

| **Release gate:** Boot OpenAvP2, select an original AvP2 installation, start the first Marine campaign mission, and play it from beginning to end without the original lithtech.exe executable. |
|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|

# 27. Immediate Implementation Backlog

1.  Create the repository and baseline Godot 4.6 C# project with Windows/Linux/macOS CI builds.

2.  Write an installation inventory tool and collect a machine-readable manifest of one patched AvP2 installation.

3.  Implement or port the REZ archive reader and virtual filesystem.

4.  Port the DTX reader to the chosen Godot 4/C# architecture and build a texture inspection tool.

5.  Port/implement Talon DAT v70 geometry loading and create a world viewer.

6.  Add material/lightmap conversion and debug visualization modes.

7.  Add world collision/blocker import and a free-flying/walking diagnostic controller.

8.  Port/implement ABC model parsing, sockets and skeleton output.

9.  Decode DAT object/entity records and build datdump output for every object in the first Marine mission.

10. Define the first entity registry and implement world models, doors, triggers, sounds and player start objects.

# Appendix A - Proposed Namespace Layout

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>OpenAvP2.Core<br />
OpenAvP2.Platform<br />
OpenAvP2.Vfs<br />
OpenAvP2.LithTech.Rez<br />
OpenAvP2.LithTech.Dat<br />
OpenAvP2.LithTech.Dtx<br />
OpenAvP2.LithTech.Abc<br />
OpenAvP2.World<br />
OpenAvP2.Entities<br />
OpenAvP2.Rendering<br />
OpenAvP2.Physics<br />
OpenAvP2.Audio<br />
OpenAvP2.Gameplay<br />
OpenAvP2.AI<br />
OpenAvP2.Network<br />
OpenAvP2.Server<br />
OpenAvP2.Tools</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

# Appendix B - Compatibility Logging Conventions

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr class="header">
<th>[VFS] Mounted AVP2.REZ, 12,842 entries<br />
[DAT] Loaded m1s1.dat, Talon v70<br />
[DTX] Texture decoded: Textures/.../wall01.dtx, DXT1, 256x256<br />
[ABC] Model loaded: Models/.../alien.abc, version 13, 42 bones<br />
[ENTITY] Unsupported class AINodePatrol at (456.2, 127.4, -842.9)<br />
[COMPAT] Door speed differs from reference tolerance: expected 128, got 131<br />
[NET] Client protocol 7 rejected by server protocol 8</th>
</tr>
</thead>
<tbody>
</tbody>
</table>

# Appendix C - Architecture Decision Summary

| **Decision**            | **Selected approach**                         | **Reason**                                                                          |
|-------------------------|-----------------------------------------------|-------------------------------------------------------------------------------------|
| Replacement strategy    | Compatibility runtime, not Talon resurrection | Reduces low-level platform work and makes cross-platform support practical.         |
| Host engine             | Godot 4.6                                     | Portable modern systems layer and headless support.                                 |
| Implementation language | C# first                                      | Strong fit for binary parsers, gameplay architecture, tools, and tests.             |
| Asset access            | Original install through VFS                  | Avoids redistribution and preserves compatibility with original data/mod structure. |
| Multiplayer protocol    | New OpenAvP2 protocol first                   | Avoids legacy-protocol work blocking cross-platform multiplayer.                    |
| Expansion support       | Module boundary now, implementation later     | Prevents base-game architecture from becoming impossible to extend.                 |
| Rendering policy        | Compatibility profile first                   | Protects original gameplay/visual intent while leaving room for enhancement modes.  |
