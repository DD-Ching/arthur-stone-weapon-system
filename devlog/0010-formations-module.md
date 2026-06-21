# Devlog 0010 — The formations module

**Date:** 2026-06-21
**Build / tag:** v0.11.0

## 1. What changed?

Another framework batch. Troops were either hand-placed in the level scene or spawned as
a scattered mob. Now there's a reusable **`Formation`**:

- `formations/Formation.gd` — a placeable `Node2D` that spawns up to three ranks
  (front / support / commander) arranged perpendicular to its facing, on a team.
- `ShieldWall`, `SpearPhalanx` (spears behind shields), `OfficerGuard` (a banner ringed by
  guards) — `.tscn` configs you drop into a level or hand to a wave.
- The reinforcement waves now arrive as cohesive formations instead of a loose scatter:
  wave 2 a shield wall, wave 3 a phalanx, wave 5 the officer's guard.

## 2. Why this fits the framework

A "formation" is the unit of *tactical* level design, the way `TerrainZone` is the unit of
*terrain* and `Objective` is the unit of *mission*. With all three, building a battle is
mostly placement: lay down terrain zones, drop in formations, register objectives, tune
parameters. The level script stops being where content lives and goes back to being glue.

## 3. What idea was tested?

**Spawn ordering.** A formation sets each unit's `team` *before* `add_child` (so the unit's
`_ready` joins the right groups — raiders vs allies, officers) and its `global_position`
*after* (so the transform is resolved). The formation node adds units to its *parent* (the
level), not to itself, so they're independent bodies the instant they exist — the formation
is just the arrangement, not a container. That keeps a wave-spawned formation and an
editor-placed one identical.

## 4. What still feels wrong?

- **No break condition yet.** A real shield wall should *break* when its banner falls or
  enough soldiers are knocked away. The `units` list is kept as the hook for that; it's not
  wired.
- **The garrison is still hand-placed** in `Battlefield.tscn` (so `battle_test`'s
  `$ShieldWall` group keeps working). It could become `Formation` instances next.

## 5. What is next?

- An `abilities/` data system (slash / bash / thrust / charge / aura), then formation
  break/morale. See [`docs/BATCH_PLAN.md`](../docs/BATCH_PLAN.md).

→ Tracked in [`ROADMAP.md`](../ROADMAP.md).
