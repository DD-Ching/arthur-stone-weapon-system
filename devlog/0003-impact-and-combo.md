# Devlog 0003 — Impact, wall-crush, and Stone Flow

**Date:** 2026-06-21
**Build / tag:** v0.3.0

## 1. What was built?

The prototype could *hit*. This stage made hits **mean different things** — and
gave you a reason to chain them.

- **One impact formula, one place.** A new `Impact` autoload owns every impact
  number and a single scoring function:
  `score = speed × mass × charge × angle × collision_bonus × combo`.
  A swing, a thrown rock, a bowling enemy, and a slam all run through it, so the
  whole game speaks one language of force.
- **Wall crush.** When an enemy is hit with a wall right behind it (a short
  raycast checks), there's nowhere to fly — the hit scores much higher and pops
  `WALL CRUSH` / `STONE PRESS` / `NO CUSHION`. Pinning enemies before you swing is
  now the strongest thing you can do.
- **Bowling.** Enemies are rigid bodies that collide with *each other*. Fling a
  light soldier into a crowd and it scores real impacts down the line —
  `BOWLING HIT` → `CHAIN IMPACT` → `DOUBLE BONK`.
- **Stone Flow.** A combo meter that builds on good hits, decays if you stop, and
  **breaks** if you whiff a swing or run your stamina dry. Stacks give small
  buffs (faster charge, a little mobility, shorter recovery, more force, and a
  stack-5 "flow mode") — deliberately small, so Arthur never stops feeling heavy.
- **More to hit, more to hit *with*.** Light Soldier / Shield Soldier / Heavy
  Guard enemy types (one `Enemy` script, configured per scene), launchable
  **crates** alongside rocks, and a **pressure-plate** puzzle (push a prop onto it
  to open a gate). A redesigned arena with a pinning pillar and a corner pocket.
- **Feedback.** Floating hit labels, hit-stop and screen-shake now scaled by the
  computed score, defeat fades, and a Stone Flow bar on the HUD.

## 2. Why physics-based impact?

Because the fun in a heavy weapon isn't the swing — it's the **consequence**. A
fixed-damage hit is the same every time; a momentum-based one rewards *setup*.
Once damage depends on speed, mass, angle, and what's behind the target, the
player stops mashing and starts *arranging*: shove the shield guy into the pillar,
line the rock up with the crowd, save the slam for when they bunch up. The weapon
becomes a physics tool, which is the whole pitch — "the chosen one who lifted the
testing system."

Wall crush and enemy collisions are what turn an empty room into a puzzle. They
cost almost nothing to compute (one raycast; the engine already resolves the
collisions) but they create the "I can't believe that worked" moments the design
is chasing.

## 3. What is Stone Flow?

A rhythm tax in reverse. Most combo meters reward speed; this one rewards *not
breaking the chain* while still hauling a rock. You can't ninja it — the buffs are
tiny on purpose. What it really does is make you want to keep the room moving:
land, reposition, land again before it decays. Miss a swing or gas out and it
bleeds. It's the loop the brief asked for — *aim → commit → impact → reward →
reposition → again* — made visible.

## 4. What still feels wrong / what's next?

- **Combo can outrun the room.** One good swing scatters a cluster out of range,
  so the *next* swing whiffs and bleeds the flow you just earned. Wants either
  tighter spawns or a touch more forgiveness on the miss penalty.
- **Label pile-ups.** Multiple hits in one frame stack their floating text. Fine
  in motion, busy in a screenshot — could fan them out.
- **No enemy threat yet.** Stone Flow "breaks on damage taken" is wired for a
  future where enemies can actually hurt you; today only whiff/exhaustion break it.
- **Next:** the spin/tornado attack (Phase 3.5) and real challenge rooms built on
  the pressure-plate seam — wall-crush training, a bowling room, a rock-launcher
  range. Tracked in [`ROADMAP.md`](../ROADMAP.md).

→ Acceptance criteria for this stage are all green; details in
[`CHANGELOG.md`](../CHANGELOG.md).
