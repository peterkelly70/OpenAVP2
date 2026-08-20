# ABC — LithTech Model

Models for characters, weapons, props and menu artwork. 856 in a patched
installation.

## Structure

An ABC file is a chain of named sections, each carrying the offset of the next:

    u16  nameLength
    char name[nameLength]
    u32  nextSectionOffset      0xFFFFFFFF ends the chain
    ...  section data

Sections, in the order AvP2 writes them:

| Section | Holds |
|---|---|
| `Header` | Version, counts, command string |
| `Pieces` | Geometry, one piece per material |
| `Nodes` | Skeleton |
| `ChildModels` | References to other models |
| `Animation` | Keyframes |
| `Sockets` | Attachment points |
| `AnimBindings` | Animation metadata |

The chain is what makes partial support safe: a reader can take the sections it
understands and step over the rest without guessing at sizes. OpenAvP2 reads
geometry, skeleton and sockets, and steps over animation for now.

## Header

`version`, then counts. AvP2 uses **12** for 851 of its models, with 9 and 11
appearing a handful of times. Version 13 adds a field, and versions above 9 add
a per-piece level of detail weight; a reader that ignores either drifts by four
bytes and everything after it is wrong.

The header also carries a command string, in the same form as DTX textures use.

## Pieces and levels of detail

A piece is one material's worth of geometry, holding one mesh per level of
detail. Within a level, **faces come before vertices**, and each face vertex
carries its own texture coordinates alongside its vertex index.

That ordering matters. Coordinates are per index rather than per vertex, so a
vertex shared between two faces may carry different coordinates in each.
OpenAvP2 therefore expands triangles rather than sharing vertices, since one
mesh vertex cannot hold two sets of coordinates.

A vertex may carry bone weights before its position and normal, each naming a
node, a position and a bias.

## Nodes

The skeleton, stored depth first: each node gives its name, index, flags, a four
by four bind matrix, and how many children follow. Parents are recovered from
that ordering rather than from an index.

## Sockets

Attachment points, each naming a node and carrying a rotation and position.
1,550 across the installation. These are load-bearing rather than decorative:
weapons, effects and character equipment hang off them, so a model whose
sockets are lost cannot be equipped correctly.

## Validation

Every model in the installation parses:

- **856 of 856, 0 failures**
- 286,938 triangles at the most detailed level
- 14,418 bones, 1,550 sockets
- Versions: 12 (851), 9 (3), 11 (2)

Rendered and checked visually: `interface/menus/models/sp_predator.abc` with
`interface/menus/skins/sp_predator.dtx` produces the menu Predator with its
mask, dreadlocks and skin correct.

## Menu models

The front end is built from models rather than images, which is why the original
menu has a rotating head rather than a picture:

| Model | Use |
|---|---|
| `sp_marine`, `sp_predator`, `sp_drone` | Species heads on the single player screen |
| `sp_laser` | The Predator's sight beam |
| `ls_planet` | The planet backdrop |
| `menu_dropship`, `menu_egg` | Main menu |
| `lm_*`, `la_*`, `lp_*` | Per-species loading screens |

Each has a skin of the same name under `interface/menus/skins/`.

## Provenance

The section layout was learned from
[godot-abc-reader](https://github.com/haekb/godot-abc-reader), which is MIT
licensed and therefore reusable with attribution. The implementation here is
written in OpenAvP2's own architecture; see `THIRD_PARTY.md`.
