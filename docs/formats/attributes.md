# Attribute Files

AvP2 keeps its tuning in plain text under `attributes/`, not in code. Twenty-two
files covering movement, weapons, AI, pickups, objectives, surfaces and effects.

This is the same lesson as the music control files: behaviour that looks like it
must be recovered from the game's compiled code is often sitting in the data,
documented by its own key names.

## Format

    // comments run to end of line, and may follow a value

    [SectionName]
    Key    = value
    Vector = <0.0, 1.0, 0.0>
    Text   = "quoted string"

Sections use a base-and-override structure: a base section holds shared values
and specific sections override only what differs. A lookup therefore has to fall
back through a chain, most specific first, rather than reading one section in
isolation. `Marine_Exosuit_AI` defines only its own `WalkSpeed`, `RunSpeed` and
`LadderSpeed`, inheriting everything else from `BaseHuman`.

Tabs and spaces are mixed freely around the separator, and comments appear
after values on the same line.

## The files

| File | Size | Holds |
|---|---|---|
| `fx.txt` | 621 KB | Effects |
| `animationbutes.txt` | 329 KB | Animation |
| `weapons.txt` | 275 KB | Weapon behaviour |
| `modelbutes.txt` | 258 KB | Model definitions |
| `proptypes.txt` | 178 KB | Props |
| `debris.txt` | 143 KB | Debris |
| `soundbutes.txt` | 140 KB | Sound |
| `characterbutes.txt` | 121 KB | **Movement and character** |
| `layout.txt` | 77 KB | HUD layout |
| `aibutes.txt` | 59 KB | AI |
| `surface.txt` | 47 KB | Surface types |
| `pickupbutes.txt` | 39 KB | Pickups |
| `spawnbutes.txt` | 35 KB | Spawning |
| `music.txt` | 32 KB | Music selection |
| `visionmodebutes.txt` | 29 KB | Vision modes |
| `charactersounds.txt` | 26 KB | Character sound sets |
| `objectivebutes.txt` | 17 KB | Objectives |
| `missions.txt` | 13 KB | Mission structure |
| `attachments.txt` | 11 KB | Attachments |
| `clientbutes.txt` | 11 KB | Client settings |
| `closecaptionbutes.txt` | 5 KB | Captions |
| `aianimations.txt` | 5 KB | AI animation |

Every one is overridden by `AVP2P5.REZ`, the 2018 update, so reading them
without the VFS's precedence loads superseded values.

## Movement

`characterbutes.txt`, section `BaseHuman`:

| Key | Value | In metres |
|---|---|---|
| `WalkSpeed` | 125 | 1.56 m/s |
| `RunSpeed` | 300 | 3.75 m/s |
| `CrouchSpeed` | 90 | 1.13 m/s |
| `LiquidSpeed` | 165 | 2.06 m/s |
| `LadderSpeed` | 180 | 2.25 m/s |
| `NormJumpSpeed` | 550 | 6.88 m/s |
| `CameraHeightPercent` | 0.82 | eye at 82% of height |
| `CanWallWalk` | 0 | Marines cannot |

Speeds are in LithTech units per second and convert at eighty units to the
metre. Note that running is the faster gait rather than a brief sprint, so
`RunSpeed` is the normal movement.

`CanWallWalk` is the flag the Alien needs, which confirms that surface-relative
movement is a character attribute rather than a special case in the controller.

### It confirms the world scale independently

`CameraHeightPercent` is 0.82 and the first Marine mission places its
`GameStartPoint` at 128 units. A character whose eye is at 82% of its height and
sits at 128 units is 156 units tall, which at eighty units to the metre is 1.95
metres. That is a plausible height for a marine, and it agrees with the scale
derived separately from a 160-unit door being two metres.

Two independent measurements agreeing is worth more than either alone.

## Why this matters

The design document says movement should be tuned against reference behaviour
rather than left at engine defaults. It does not have to be tuned by
observation, and it should not be: the values are here, exact, and they resolve
through the VFS like any other resource, so a mod that changes movement changes
it in OpenAvP2 too.
