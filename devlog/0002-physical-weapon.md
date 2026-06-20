# Devlog 0002 — Making the stone physical

**Date:** 2026-06-21
**Build / tag:** v0.2.0

## 1. What was built?

A big step from "animated swing" to "physical object":

- **Fixed the weapon visual.** Arthur now grips the sword *handle* (grip + pommel +
  crossguard); the blade runs *through* a heavy stone head, drawn so it reads as
  embedded. The old version looked like he was holding a wooden stick beside a rock.
- **Passive physical presence.** The stone head is an `AnimatableBody2D` that blocks
  and shoves enemies/props even while you're only aiming. Enemies and rocks became
  `RigidBody2D` on named collision layers, so they collide with walls, each other,
  and the stone for free.
- **Overhead slam** (right-click): raise → hold → drop → shockwave (radial impulse
  with falloff + stun), cracks/dust, a debris rock, big shake + hit-stop.
- Hit-stop, a swing trail, a charge ring, and two headless tests (swing + behaviour)
  wired into CI.

## 2. What was learned?

- **`AnimatableBody2D` is the right tool for "a moving solid you steer."** Set
  `sync_to_physics`, move it each frame, and it shoves rigid bodies without any
  manual penetration code. The only trick was disabling its collider during the fast
  active swing so the *designed* impulse — not the chaotic sweep — does the hitting.
- **Spawn order bites.** `add_child()` runs `_ready()` *before* you can set the
  node's `global_position`, so the slam shockwave was computing knockback from the
  world origin. The fix (move the impulse into a `detonate()` called after
  positioning) is a good general rule: anything position-dependent shouldn't live in
  `_ready()` of a spawned node.
- **Tests lie if you let them.** The behaviour test passed *with the origin bug*
  because Arthur happened to sit at the origin. Spawning Arthur off-origin turned it
  into a real regression guard (and immediately caught a second issue — Arthur's
  mouse-aim hijacking the test's forced aim).

## 3. What still feels wrong?

- The passive push can get **twitchy** when the stone sweeps fast across a cluster —
  it's fun, but not yet *readable*. Needs a velocity cap or a softer push curve.
- The slam's "lift" is faked by scaling the stone + a shadow. It reads, but a real
  anticipation pose (pull fully behind Arthur, then overshoot forward) would sell the
  weight better.
- Cracks/dust are transient; the spec wants **persistent** cracked ground / dirt
  mounds you can interact with. Not there yet.
- No audio, so impacts still under-hit relative to how they look.

## 4. What's the next experiment?

- **Spin / tornado attack** (roadmap Phase 3.5): a held, stamina-draining whirl that
  pushes everything outward — the natural next layer now that the physics is stable.
- A tiny **puzzle room**: a pressure plate + a weak wall, to prove "weapon as tool"
  (launch a rock to break the wall; shove an enemy onto the plate).
- Tune the passive-push curve until herding enemies feels deliberate, not chaotic.

→ Tracked in [`ROADMAP.md`](../ROADMAP.md) (Phase 3 / Phase 3.5).
