# Devlog 0001 — First playable

**Date:** 2026-06-20
**Build / tag:** v0.1.0

## 1. What was built?

The whole Phase 1 core, from an empty folder to a runnable prototype:

- A Godot 4 project with an input map and `Arena.tscn` as the main scene.
- `Arthur` with momentum movement — low acceleration, sliding stop — so he reads
  as heavy before he even swings.
- `StoneWeapon` as a four-state swing machine (ready → wind-up → active →
  recovery) with hold-to-charge.
- A stamina pool that's spent on swings, regenerates after a delay, and fizzles
  the swing if you're too tired.
- Knockback on four target dummies, with wall rebound and hit counters.
- A follow camera with impact-scaled shake, and a minimal stamina/state HUD.

## 2. What was learned?

- **The wind-up and recovery carry the weight, not the swing itself.** The active
  sweep is fast (~0.16s); the *feeling* of heaviness comes almost entirely from
  the slow wind-up and the long, movement-throttled recovery. That's the cheapest,
  strongest lever for "this thing is heavy."
- **Aim lag is a sneaky-good idea.** Making the weapon rotate slowly toward the
  mouse — and slower mid-swing — turned "heavy" from a number into something you
  feel in your hands while lining up a hit.
- **Decoupling targets via a group + `apply_knockback()` keeps the weapon dumb.**
  The weapon doesn't know what a dummy is, which is exactly the seam enemies and
  destructibles will use later.

## 3. What still feels wrong?

- No **hit-stop** yet, so a landed hit is less punchy than the knockback distance
  implies. The impact reads visually (shake + launch) but not in the *timing*.
- The exhaustion **fizzle** is functional but under-communicated — a flash on the
  bar isn't enough; Arthur should visibly stumble or drop the head.
- Recovery is currently a flat ease-back; it should probably have a tiny
  over-swing/wobble so the stone feels like it's settling, not snapping.
- Tuning is all guesswork right now — the numbers feel *plausible* but haven't
  been pressure-tested against a real player.

## 4. What's the next experiment?

- Add **hit-stop** (freeze a few frames on impact, scaled by charge) and A/B it
  against the current feel. Hypothesis: it'll make light hits feel as committed
  as heavy ones.
- Give the fizzle a real **stagger** animation/state so overcommitting *looks*
  like a mistake, not a no-op.
- Start a proper tuning pass on wind-up vs recovery vs movement-throttle — find
  the point where missing feels *fair* but scary.

→ Tracked as Phase 2 (Game Feel) in [`ROADMAP.md`](../ROADMAP.md).
