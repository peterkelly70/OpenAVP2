# Compatibility Notes

Places where OpenAvP2 knowingly differs from the original, and why.

| Field | Meaning |
|---|---|
| Subsystem | Rendering, physics, audio, AI, scripting, … |
| Original behaviour | What Talon did |
| OpenAvP2 behaviour | What we do |
| Reason | Godot constraint, unknown semantics, deliberate improvement |
| Tolerance | Accepted deviation, if measurable |
| Flag | Compatibility flag that restores original behaviour, if any |

Deviations flagged at runtime use the `[COMPAT]` log channel:

```
[COMPAT] Door speed differs from reference tolerance: expected 128, got 131
```
