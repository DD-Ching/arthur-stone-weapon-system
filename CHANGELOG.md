# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow semantic-ish versioning (`MAJOR.MINOR.PATCH`),
where a new `MINOR` marks a playable milestone reaching `main`.

## [Unreleased]

### Planned
- A bigger crowd via cheaper enemy updates (pooling / coarser AI ticks), a KO + time
  score screen, and the challenge rooms. See [`ROADMAP.md`](ROADMAP.md).

---

## [0.8.0] — 2026-06-21

**Hold the Ford.** The ford becomes a real "hold the line" battle: five escalating
waves of raiders try to cross, allied footmen fight at your side, and letting too many
across loses the ford. Completes the Ford roadmap (river/wheel/bridge/audio) and makes
the army smarter.

### Added
- **Structured 5-wave assault** — reinforcements now arrive as five escalating waves
  (Light Raiders → Shield Soldiers → Spears behind shields → Cavalry + war cart → the
  Officer & escort), announced on the HUD, each launching once the field thins or a
  timer expires. Repel all five and the ford holds.
- **"Hold the Ford" lose condition** — a defence line + allied banner at your bank.
  Raiders now *march toward the banner* (fighting through the line to cross), not just
  at Arthur; a raider that walks past the line under its own power is a **BREACH**.
  Twelve breaches and the ford falls.
- **Allied footmen** — a team system on the one enemy script: allies spawn on your side,
  hunt the nearest raider, fight and die alongside you. No friendly fire — Arthur's
  stone shoves allies but never scores on them; a fallen ally costs no KO.
- **Smarter enemy AI** — units separate instead of stacking, non-shield raiders **flank**
  to surround rather than clump, spearmen keep their spacing, and everyone re-picks the
  nearest threat a few times a second (so they switch between Arthur and allies).
- **Bridge collapse** — the wooden bridge is now damageable: pound it with launched
  props and it **collapses**, turning the dry crossing into open water (denying the
  raiders their clean route).
- **Floating logs** — drift down the current from upstream; a fast log bowls raiders
  like a launched rock, and Arthur can swing them.
- **Real audio** — a `SoundBank` autoload synthesises a short procedural sound per
  event (thud, clank, splash, creak, rising chime…) and plays it, so the twelve audio
  hooks now actually make noise in the browser. No asset files.
- **Charger reach ×3** — cavalry and the war cart now commit to a charge three times
  as long, a real cross-the-field dash.
- A seventh headless test (`HoldFordTest`) covers allies, wave advance, and breaches.
  All seven tests pass.

---

## [0.7.0] — 2026-06-21

**The Ford of the Stone King.** The arena becomes a river crossing — terrain that is
itself a physics weapon. The combat, units, officer morale, mud, props, and objective
from v0.4–v0.6 are unchanged; this adds the *battlefield* around them.

### Added
- **The ford (river + current).** A shallow river spans the field. Off the bridge it
  drags bodies *and* a light downstream **current** drifts them sideways, so cavalry
  and carts lose their line in the water and loose props float away. Crossing a moving
  body in splashes (`SPLASH`). Data-driven `Rect2` bands like the mud — no fluid sim.
- **The wooden bridge.** A dry planked deck is the one clean crossing — the choke. Off
  it, the water slows the army, so the bridge naturally funnels the assault.
- **The water wheel.** A spinning mill wheel on the bank that **bats any enemy or prop
  that wanders (or is knocked) into it** — a tangential impulse flings them off, hard
  enough to go limp and fly. Knock a soldier into the wheel and watch them launch. An
  `Area2D` + one Godot impulse, debounced; no custom physics.
- **Audio event hooks.** A new `Audio` autoload is a named-event bus (`Audio.play(...)`
  → one `sfx(event, pos)` signal). All twelve brief events are wired at their real
  trigger points (`heavy_swing`, `stone_scrape`, `shield_block`, `shield_break`,
  `wall_crush`, `enemy_launch`, `chain_impact`, `cavalry_charge`, `banner_down`,
  `water_splash`, `water_wheel_creak`, `stone_flow_gain`) so dropping in real sounds
  later is a one-file change.
- The HUD objective now frames the fight as **HOLD THE FORD — BREAK THE SHIELD WALL**,
  with a "THE FORD OF THE STONE KING" title on spawn.
- A sixth headless test (`FordTest`) asserts the current drifts a body, the wheel
  launches one, and the audio events fire. All six tests pass.

---

## [0.6.3] — 2026-06-21

### Changed
- **Code-review + simplify pass** (no gameplay change) — removed leftovers from the
  v0.6.1 drag-to-swing rework, surfaced by an adversarially-verified review:
  - deleted the orphaned `StoneWeapon.press_attack()` / `release_attack()` wrappers
    (Arthur and the tests drive the weapon via `set_swinging()` directly),
  - deleted the unused `StoneWeapon.is_ready()` and the dead `swing_cost` export
    (stamina now drains continuously via `swing_stamina_rate`),
  - deleted the never-called `Impact.recovery_mult()` (and corrected the architecture
    doc that still listed it),
  - rewrote the `StoneWeapon` class docstring, which still described the removed
    "hangs behind / angular kick that flings the head" model, to match the actual
    spring-toward-cursor + drag-torque control.
- The review also *rejected* several tempting merges (unifying the swing/spin hit
  loops would have silently changed spin's Stone Flow economy; `note_miss()` is still
  used by the impact test) — left as-is on purpose. All five headless tests still pass.

---

## [0.6.2] — 2026-06-21

### Changed
- **Mounted units are now sized to scale.** The cavalry was barely larger than a foot
  soldier (radius 18 vs 16), so it didn't read as a horse + rider — bumped its radius
  and collision to **26** (≈1.6× a soldier). The war cart grew from **56×40 → 72×52**
  (radius 26 → 32) so the heavy charger clearly dwarfs infantry. Collision shapes track
  the new visuals; masses are unchanged (still launchable — strength still wins). Spawn
  positions are far apart, so the bigger bodies don't overlap on start. All five tests
  pass; cavalry charge still bowls fodder and breaks on a timed hit.

---

## [0.6.1] — 2026-06-21

**Drag-to-swing control.** The weapon is now controlled like a physics sandbox: you
*drag* the heavy stone rather than pressing an attack button.

### Changed
- **Normal mode** (button up): the head springs **toward the cursor** with weight and
  lag — it never snaps. Slow contact just **pushes/blocks** (the solid stone body),
  no scored damage.
- **Swing mode** (attack button held): the **mouse drag** applies torque — dragging
  **clockwise swings clockwise**, counter-clockwise swings counter-clockwise — and
  builds **real angular speed** (it follows the drag, not the shortest path to the
  cursor). Dragging costs stamina.
- **Damage is purely physical**: a hit only scores when the head is actually moving
  fast (the existing `Impact` formula reads head speed); a fast whip launches, a slow
  drag pushes, fast-into-a-wall still wall-crushes. A plain click no longer creates an
  attack. Hits apply continuously (re-biting a sustained contact), not as a scripted
  swing.
- Removed the click-to-fling + per-swing lunge (Arthur's knock-off on damage stays).
  Slam, spin, Stone Flow, wall crush, bowling, knockback, the horde, cavalry, and the
  war cart are all unchanged.

### Notes
- The swing smoke test now drives a real mouse drag; all five headless tests pass.

---

## [0.6.0] — 2026-06-21

**War Cart.** The last big charging mass joins the field.

### Added
- **War cart / relic chariot** (`WarCart.tscn`): a heavy, tanky charging mass that
  reuses the cavalry charge brain but plows the crowd, barely flinches from a light
  hit, staggers + breaks its charge on a solid blow, and — when finally wrecked —
  **flips and bursts into launchable debris** (`CART FLIPPED`) that Arthur can fling
  back into the army. One rides the central charge lane.

### Notes
- This completes the musou charge set-pieces (spin, horde, cavalry, war cart). The
  v0.3 `Arena.tscn` remains a calm sandbox; web build stays single-threaded.

---

## [0.5.0] — 2026-06-21

**Musou layer.** The battlefield leans into a Dynasty-Warriors power fantasy — one
absurd hero mowing through an army.

### Added
- **Spin / tornado attack** (hold `Shift` or middle-mouse): whirl the stone around
  Arthur, launching the whole crowd **outward in a ring**. Drains stamina fast,
  keeps some mobility (a moving tornado, not rooted), and takes no per-hit freeze so
  it never stutters; the head glows hot and a spin-radius ring shows the reach. It
  breaks shields it sweeps through and bowls launched enemies into the rest for chains.
- **KO counter** (top-right) with musou milestones — `RAMPAGE!` / `MASSACRE!` /
  `WARLORD!` / `LEGENDARY!` / `UNSTOPPABLE!` / `ONE-MAN ARMY!` flash on the round numbers.
- **Reinforcement horde**: the battlefield trickles fresh fodder in from the back
  rank to keep an army on the field (`horde_target`), so there's always more to mow.
- **Cavalry charge**: telegraphed mounted chargers that circle, show a charge lane,
  then charge straight — dangerous to Arthur and plowing through their own crowd, but
  a solid hit mid-charge staggers them and **breaks the charge** (`CHARGE BROKEN`).
- Headless spin + KO test wired into CI.

### Notes
- War cart is still **designed in [`ROADMAP.md`](ROADMAP.md)**. The v0.3 `Arena.tscn`
  remains as a calm sandbox. Web build stays single-threaded for GitHub Pages.

---

## [0.4.0] — 2026-06-21

**Momentum Swing & Battlefield Prototype.** The heavy attack became a physics
flail you fling with momentum, and the arena grew into a small ancient battlefield
with a thinking army and an objective.

### Changed — the swing is now momentum, not charge
- The stone head is a spring-damped **pendulum that hangs behind Arthur** and
  sloshes with real inertia as he moves and turns. Left-click / Space **applies a
  force** — an angular kick that flings the head from behind, around, to the front
  (clockwise or counter-clockwise emerges from the physics). The kick stacks on the
  momentum you already built by moving and whipping your aim.
- **Damage is read straight off the head's real speed** (no charge term). The stone
  glows hotter the faster it moves and the HUD shows live swing **POWER**.
- Each swing **lunges Arthur forward** — a dash you can chain to sprint/reposition,
  and the dash speed feeds the head's momentum.

### Added — battlefield
- **Enemy AI** on the shared `Enemy` base: approach, keep shield toward Arthur, a
  telegraphed attack (melee / shield-bash / spear thrust), and stagger. The AI
  **yields to physics the instant the body is launched or staggered**, so a hard
  enough hit always wins — Arthur's strength overrules a soldier's defense.
- **Enemy types** behave differently: Light Soldier (rush, flies far), Shield
  Soldier (front block + bash + **SHIELD BREAK** on a strong hit), Spearman (holds
  distance + telegraphed thrust), Heavy Guard (slow, hard to stagger), Banner
  Bearer (stays back; on death nearby enemies **panic**).
- Shields own their block/break maths, decided on the **raw** hit: a weak swing is
  `BLOCKED`, a strong swing `SHIELD BREAK`s and staggers; wall-crush bypasses it.
- A **shield-wall formation** + spear line + flanking charge group + heavy anchors
  + a banner, **mud** that drags charges, funnel **fences**, and launchable props.
- **Arthur health**, i-frames, a hurt flash, and death; taking a hit breaks Stone
  Flow. The **"Break the Shield Wall"** objective with a win/lose banner.
- New main scene `Battlefield.tscn`; HUD gains a health bar, objective line, and
  banner. A battlefield headless test (AI advance + Arthur damage + objective) in CI.

### Notes
- Cavalry and the war cart are **designed in [`ROADMAP.md`](ROADMAP.md)** for the
  next milestone, not yet built. The v0.3 `Arena.tscn` remains as a calm sandbox.
  Web build stays single-threaded for GitHub Pages.

---

## [0.3.0] — 2026-06-21

**Impact & Combo Prototype.** Every hit now has *consequences* — its force comes
from a real momentum-style formula, and chaining hits builds a combo. The weapon
became a physics tool, not just a sword.

### Added
- **Central impact system** (`Impact` autoload, `scripts/Impact.gd`): one place
  for every impact number and one scoring formula —
  `score = speed × mass × charge × angle × collision_bonus × combo` — that turns a
  hit into knockback, damage, stun, screen-shake, a feedback label, and combo gain.
  A swing, a thrown rock, a bowling enemy, and a slam all run through it.
- **Wall crush / no-cushion bonus**: a short raycast checks for a wall behind the
  target; pinned hits score and damage far more and pop `WALL CRUSH` / `STONE
  PRESS` / `NO CUSHION`. Pinning enemies before you hit them is now the strongest
  play (and bypasses shields).
- **Enemy collisions / bowling**: enemies are rigid bodies that collide with each
  other; a fast-flung enemy scores a real hit on the next one — `BOWLING HIT` →
  `CHAIN IMPACT` → `DOUBLE BONK`.
- **Stone Flow combo meter** (HUD bar + stack read-out): builds on meaningful
  hits, decays over time, and breaks on a whiffed swing or stamina exhaustion.
  Stacks grant *small* buffs (faster charge, a little mobility, shorter recovery,
  more force, a stack-5 "flow mode") — tuned so Arthur never feels weightless.
- **Enemy types** from one configurable `Enemy` script: Dummy, **Light Soldier**
  (low mass, flies far — great bowling balls), **Shield Soldier** (blocks frontal
  hits, vulnerable to flanks and wall crush), **Heavy Guard** (moving cover).
- **Crates** (`Crate.tscn`) alongside rocks, and a **pressure-plate puzzle**
  (`PressurePlate.tscn`): push or launch a prop onto the plate to open a gate.
- **Floating hit labels** (`FloatingText`), defeat fades, and hit-stop + screen
  shake now scaled by the computed impact score.
- **Redesigned arena**: a centre pillar to pin against, a corner pocket / corridor
  for wall-crush practice, a soldier formation, mixed props, and the plate puzzle.
- Headless **impact + Stone Flow test** (`tests/ImpactTest.tscn`), wired into CI,
  asserting a pinned hit out-damages an open hit, charge raises the score, and the
  combo gains on hits / loses on a miss.

### Changed
- The swing now reads its knockback/shake from `Impact` (measured head speed +
  charge + angle + wall-crush), so a slow touch pushes, a fast swing launches, and
  a charged-into-a-wall hit smashes. A swing that connects with nothing bleeds the
  combo.
- `TargetDummy` is now an instance of the shared `Enemy` script; the slam
  shockwave deals real damage + feeds a little Stone Flow.
- Knockback/shake magnitudes moved out of `StoneWeapon` into `Impact` — tuning
  truly lives in one place now.

### Notes
- Still placeholder shapes, still no audio. Enemies don't fight back yet, so Stone
  Flow's "break on damage taken" is wired but dormant. Web build remains
  single-threaded for GitHub Pages.

---

## [0.2.0] — 2026-06-21

**Physical Stone Weapon.** The weapon now reads correctly *and* behaves like a
heavy physical object, with a second attack and launchable props.

### Added
- **Passive physical presence**: the stone head is an `AnimatableBody2D` that
  blocks and shoves enemies/props even while only aiming — it's a heavy object you
  steer, not a cursor. Enemies and props are now `RigidBody2D` on named collision
  layers, so they collide with walls, each other, and the stone.
- **Overhead slam** (right mouse button): raise → hold → drop with a radial
  **shockwave** (distance-falloff knockback + stun), cracks/dust, big shake +
  hit-stop, and a **debris rock** dropped at the impact — closing the
  slam → launch → hit loop.
- **Launchable rock props** (`Rock.tscn`) that a swing or slam can fling into enemies.
- **Hit-stop** on impact (scaled to hit strength) and a **swing trail** + **charge ring**.
- Behaviour test (`tests/BehaviorTest.tscn`) covering passive presence, the slam
  shockwave, knockback, and debris spawning.
- Headless swing smoke test (`tests/SwingSmokeTest.tscn`), wired into CI.
- Live **web demo** on GitHub Pages, auto-deployed from `main`
  (`.github/workflows/pages.yml`): <https://dd-ching.github.io/arthur-stone-weapon-system/>
- `export_presets.cfg` with a Web preset; named 2D physics layers in `project.godot`.

### Changed
- **Weapon visual corrected**: Arthur grips the **sword handle** (grip + pommel +
  crossguard); the blade runs *through* the heavy **stone head** (drawn embedded),
  reading as a sword-in-stone hammer instead of a separate wooden stick.
- `TargetDummy` is now a `RigidBody2D` (with friction via `linear_damp`), gaining a
  stun state; knockback is applied as a physics impulse.
- Swing knockback strengthened and the swing now launches rocks as well as enemies.

### Notes
- Still placeholder shapes, still no audio / enemy AI / win condition. The web
  build remains single-threaded so it runs on GitHub Pages.

---

## [0.1.0] — 2026-06-20

The first playable prototype: **2D Heavy Weapon Prototype**. Proves the core
mechanic — Arthur is powerful because he lifted the whole stone, but the stone
makes him slow, vulnerable, and hard to control.

### Added
- Godot 4 project structure, input map, and a runnable main scene (`Arena.tscn`).
- `Arthur` character with momentum-based movement (low acceleration, sliding stop).
- `StoneWeapon` heavy swing with a four-state machine: ready → wind-up → active → recovery.
- Hold-to-charge swing: tap for a quick heavy hit, hold to wind up a bigger one.
- Stamina system: spend-on-swing, post-swing regen delay, and an exhaustion fizzle
  that drops you straight into recovery.
- Knockback applied to target dummies, with wall rebound and a per-dummy hit counter.
- Four target dummies and a walled test arena with a faint reference grid.
- A follow `Camera2D` with impact-scaled screen shake.
- Minimal HUD: stamina bar, live weapon-state read-out, and on-screen control hints.
- `R` to reset the arena.
- Project docs: README, ROADMAP, concept, controls, design goals, architecture, build notes.
- First devlog entry.

### Notes
- All visuals are placeholder shapes drawn in code — game feel over polish, by design.
- No audio, no enemy AI, no win condition yet. See [`ROADMAP.md`](ROADMAP.md).

[Unreleased]: https://github.com/DD-Ching/arthur-stone-weapon-system/compare/v0.8.0...HEAD
[0.8.0]: https://github.com/DD-Ching/arthur-stone-weapon-system/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/DD-Ching/arthur-stone-weapon-system/compare/v0.6.3...v0.7.0
[0.6.3]: https://github.com/DD-Ching/arthur-stone-weapon-system/compare/v0.6.2...v0.6.3
[0.6.2]: https://github.com/DD-Ching/arthur-stone-weapon-system/compare/v0.6.1...v0.6.2
[0.6.1]: https://github.com/DD-Ching/arthur-stone-weapon-system/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/DD-Ching/arthur-stone-weapon-system/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/DD-Ching/arthur-stone-weapon-system/compare/v0.4.1...v0.5.0
[0.4.0]: https://github.com/DD-Ching/arthur-stone-weapon-system/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/DD-Ching/arthur-stone-weapon-system/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/DD-Ching/arthur-stone-weapon-system/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/DD-Ching/arthur-stone-weapon-system/releases/tag/v0.1.0
