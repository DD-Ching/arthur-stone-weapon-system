# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project aims to follow semantic-ish versioning (`MAJOR.MINOR.PATCH`),
where a new `MINOR` marks a playable milestone reaching `main`.

## [Unreleased]

### Planned
- Phase 3.5: spin/tornado attack and puzzle-combat interactions (switches, weak
  walls, pressure plates). See [`ROADMAP.md`](ROADMAP.md).

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

[Unreleased]: https://github.com/DD-Ching/arthur-stone-weapon-system/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/DD-Ching/arthur-stone-weapon-system/releases/tag/v0.1.0
