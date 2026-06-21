# Devlog 0009 — The objectives module

**Date:** 2026-06-21
**Build / tag:** v0.10.0

## 1. What changed?

The next framework batch. The level's win/lose used to be hand-coded inside
`Battlefield.gd` (`_check_victory` / the breach cap). Now it's composed from reusable
**objectives**:

- `Objective` (base) + `RepelWavesObjective`, `DefeatOfficerObjective`,
  `HoldLineObjective`, run by an `ObjectiveManager`.
- `Battlefield` just registers the three objectives; the manager decides win/lose and
  builds the HUD line. A new battle is now a different *list*, not new code.

A small gameplay consequence: winning Hold the Ford now also requires **defeating the
enemy officer** (the banner bearer), not just repelling the waves — exactly the spec's
"defeat the officer to break morale."

## 2. Why this fits the framework

The whole goal is "build once, reuse many." Win conditions were the most level-specific
thing left in the codebase. Pulling them into objects means the *next* level —
"Break the Shield Wall", "Stop the Charge", "Protect the Banner" — is assembled by
picking objectives off a shelf and tuning their parameters. The level script goes back to
its real job: laying out the battlefield.

## 3. What idea was tested?

**Two kinds of objective.** The first cut treated every objective the same and the game
stopped being winnable — `HoldLineObjective` (a "don't let the line break" rule) is never
"done", so requiring it to be done to win blocked the win forever. The fix was to name the
distinction: an objective is either *completable* (must be done to win) or a *constraint*
(`completable = false` — it can only fail you). That one flag is what lets a manager mix
"do these things" with "without letting these things happen" — the shape almost every
mission objective takes.

## 4. What still feels wrong?

- **Formations are still hand-placed** in the scene; the garrison and waves don't yet use
  a `Formation` module.
- **Abilities** are still branches in `Enemy`, not data.
- The objective HUD line is getting long (`WAVE x/5 · OFFICER ALIVE · BREACH x/12`).

## 5. What is next?

- A `formations/` module (placeable ShieldWall / SpearLine / ChargeGroup), then an
  `abilities/` data system. See [`docs/BATCH_PLAN.md`](../docs/BATCH_PLAN.md).

→ Tracked in [`ROADMAP.md`](../ROADMAP.md).
