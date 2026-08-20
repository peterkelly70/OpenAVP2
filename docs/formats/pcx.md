# PCX — Interface Images

AvP2 stores its interface artwork as PCX: menus, HUD elements, icons,
crosshairs. 376 images in a patched installation, more than any other interface
format.

PCX is a published ZSoft format predating LithTech and is not game specific.
Godot has no importer for it, so without a decoder every interface image in an
installation is unreadable.

## Structure

A 128-byte header, a run-length encoded body, and for palettised images a
palette appended at the end.

| Offset | Field |
|---|---|
| `0x00` | Manufacturer, always `0x0A` |
| `0x01` | Version, 5 throughout AvP2 |
| `0x02` | Encoding, 1 meaning run-length |
| `0x03` | Bits per pixel per plane |
| `0x04`–`0x0B` | Bounds as min x, min y, max x, max y |
| `0x41` | Number of colour planes |
| `0x42` | Bytes per scanline in one plane |

Width and height come from the bounds rather than being stored directly.
`bytesPerLine` may exceed the width, so scanlines are padded and the surplus
must be skipped rather than read as pixels.

### Run-length encoding

A byte with its top two bits set is a repeat count in its low six bits,
followed by the value to repeat. Any other byte is a literal.

### Palette

A palettised image ends with a `0x0C` marker and 768 bytes of RGB. **This must
be excluded before decoding the body**, or the palette is consumed as pixel
data and the last rows of the image are quietly wrong.

## Variants in AvP2

| Variant | Count | Handled |
|---|---|---|
| 8 bits, 1 plane, palettised | 344 | Yes |
| 8 bits, 3 planes, RGB | 31 | Yes |
| 1 bit, 4 planes, planar | 1 | No |

The planar image is `interface/statusbar/marine/md_blip9.pcx`, one frame of the
motion tracker. It is reported as unsupported rather than decoded incorrectly.

Three-plane images store a full row of red, then green, then blue, rather than
interleaving them per pixel.

## Validation

375 of the 376 images in the installation decode, the exception being the
planar image above. `interface/avp2_logo.pcx` decodes to the game's 640 by 480
title logo with correct colours.
