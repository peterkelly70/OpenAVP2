# REZ — LithTech Resource Archive

Container format for AvP2 game content. Everything except 84 loose files in a
retail installation lives inside these archives, which makes REZ the gate on all
other format work (roadmap stage 1).

## Provenance of these notes

Derived independently by inspecting archives from a legally owned retail
installation (AvP2 + Primal Hunt, patched to 1.0.9.6, plus the 2018 AvP2SMS
update). No reference implementation was consulted. Every claim below marked
*verified* was tested across all 19 archives in that installation; anything not
established is marked **unknown** rather than guessed.

## Header

The file opens with a fixed 127-byte ASCII banner, then binary fields.

| Offset | Size | Field | Status |
|---|---|---|---|
| `0x00` | 2 | `0D 0A` | verified |
| `0x02` | 60 | `RezMgr Version 1 Copyright (C) 1995 MONOLITH INC.`, space padded | verified |
| `0x3E` | 2 | `0D 0A` | verified |
| `0x40` | 60 | `LithTech Resource File`, space padded | verified |
| `0x7C` | 3 | `0D 0A 1A` — terminator | verified |
| `0x7F` | 4 | `version` (u32 LE), **1** in every AvP2 archive | verified |
| `0x83` | 4 | `rootDirPos` (u32 LE), offset of the root directory | verified |
| `0x87` | 4 | `rootDirSize` (u32 LE), size of the root directory | verified |
| `0x8B` | 4 | **unknown** — two observed values, see below | unknown |
| `0x8F` | 4 | **unknown** — a large offset, always below `rootDirPos` | unknown |
| `0x93` | 4 | `creationTime` (u32 LE), Unix `time_t` | verified |
| `0x97` | 4 | **unknown** — zero in all 19 archives | unknown |

All multi-byte integers observed so far are little-endian. Readers must not
assume host endianness.

### The `0D 0A 1A` terminator

The banner ends with CR LF SUB. `1A` is the DOS end-of-file character, so
`TYPE AVP2.REZ` on a DOS or Windows console prints the copyright banner and
stops rather than dumping 529 MB of binary. It is a display convention, not a
structural field, but it does give a cheap format check: a valid REZ begins
`0D 0A 52 65 7A 4D 67 72` (`\r\nRezMgr`).

### Verified invariant

    rootDirPos + rootDirSize == fileSize

This holds exactly for all 19 archives, which is what confirms the meaning of
both fields. The root directory is stored at the **end** of the archive, so a
reader seeks to `rootDirPos` and reads to EOF. It is worth asserting this in the
loader: a mismatch means a truncated or corrupt archive, and is a far better
error than failing later on a nonsensical entry offset.

### The unknown field at `0x8B`

Takes exactly two values across the installation:

| Value | Archives |
|---|---|
| `3080238` | All original 2001–2002 archives |
| `1701600` | `AVP2P5.REZ` and `LITHSERVER.REZ`, both from the 2018 update |

It therefore tracks the tool that wrote the archive rather than the archive's
contents. Candidate readings (max name lengths, a packer version) are not yet
distinguishable from this sample. Left unread until the directory structure is
understood; it may turn out to be irrelevant to loading.

## Directory structure

Verified. The root directory is a flat sequence of variable-length entries, each
beginning with a u32 discriminator. Directory entries point at a nested block of
the same form, so the archive is a tree.

### Directory entry (`flag == 1`)

| Offset | Size | Field |
|---|---|---|
| `0x00` | 4 | `flag` = 1 |
| `0x04` | 4 | `pos` — offset of this directory's own entry block |
| `0x08` | 4 | `size` — length of that block in bytes |
| `0x0C` | 4 | `time` — Unix `time_t` |
| `0x10` | n+1 | `name` — NUL-terminated ASCII |

Total: 16 + strlen(name) + 1.

### File entry (`flag == 0`)

| Offset | Size | Field |
|---|---|---|
| `0x00` | 4 | `flag` = 0 |
| `0x04` | 4 | `pos` — offset of the file's data in the archive |
| `0x08` | 4 | `size` — length of the file in bytes |
| `0x0C` | 4 | `time` — Unix `time_t` |
| `0x10` | 4 | `id` — a per-archive numeric identifier |
| `0x14` | 4 | `type` — extension as a **byte-reversed** four-character code |
| `0x18` | 4 | **unknown** — zero in all 13,376 files observed |
| `0x1C` | n+1 | `name` — NUL-terminated ASCII, **without** the extension |
| | 1 | **unknown** trailing byte — zero in every entry observed |

Total: 28 + strlen(name) + 2.

### The reversed type code

The extension is stored as four bytes in reverse order, so `WAV` appears in the
file as `56 41 57 00` (`"VAW\0"`). Read the four bytes, reverse them, and strip
NULs. The full name of a resource is `name + "." + type`.

Note that the name field does **not** include the extension, so a loader must
recombine the two. This matters for VFS path canonicalisation: the logical path
`Music/WaveTracks/Misc_Track25_HP4S3A.wav` is assembled from the directory
chain, the entry name, and the reversed type code.

### Entries with no type

160 entries carry an empty type code together with `pos == 0` and `size == 0`.
They are not readable files. Treat them as metadata and skip them rather than
attempting to extract them.

### Validation

The layout above was confirmed by parsing every archive to full depth. A correct
parser consumes each directory block to **exactly** its declared `size`; a wrong
one leaves a remainder or reads a nonsensical discriminator. Across all 19
archives:

- 557 directories, 13,376 files
- 0 malformed entries, 0 leftover bytes
- 0 entries whose `pos + size` exceeded the archive length

That total-consumption property is the strongest available check, and the reader
should assert it: any remainder means the entry layout has been misread, and
failing loudly at that point is far better than surfacing corrupt resources
later.

## Format census of a patched installation

The real stage 0 inventory, from all 19 archives:

| Type | Count | Meaning |
|---|---|---|
| DTX | 5,853 | Textures |
| WAV | 4,607 | Audio |
| ABC | 926 | Models and animation |
| PCX | 601 | Images, largely interface |
| SPR | 556 | Sprites |
| SGT | 188 | DirectMusic segments |
| DLS | 162 | DirectMusic instrument collections |
| **DAT** | **160** | **Worlds** |
| TXT | 132 | Text and configuration |
| (none) | 160 | Metadata entries, not files |
| STY | 15 | DirectMusic styles |
| DLL | 10 | Game code, not used by OpenAvP2 |
| LTO | 4 | Server objects, not used by OpenAvP2 |
| DEP, SCC | 2 | Build leftovers |

The music formats (SGT, DLS, STY) are DirectMusic, which has no modern
cross-platform equivalent. That is a larger audio problem than TDD section 13
anticipated and deserves its own decision before stage 0 is called complete.

## Archives in a patched installation

19 archives across both games. Load order matters: the patch archives override
base content, which is what the VFS mount precedence in TDD section 7 exists to
express.

| Archive | Size | Role |
|---|---|---|
| `AVP2.REZ` | 529 MB | Base game content |
| `AVP2X.REZ` | 291 MB | Primal Hunt content |
| `AVP2P5.REZ` | 224 MB | 2018 community update (AvP2SMS) |
| `SOUNDS.REZ` | 198 MB | Audio |
| `ALIEN.REZ` / `MARINE.REZ` / `PREDATOR.REZ` | 153 / 149 / 110 MB | Per-species content |
| `MULTI.REZ` | 53 MB | Multiplayer content |
| `AVP2P.REZ` | 45 MB | Patch |
| `DIALOGUE.REZ` | 6.7 MB | Speech |
| `AVP2DLL.REZ` | 5.3 MB | Game DLLs |
| `AVP2P1.REZ` | 4.7 MB | Patch |
| `LITHSERVER.REZ` | 3.4 MB | Dedicated server content |
| `AVP2L.REZ` | 3.0 MB | Localisation |

Determining the correct precedence among `AVP2P.REZ`, `AVP2P1.REZ` and
`AVP2P5.REZ` is a task for stage 1 and should be driven by what the game's own
configuration declares, not by filename ordering.
