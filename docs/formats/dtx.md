# DTX — LithTech Texture

Texture format for AvP2. 5,853 files across a patched installation, the largest
single class of content in the game.

## Provenance of these notes

Derived independently by inspecting textures from a legally owned retail
installation. No reference implementation was consulted. Field meanings were
established by correlating header bytes against file sizes across all 5,080
textures in `AVP2.REZ`, so each claim below is measured rather than assumed.

## Header

164 bytes, followed immediately by pixel data.

| Offset | Size | Field | Status |
|---|---|---|---|
| `0x00` | 4 | Resource type, `0` in every observed file | verified |
| `0x04` | 4 | `version` (s32), **-5** in every AvP2 texture | verified |
| `0x08` | 2 | `width` (u16) | verified |
| `0x0A` | 2 | `height` (u16) | verified |
| `0x0C` | 2 | `mipmaps` (u16), levels stored including the base | verified |
| `0x0E` | 2 | `sections` (u16), 0 except in 2 files | verified |
| `0x10` | 4 | `flags` (s32), engine flags | partially understood |
| `0x14` | 4 | `userFlags` (s32), game-defined | partially understood |
| `0x18` | 12 | `extra[12]`, of which byte 2 is the pixel format | see below |
| `0x24` | 128 | `commandString`, NUL-terminated ASCII | verified |

`4 + 4 + 2 + 2 + 2 + 2 + 4 + 4 + 12 + 128 = 164`, which matches the header size
implied by every file's length.

## Pixel format

`extra[2]`, at offset `0x1A`. Confirmed by checking each value against the
number of bytes the file actually contains:

| Value | Format | Bytes per pixel | Count in `AVP2.REZ` |
|---|---|---|---|
| 0 | Unset; the field postdates these files, contents are 32-bit | 4 | 18 |
| 3 | 32-bit uncompressed | 4 | 427 |
| 4 | S3TC DXT1 | 0.5 | 3,504 |
| 5 | S3TC DXT3 | 1 | 102 |
| 6 | S3TC DXT5 | 1 | 1,029 |

Values 1, 2 and the 8-bit palettised case are defined by the format but do not
appear in AvP2.

Uncompressed pixels are stored **BGRA**; Godot expects RGBA, so the red and blue
channels must be exchanged. A missed swizzle produces an image that still looks
like a texture, which is why it is worth a targeted test rather than an eyeball
check.

## Mip chain

Levels follow the header contiguously, largest first, each a quarter the area of
the previous. Sizes for a level are computed from the format's bytes per pixel,
with each dimension halved and clamped to a minimum of one.

**AvP2 stores a partial chain.** A 256 by 256 texture typically carries four
levels rather than the nine needed to reach a single pixel. Godot's
`Image.create_from_data` requires a complete chain and rejects a partial one, so
OpenAvP2 uploads the base level and lets Godot generate mips at whatever quality
the renderer wants. The stored levels remain accessible for anything that needs
the originals.

## Command strings

3,306 of the 5,080 textures in `AVP2.REZ` carry a command string. These are
surface directives, and they answer several of the rendering questions in TDD
section 11 directly rather than by inference. 95 distinct strings appear.

| Directive | Example | Meaning |
|---|---|---|
| `ViewModes` | `ViewModes HeatVision NoFog;` | Behaviour under a species vision mode |
| `Detailtex` | `Detailtex WorldTextures\DetailTex\dt11.dtx` | Secondary detail texture layer |
| `ColorKey`, `AlphaRef` | `ColorKey 0 0 0;AlphaRef 128;` | Transparent colour and alpha test threshold |

The alpha test threshold is therefore **data, not a guess**. TDD section 11 lists
"correct cutout threshold behavior" as a compatibility requirement; the value is
in the texture.

Separately, the game ships dedicated texture sets under `skins/characters/heatvision/`,
so at least some vision modes are implemented with alternate art rather than
purely as a post-process. That matters for TDD sections 10.2 and 10.3.

## Validation

Every DTX in `AVP2.REZ` was parsed and converted to a Godot image:

- **5,080 of 5,080 decoded, 0 failures**
- Format distribution matches the independent size analysis exactly
- Spot-checked visually: a DXT3 character skin and a 32-bit prop texture both
  render with correct colour, confirming the byte order handling

Two textures under `worldtextures/lights/` carry more data than their mip chain
accounts for; they parse and decode correctly, and the surplus is left unread.
