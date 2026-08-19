# Architecture Decisions

Decisions taken after the Technical Design Document v0.1 was written, where they
supersede or extend it. The TDD remains the design of record; this file records
what changed and why.

## 1. GDScript replaces C# as the implementation language

**Supersedes:** TDD section 5, and Appendix C ("Implementation language: C# first").

The TDD chose C# for typed binary parsing and the .NET test ecosystem. That
requires the .NET SDK and the separate .NET build of Godot; the standard Godot
build has neither.

**Decision:** GDScript, on the standard Godot build. C++ GDExtension remains
available for hot paths that show measured need, as the TDD already allows.

**Consequences, accepted:**

- Binary decoding is slower than C# over spans. Mitigated by decision 2 below,
  which moves archive decoding out of the runtime path entirely.
- TDD section 7's "standalone library with no dependency on the game scene tree"
  stops being literal: GDScript runs only inside Godot, so the command line
  tools are `godot --headless --script tools/<name>.gd`. The *architectural*
  separation still holds, and is enforced by the format and inventory services
  taking a filesystem port rather than touching Godot's scene tree.
- No compile step, so type errors surface at runtime rather than at build time.
  Partly offset by the test suite and by GDScript's static typing hints, which
  the project uses throughout.

**Gained:** the test suite runs locally in under a second against the installed
Godot, instead of every change round-tripping through CI to find out whether it
compiled. On a project this size that feedback loop is worth more than the
parsing throughput being traded away.

## 2. Archives are extracted up front, not read at runtime

**Extends:** TDD sections 6, 7 and 8.1, which already provide for cached
converted resources under OpenAvP2-owned directories.

A retail installation holds 1.4 GB across 12 REZ archives, and only 84 loose
files. Parsing archives on every launch would make GDScript's decoding speed a
permanent runtime cost.

**Decision:** extract archives once, as an explicit import step, into an
OpenAvP2-owned cache. The runtime then reads loose files, and archive decoding
becomes a one-time cost paid at install time rather than per launch.

**Consequences:**

- Extraction must preserve source layering rather than flattening: each archive
  extracts to its own layer, and the VFS resolves precedence across those layers
  at runtime. Flattening on extraction would destroy the override order in TDD
  section 7 and break mod support.
- Extracted content is copyrighted game data. It goes to an OpenAvP2-owned cache
  directory, never into the repository or any release artefact. `.gitignore`
  excludes `extracted/` and `cache/` alongside the archive extensions.
- The cache needs a version stamp, so that a change to the extractor or to a
  decoder invalidates stale output rather than silently serving it.
- Disk cost roughly doubles the installation footprint. The import step should
  report the space required before starting.

## 3. The engine layer stays game-neutral; the game layer does not

**Extends:** TDD sections 8 and 18.

AvP2 is one of several titles built on LithTech, and the container, texture and
world formats are engine formats rather than AvP2 formats. Keeping the readers
game-neutral costs almost nothing while the alternative, discovering later that
AvP2 assumptions have spread through the format layer, is expensive.

**Decision:** `src/lithtech/` contains no knowledge of AvP2. Game-specific facts
live above it, in installation discovery, the entity registry and the gameplay
layer.

**Current position, audited:**

- The only AvP2-specific value in `src/` is `REQUIRED_ARCHIVES` in the
  installation validator, which is the correct place for it: identifying an
  installation is inherently game-specific.
- The format readers carry no AvP2 assumptions.
- Only the DTX reader touches Godot, unavoidably, since it produces an `Image`.
  Everything else in `src/lithtech/` is engine-free and testable headless.

**Versions are the real axis of variation.** Each reader holds a set of
supported versions rather than a single constant, and reports both the version
found and the versions it handles when it refuses a file. Adding a version is
then a data change plus whatever branching that version needs, which is what TDD
section 8.3 asks for when it says version differences belong behind
version-specific readers.

**What this deliberately does not do.** No abstraction is being built for games
whose files cannot be tested. The supported sets list only versions verified
against real data: REZ 1, DTX -5, DAT 70. Adding speculative version numbers
would be a guess wearing the costume of a feature, and the project has a first
playable mission to reach before it earns the right to generalise.
