# DAT — LithTech Talon v70 World

The central compatibility subsystem, as TDD section 8.2 says. 160 worlds in a
patched installation, every one version 70.

## Provenance of these notes

Derived independently by inspecting worlds from a legally owned retail
installation. No reference implementation was consulted. Every claim marked
*verified* was tested across all 160 worlds.

## Header

| Offset | Size | Field | Status |
|---|---|---|---|
| `0x00` | 4 | `version` (u32), **70** in all 160 worlds | verified |
| `0x04` | 4 | `objectDataPos`, offset of the object records | verified |
| `0x08` | 4 | `blindObjectDataPos` | verified |
| `0x0C`–`0x28` | 28 | Further offsets, zero in every AvP2 world | unknown |
| `0x2C` | 4 | Length of the world info string | verified |
| `0x30` | n | World info string, ASCII, not NUL terminated | verified |

The field at `0x2C` reads like another offset but is not: it is a length, and
the string it measures follows immediately. Confirmed on all 160 worlds, where
the bytes at `0x30` are always printable ASCII of exactly that length.

### World info string

Present in 109 of 160 worlds. Carries semicolon-separated directives:

    AmbientLight 10 15 20;
    TerrainSubDivSize 20000; PBlockSize 2048; LightTableRes 2048
    LMGridSize 40

`AmbientLight` is the world's ambient term and is needed before any level looks
correct. The rest configure terrain subdivision, the physics block size and
lightmap resolution.

## Object records

At `objectDataPos`. This is where a world stops being geometry and becomes a
level.

    u32 objectCount
    repeat objectCount times:
        u16 recordLength        bytes following this field for this object
        u16 classNameLength
        char className[classNameLength]
        u32 propertyCount
        repeat propertyCount times:
            u16 nameLength
            char name[nameLength]
            u8  type
            u32 flags
            u16 dataLength
            byte data[dataLength]

`recordLength` is worth checking rather than skipping. A misread anywhere inside
an object is caught at its boundary instead of silently corrupting every object
that follows, and the reader treats a mismatch as fatal.

### Property types

Established by correlating the type byte against actual data lengths across all
160 worlds:

| Type | Meaning | Length | Encoding |
|---|---|---|---|
| 0 | String | variable | u16 length, then ASCII |
| 1 | Vector | 12 | three floats |
| 2 | Colour | 12 | three floats, 0 to 255 |
| 3 | Real | 4 | float |
| 5 | Bool | 1 | zero or non-zero |
| 6 | Flags | 4 | u32 |
| 7 | Rotation | 16 | four floats, a quaternion |

Types 4 and 8 do not appear in AvP2. Type 7 occurs exactly 133,781 times across
the game, once per object, so every object carries a rotation.

## Validation

All 160 worlds parsed to completion:

- **160 of 160 worlds, 0 failures**
- **133,781 objects, 5,672,949 properties**
- Every object's consumed byte count matches its declared `recordLength`

That last point is the strong check: the record length is redundant information,
so agreement across 133,781 records means the property encoding is right.

## What the worlds contain

121 distinct object classes. Across all worlds the commonest are `Light`
(34,399), `TranslucentWorldModel` (22,597), `DirLight` (10,984), `AIVolume`
(10,784) and `Trigger` (4,947).

The first Marine mission, `worlds/singleplayer/m1s1.dat`, is the milestone that
gates the project, and it contains 30 classes:

| Count | Class | | Count | Class |
|---|---|---|---|---|
| 181 | TranslucentWorldModel | | 14 | AINode |
| 89 | Key | | 12 | Steam |
| 77 | Prop | | 12 | SkyPointer |
| 69 | AIVolume | | 10 | DebrisSpawner |
| 64 | Light | | 10 | Switch |
| 56 | Trigger | | 10 | ObjectLight |
| 38 | SoundFX | | 7 | Dripper |
| 26 | Explosion | | 6 | Fire |
| 25 | KeyFramer | | 6 | ScreenShake |
| 24 | Door | | 6 | RotatingDoor |
| 19 | CinematicTrigger | | 4 | VolumeBrush |
| 16 | DirLight | | 4 | AIPredator |
| 15 | ScaleSprite | | 4 | AINodePatrol |

This is the implementation order for TDD section 9, measured rather than
guessed. Lights, world models, triggers and doors carry the level; `KeyFramer`
drives scripted motion; `CinematicTrigger` drives the scripted sequences.

## Geometry

Geometry is not addressed by a header offset. Every candidate slot between
`0x0C` and `0x28` is zero in all 160 worlds because those are unused header
slots; the sections run **sequentially** from just after the world info string.

Top-level layout:

    WorldHeader        version, object data offset, render data offset, 8 unused
    WorldInfo          info string, lightmap grid size, world bounds
    WorldTree          padded bounds, node count, then a subdivision bitstream
    WorldModelHeader   count, then that many world models
    WorldObjectHeader  count, then that many objects
    RenderData         lightmaps

### World info and tree

| Field | Notes |
|---|---|
| Lightmap grid size | float; 20, 30, 32, 40, 64 or 128, matching the `LMGridSize` directives in the info strings |
| World bounds | two vectors |
| Tree bounds | the same bounds padded by exactly 128 units on every axis |
| Node count | quadtree size; 85, 341 and 1365 are complete trees of four, five and six levels |

The tree layout follows as a **bitstream**: one bit per node, set meaning the
node divides into four children, read recursively. Only its length matters for
building geometry, but it must be walked to find where the models begin.

### World model

Each model is preceded by an offset to the next one, which is what makes the
sequence safe to walk without decoding every trailing section.

    int   nextModelOffset
    byte  padding[32]
    int   infoFlags, unknown
    short nameLength, char name[]         e.g. "BigPipe", "PhysicsBSP"
    int   pointCount, planeCount, surfaceCount, portalCount
    int   polygonCount, leafCount, vertexReferenceCount
    int   visListSize, leafListCount, nodeCount, unknown, unknown
    vec3  boundsMin, boundsMax, worldTranslation
    int   textureNameBytes, textureCount
    char  textureNames[]                  NUL-terminated
    byte  vertexCounts[polygonCount][2]   per polygon: count and extra
    ...   leaves, planes, surfaces, points, polygons, nodes

A surface holds a texture index and three vectors: a mapping origin and two
axes. A polygon holds a centre, lightmap dimensions, surface and plane indices,
its own mapping vectors, and its vertex indices as 5-byte records of which the
first two bytes are the index.

**Texture coordinates are not stored per vertex.** They are computed by
projecting a vertex's offset from the surface origin onto the two axes and
dividing by the texture's dimensions, so the real texture size must be read
rather than assumed; a wrong size leaves the mapping correct but wrongly scaled.

### Structural models

Three models are not ordinary geometry. `PhysicsBSP` is the collision hull,
`VisBSP` the visibility structure, and `MainTerrain` the terrain. Rendering the
first two alongside the visible geometry buries the level in overlapping
surfaces, so they are excluded from the visual build and kept for collision.

### Validation

`worlds/singleplayer/m1s1.dat`, the mission that gates the project, parses to
294 world models, 13,681 points and 10,784 polygons, referencing 212 distinct
textures, **all of which resolve through the VFS**. The level renders and can be
flown through.

## Provenance of the geometry notes

The header, object records and property encoding above were derived
independently from a retail installation before any reference was consulted.

The world model layout was then learned from the 010 Editor binary templates
published in the `Research` directory of
[godot-dat-reader](https://github.com/haekb/godot-dat-reader). Those templates
are a format specification rather than an implementation. The repository
declares no licence, so under the policy in `THIRD_PARTY.md` it is
study-only: the field layout is recorded here in our own words and implemented
in OpenAvP2's own architecture, with no code taken from that project.

