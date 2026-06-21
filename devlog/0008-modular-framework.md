# Devlog 0008 — A modular battlefield framework

**Date:** 2026-06-21
**Build / tag:** v0.9.0

## 1. What changed?

A refactor turn, not a content turn. The goal was to stop the project from becoming a
pile of one-off features and make the *next* ten versions cheaper to build.

- **Project memory** — `CLAUDE.md`, `docs/MEMORY.md`, `docs/BATCH_PLAN.md`, and a
  refreshed `ARCHITECTURE.md`, so a fresh session (human or AI) can get oriented fast.
- **`TerrainZone`** — terrain rules used to be hard-coded `const`s and a per-body loop
  *inside* the level script. Now a river/mud/ford is a placeable `Area2D` with exported
  rules (slow, current, dangerous, drowns-light). Drop another one anywhere → same
  behaviour. The ford river and mud are just instances.
- **`Spawner`** — the wave and ally spawn loops were near-duplicates; now they share one
  helper.
- **Smarter movement** — units recover when stuck, and **avoid dangerous terrain**: with
  the ford marked dangerous, the warband steers toward the bridge instead of wading in.

## 2. Why this fits the design

The acceptance test for the refactor was the game's own headline example: *a river
should make enemies funnel onto the bridge.* Before, that was a special case you'd hand-
script per level. Now it falls out of two reusable pieces — a `TerrainZone(dangerous)`
and a "crossing" marker — so the chokepoint is a property of the *terrain you placed*,
not the level's code. Build once, reuse many.

## 3. What physics / gameplay idea was tested?

**Compose, don't clobber.** The original terrain wrote `linear_velocity` directly. When
that moved into `TerrainZone`, the water wheel stopped throwing rocks — the zone's direct
velocity write was overwriting the wheel's impulse the same frame. The fix was to apply
drag and current as **impulses** (`apply_central_impulse`), which the physics server
accumulates alongside every other force. That didn't just fix the wheel: it fixed a
latent bug where a body standing in the current couldn't be knocked back at all. A good
sign the module boundary was the right one — the bug was *in* the old coupling.

## 4. What still feels wrong?

- **Formations and objectives are still inline** in the level script. They're the next
  obvious modules (`formations/`, `objectives/` + an `ObjectiveManager`).
- **Abilities** (slash/bash/thrust/charge/aura) are still branches inside `Enemy`, not
  data — fine for now, but a data-driven ability module would let enemies be *composed*.
- **Avoidance is a heuristic** (steer at the nearest crossing when danger is dead ahead),
  not real navigation. It funnels nicely but won't handle a maze.

## 5. What is next?

- `formations/` and `objectives/` modules; a data-driven ability system; a full
  `WaveSpawner` + pooling for a bigger crowd. See [`docs/BATCH_PLAN.md`](../docs/BATCH_PLAN.md).

→ Tracked in [`ROADMAP.md`](../ROADMAP.md).
