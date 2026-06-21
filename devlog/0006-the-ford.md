# Devlog 0006 — The Ford of the Stone King

**Date:** 2026-06-21
**Build / tag:** v0.7.0

## 1. What changed?

The empty muddy arena became a **river crossing** — and the terrain became a weapon.

- **The ford** — a shallow river spans the field. Off the bridge it drags bodies
  *and* a light **downstream current** drifts them sideways. A cavalry charge that
  tries to ford loses its line; a knocked-loose crate floats away; Arthur himself gets
  gently shoved while he wades.
- **The wooden bridge** — a dry planked deck down the middle, the one clean crossing.
  Because the water slows everything off it, the bridge naturally **funnels the
  assault** into a choke you can hold.
- **The water wheel** — a spinning mill wheel on the bank that **bats anything knocked
  into it** clear across the field. Knock a soldier into the paddles and they launch.
- **Audio event hooks** — a new `Audio` autoload, a named-event bus. Every impact now
  calls `Audio.play("heavy_swing" / "shield_break" / "water_splash" / …)`; twelve
  events are wired at their real trigger points, waiting for sound assets.

## 2. Why move from test arena to battlefield?

The brief's design line is *"the battlefield is not decoration — it is a physics
playground."* An arena where the only physics is your own weapon is a sandbox with one
toy. The Ford adds **terrain that fights back and can be turned against the enemy**:
the current steals a charger's aim, the wheel is a second attacker you aim *enemies*
into, the bridge is a position worth holding. Arthur is still overwhelmingly strong —
the challenge was never that he can't fight, it's *where* he applies that force.

## 3. What physics / gameplay idea was tested?

**Terrain as Godot physics, not a simulation.** Per the brief, no custom fluid sim.
The river is the same data-driven `Rect2` trick the mud already used — point-in-rect,
multiply velocity by a drag, add a current vector. The water wheel is an `Area2D` that
each frame applies one tangential + outward impulse to whatever `RigidBody2D` overlaps
it, debounced through the existing `Impact.try_collision_hit` so a body is batted a few
times a second instead of every frame. Both lean entirely on the engine: the *enemies
go limp when launched* seam (from way back in v0.4) means the current and the wheel
scatter a living army for free, exactly like the swing and the spin do.

## 4. What still feels wrong?

- **The objective hasn't caught up.** It's still "Break the Shield Wall," now flavoured
  as holding the ford — but a true **"Hold the Ford"** lose condition (too many raiders
  cross) and a **structured wave escalation** are what the river is asking for.
- **Reinforcements are a random trickle,** not the raiders → shields → spears → cavalry
  → officer build the brief sketches.
- **No real audio yet** — the hooks fire into the void until sounds are authored.

## 5. What is next?

- A **"Hold the Ford"** defend objective + a **5-wave** escalation.
- **Bridge collapse** as an objective (launch props into the supports).
- Floating **log** hazards drifting down the current.
- Real sounds behind the event hooks.

→ Tracked in [`ROADMAP.md`](../ROADMAP.md).
