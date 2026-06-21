# Devlog 0011 — A real army

**Date:** 2026-06-21
**Build / tag:** v0.12.0

## 1. What changed?

A content + balance turn, riding the framework. The allies were six identical basic
footmen — too weak and too plain. Now the player commands a **real army**:

- New ally types (each a config of `Enemy.gd`, team `ally`): a **Shield Guard** front line,
  a **Spear Guard**, and a **Knight** — a heavy champion that shrugs off knockback and hits
  hard. The basic **Footman** got a buff.
- They deploy as an **`AlliedHost`** formation (shields front, spears behind, the Knight as
  the reserve champion) using the v0.11 formation module.
- A **`density`** dial (default 2.5) scales *both* armies — the garrison, every wave, and
  the allied host — for a dense mass battle.

## 2. Why this was cheap to build

This is the payoff of the last few batches. A new strong, varied army cost **zero new
systems**: every ally is a `.tscn` of the existing `Enemy` with `team = "ally"` and tuned
exports; they fight via the same AI; they deploy via the existing `Formation`; they're
held out of the objective counts by the existing team groups; and Arthur already skips the
`allies` group, so no friendly fire. "Build once, reuse many" did exactly what it promised
— this was config and placement, not code.

## 3. What idea was tested?

**One multiplier, both sides.** `density` scales counts uniformly: wave rosters via a
`_repeat` of their scene list, formations via `front_count/support_count × density`, and
the hand-placed garrison via a code-spawned `_bulk_garrison` remainder. The pre-placed
shield wall stays the `×1` base (so the headless `battle_test` still finds it), and the
rest is generated to reach the target.

## 4. What still feels wrong?

- **Performance.** ~67–90 bodies on the single-thread web build is the real cost; `density`
  is a knob, but a proper `EnemyPool` / coarser AI ticks would let it go higher cleanly.
- **Balance is a first guess.** A strong allied host plus Arthur may tip the fight; the
  numbers want a playtest pass.

## 5. What is next?

- An `abilities/` data system, then enemy pooling so the crowd can grow without the
  framerate cost. See [`docs/BATCH_PLAN.md`](../docs/BATCH_PLAN.md).

→ Tracked in [`ROADMAP.md`](../ROADMAP.md).
