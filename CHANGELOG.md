# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow semantic-ish versioning (`MAJOR.MINOR.PATCH`),
where a new `MINOR` marks a playable milestone reaching `main`.

## [Unreleased]

### Planned
- Layered objectives (officers, capture-the-banner, hold-the-line), a bigger crowd
  via cheaper enemy updates, and audio. See [`ROADMAP.md`](ROADMAP.md).

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

[Unreleased]: https://github.com/DD-Ching/arthur-stone-weapon-system/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/DD-Ching/arthur-stone-weapon-system/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/DD-Ching/arthur-stone-weapon-system/compare/v0.4.1...v0.5.0
[0.4.0]: https://github.com/DD-Ching/arthur-stone-weapon-system/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/DD-Ching/arthur-stone-weapon-system/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/DD-Ching/arthur-stone-weapon-system/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/DD-Ching/arthur-stone-weapon-system/releases/tag/v0.1.0
