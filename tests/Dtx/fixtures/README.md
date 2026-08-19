# Dtx test fixtures

Fixtures for Dtx parser tests.

**Never commit original AvP2 game data here.** Extracted archives, levels,
textures, models and sounds are copyrighted and are excluded by `.gitignore`.

Acceptable fixtures:

- Synthetic files constructed by test code to exercise header and edge-case handling.
- Hashes, dimensions, counts and other *measurements* taken from a real
  installation, stored as expected values rather than as game data.

Tests that require a real installation must skip cleanly when one is not
configured, so that CI stays green without game data.
