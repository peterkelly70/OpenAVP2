# Entity Notes

One document per DAT object class: property names and types, observed values,
runtime behaviour, and which missions depend on it.

Entities are implemented by frequency and mission criticality. `datdump` output
for the first Marine mission drives the initial priority list (TDD backlog item 9).

Unknown classes are logged, not fatal:

```
[ENTITY] Unsupported class AINodePatrol at (456.2, 127.4, -842.9)
```

Every such log line is a candidate for a document here.
