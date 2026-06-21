# Roadmap — Arthur Stone Weapon System

The plan is split into phases. Each phase ends in something *playable* so the
core mechanic is always provable. We don't build a phase until the one before it
feels right.

Legend: ✅ done · 🔶 in progress · ⬜ planned

---

## Phase 0 — Project Setup ✅

Get a clean, openable, public-ready repository in place.

- ✅ Godot 4 project (`project.godot`, input map, main scene)
- ✅ Repository structure (`scenes/`, `scripts/`, `assets/`, `docs/`, `devlog/`)
- ✅ `README`, `LICENSE` (MIT), `.gitignore`, `.gitattributes`
- ✅ `ROADMAP`, `CHANGELOG`, concept + design docs
- ✅ A basic boot scene that actually runs

---

## Phase 1 — 2D Core Prototype ✅  → ships as **v0.1.0**

The smallest thing that proves the mechanic.

- ✅ Arthur movement with weight + momentum
- ✅ Stamina pool (spend on swing, delayed regen, exhaustion fizzle)
- ✅ Heavy weapon swing: wind-up → active → recovery state machine
- ✅ Hold-to-charge swing variant
- ✅ Knockback on target dummies
- ✅ A few target dummies + a walled arena
- ✅ Minimal HUD (stamina + weapon state)

**Milestone reached → tag `v0.1.0`.**

---

## Phase 2 — Game Feel 🔶  → ships as **v0.2.0**

Make the existing mechanic *feel* as good as it reads.

- ✅ Hit-stop / freeze-frame on impact (scaled to hit strength)
- ✅ Swing arc trail + a charge ring on the stone
- ✅ Camera shake scaled to impact
- ✅ Tunable knockback — now centralized in the `Impact` hub
- 🔶 Squash/stretch on enemies (flash + defeat fade in; squash pending)
- ⬜ Recovery-timing pass: make the punish window *readable*
- ⬜ Audio hooks (whoosh on wind-up, crunch on impact)

---

## Phase 3 — Physics Depth ✅  → ships as **v0.2.0 → v0.3.0**

Let the stone's mass become a real, exploitable system.

- ✅ **Passive physical presence** — the stone blocks/shoves enemies and props
  while aiming (AnimatableBody2D stone head + RigidBody2D enemies/props)
- ✅ **Overhead slam** with a radial **shockwave** (knockback + stun + cracks/dust)
- ✅ Launchable **rock + crate props**, including **debris** dropped by a slam
- ✅ **Momentum-based impact formula** (one tunable `Impact` hub):
  `speed × mass × charge × angle × collision × combo`
- ✅ **Wall crush / no-cushion** bonus (raycast for a wall behind the target)
- ✅ **Enemy-to-enemy bowling** (rigid-body collisions score real hits)
- ✅ **Stone Flow** combo meter (build / decay / break, small stack buffs)
- ✅ **Enemy types** from one configurable script (Dummy, Light, Shield, Heavy)
- ✅ **Rotational inertia / drag** — the swing is a real spring-damped pendulum that
  lags, overshoots, and lunges Arthur's body (the v0.4.0 momentum swing)
- 🔶 Light terrain damage / cracks (transient on slam; persistent decals pending)
- ⬜ Destructible crates / walls; heavy-weapon sliding after a big swing
- ⬜ Different **stone sizes** as a power ↔ mobility dial

---

## Phase 3.5 — Spin Attack & Challenge Rooms ⬜  → targets **v0.4.0**

Build on the now-stable physics into a "weapon as tool" puzzle layer.

- ✅ Push enemies / rocks / crates onto a **pressure plate** to open a gate
  (the first puzzle seam — shipped in v0.3.0)
- ⬜ **Spin / tornado** attack: whirl the stone, push everything outward, clear
  dust/smoke — drains stamina fast, dangerous to overuse (Arthur loses control)
- ⬜ Launch rocks into **weak walls** and **bridge supports**
- ⬜ Dirt mounds as temporary barriers; boulders as heavier plate weights

### Challenge rooms (designed; not yet built)

Small hand-built rooms that each teach one trick, built on the existing seams:

- ⬜ **Wall-Crush Training** — defeat enemies only by pinning them to walls
- ⬜ **Bowling Room** — clear a formation with one launched enemy
- ⬜ **Rock Launcher** — hit enemies only by launching rocks/crates
- ⬜ **Bridge Break** — destroy supports with heavy hits to open a route
- ⬜ **Pressure-Plate Puzzle** — weight several plates to unlock the next room
- ⬜ **Smoke Room** — clear smoke with the spin attack to reveal enemies
- ⬜ **Stamina Discipline** — clear the room without exhausting stamina
- ⬜ **Combo Trial** — reach a Stone Flow stack before time runs out

---

## Phase 4 — Momentum Swing & Battlefield ✅  → ships as **v0.4.0**

The heavy attack becomes momentum; the arena becomes a battlefield.

- ✅ **Momentum swing** — the head is a spring-damped pendulum that trails behind
  Arthur and is *flung* by a press; damage from real head speed, no charge bar
- ✅ **Swing lunge** — each swing dashes Arthur forward (chain to sprint/reposition)
- ✅ **Enemy AI** — approach / guard / telegraphed attack / stagger, that yields to
  physics the instant the body is launched (steer-then-ragdoll)
- ✅ **Enemy types**: Light Soldier, Shield Soldier (block + bash + **SHIELD BREAK**),
  Spearman (spacing + thrust), Heavy Guard, Banner Bearer (morale)
- ✅ **Shield-wall** formation + spear line + flanking charge group + banner
- ✅ **Battlefield terrain**: mud drag, funnel fences, launchable props
- ✅ **Arthur health** + i-frames + death; **"Break the Shield Wall"** objective + win/lose
- ⬜ Balance pass against playtests; more objectives

### Cavalry & war cart (designed, next milestone)

Built to slot into the AI's "steer-then-ragdoll" seam:

- ⬜ **Cavalry** — a light/medium mounted warrior: repositions at range, picks a
  charge lane, shows a warning line, charges mostly straight with poor turning,
  overshoots, and is vulnerable from the side. Slows in mud, trips on fences, can be
  redirected by a side hit or a launched prop, and dismounted by a strong charged
  swing. Feedback: `CAVALRY CHARGE` / `SIDE HIT` / `CHARGE BROKEN` / `RIDER DISMOUNTED`.
- ⬜ **War cart / relic chariot** — a dangerous moving mass: charges straight, knocks
  soldiers aside, deflects on a heavy hit, flips on a charged side hit, and breaks
  into launchable debris on a wall impact. Feedback: `CART FLIPPED`.
- ⬜ More objectives: Stop the Cavalry Charge, Reverse the Charge, Capture the Banner,
  Hold the Line, Cart Breaker, Mud Trap.

---

## Phase 4.5 — Public Demo 🔶  → ongoing

Get it into other people's hands.

- 🔶 Web (HTML5) export ✅ + a desktop build ⬜
- ✅ Publish GitHub **Releases** (`v0.1.0` → `v0.4.0`) — source milestones; desktop binary still to attach
- ✅ GitHub **Pages** hosting the web build: <https://dd-ching.github.io/arthur-stone-weapon-system/>
  (auto-deployed by [`.github/workflows/pages.yml`](.github/workflows/pages.yml))
- ⬜ A capture (GIF/video) of the core loop
- ⬜ Devlog write-up of what players actually felt

Export steps are documented in [`docs/BUILD.md`](docs/BUILD.md).

---

## Phase 5 — Future 3D Exploration ⬜

Document (not necessarily build) the translation to 3D.

- ⬜ Map each 2D system to its 3D equivalent (see README → *Future 3D direction*)
- ⬜ Prototype Arthur on a 3D ground plane with the same momentum feel
- ⬜ Replace the swept 2D hitbox with a 3D arc volume / shapecast
- ⬜ Confirm the swing state machine survives the move unchanged
- ⬜ Write up what transferred cleanly and what didn't

---

## Backlog / ideas parking lot

Not scheduled, not forgotten:

- Weapon upgrade paths and a progression loop
- The "failed chosen one" narrative thread
- Deliberate physics-comedy moments
- Enemies that move, threaten, and can be juggled
- Stamina-exhaustion states (stagger, drop the stone)
- Alternate weapons born from the same joke (the anvil, the church bell…)

---

## Versioning

Semantic-ish tags. A new `0.x.0` lands when a phase reaches a playable milestone
on `main`; `0.x.y` patches fix feel/bugs within a phase.
