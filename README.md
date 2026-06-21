# Arthur Stone Weapon System

> *What if the chosen one failed the test — but broke the testing system instead?*

A small, playable **2D combat prototype** built in [Godot 4](https://godotengine.org/).
Arthur tried to pull the sword from the stone. He failed. Then he lifted the
**entire stone** out of the ground — sword and all — and decided that was close
enough.

The result is not a sword. It is a giant **stone-hammer / sword-stone hybrid**.
It is devastatingly powerful, and almost unusable. That tension *is* the game.

<p align="center"><em>Status: <strong>v0.3.0 — Impact &amp; Combo</strong> · placeholder art · momentum-based hits, wall crush, bowling, and the Stone Flow combo playable</em></p>

<p align="center">
  <a href="https://dd-ching.github.io/arthur-stone-weapon-system/"><strong>▶ Play it in your browser</strong></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/DD-Ching/arthur-stone-weapon-system/releases">Release notes</a>
</p>

<p align="center">
  <a href="https://github.com/DD-Ching/arthur-stone-weapon-system/actions/workflows/validate.yml"><img alt="Validate" src="https://github.com/DD-Ching/arthur-stone-weapon-system/actions/workflows/validate.yml/badge.svg"></a>
  <a href="https://github.com/DD-Ching/arthur-stone-weapon-system/actions/workflows/pages.yml"><img alt="Deploy web demo" src="https://github.com/DD-Ching/arthur-stone-weapon-system/actions/workflows/pages.yml/badge.svg"></a>
</p>

---

## The core idea

The whole prototype exists to prove one feeling:

> **Arthur is powerful because he lifted the whole stone — but the stone also
> makes him slow, vulnerable, and hard to control.**

Every system is built around a trade-off:

| You get…            | You pay with…                          |
| ------------------- | -------------------------------------- |
| Huge impact force   | A slow, telegraphed wind-up            |
| A massive hitbox    | A long, exposed recovery               |
| Big knockback       | Stamina you can't spam                 |
| Momentum            | Precision — the stone fights your aim  |

A swing is a **commitment**. Missing should hurt. Connecting should feel great.

---

## Current prototype status (v0.3.0)

What's actually in the build right now:

- ✅ Controllable Arthur with **momentum-based movement** (slow to start, slides to stop)
- ✅ The **stone-sword**, drawn correctly: Arthur grips the **sword handle**; the blade
  runs *through* a heavy **stone head** that's swung like a hammer
- ✅ A four-state heavy swing (*ready → wind-up → active → recovery*) with **hold-to-charge**,
  a charge ring, and a swing trail — plus an **overhead slam** (right-click) with a shockwave
- ✅ **Passive physical presence** — the stone *blocks and shoves* enemies and props even
  while you're only aiming. It's a heavy object you steer, not a cursor
- ✅ **Momentum-based impact** — one formula (`speed × mass × charge × angle × collision × combo`)
  decides every hit, so a slow touch pushes, a fast swing launches, a charged swing smashes
- ✅ **Wall crush** — pin an enemy against a wall and the hit hurts *much* more (`WALL CRUSH` /
  `STONE PRESS`), even through a shield
- ✅ **Bowling** — rigid-body enemies collide with each other for chain hits (`BOWLING HIT` →
  `CHAIN IMPACT` → `DOUBLE BONK`); **rocks and crates** launch into enemies too
- ✅ **Stone Flow combo** — a HUD meter that builds on good hits, decays, and breaks on a whiff
  or exhaustion; stacks grant *small* buffs so Arthur never feels weightless
- ✅ **Enemy types** (one configurable script): Dummy, Light Soldier, Shield Soldier, Heavy Guard
- ✅ Floating **hit labels**, defeat fades, **camera shake** + **hit-stop** scaled to the impact
- ✅ A redesigned **arena** (pinning pillar, corner pocket, soldier formation) with a
  **pressure-plate puzzle**, a follow camera, and a HUD (stamina + weapon state + Stone Flow)

What it is **not** yet: a real game. Enemies don't fight back, no full levels/challenge rooms,
no audio, no win condition, no final art. See [`ROADMAP.md`](ROADMAP.md) for where it's going.

---

## Controls

| Input                          | Action                                          |
| ------------------------------ | ----------------------------------------------- |
| `W` `A` `S` `D` / Arrow keys   | Move (with weight + momentum)                   |
| Mouse                          | Aim — the weapon turns *slowly* toward the cursor |
| `Space` / Left Mouse Button    | Heavy swing — **hold to charge**, release to commit |
| **Right Mouse Button**         | **Overhead slam** — a committed smash with a shockwave |
| `R`                            | Reset the arena                                 |

Even without attacking, sweeping the mouse drags the heavy stone *through* enemies
and rocks, shoving them around. Full notes and the design reasoning behind each
control: [`docs/CONTROLS.md`](docs/CONTROLS.md).

---

## How to run

**Fastest:** just [**play it in your browser**](https://dd-ching.github.io/arthur-stone-weapon-system/) — a single-threaded Web build auto-deployed to GitHub Pages on every `main` push. (Give it a few seconds to download the engine and boot.)

**From source** (for tweaking) — you need **Godot 4.3 or newer** (standard build — no C#/.NET required):

1. Install Godot from <https://godotengine.org/download> (or your package manager).
2. Open the Godot **Project Manager** → **Import**.
3. Select this folder's [`project.godot`](project.godot) and click **Import & Edit**.
4. Press **F5** (or the ▶ Play button) to launch.

The first launch will import `icon.svg` and build the `.godot/` cache — that's
normal and only happens once.

> The web demo is built by [`.github/workflows/pages.yml`](.github/workflows/pages.yml).
> Export steps (web + desktop) are documented in [`docs/BUILD.md`](docs/BUILD.md).
> A downloadable desktop build is still planned for **Phase 4**.

---

## Design goals

1. **Game feel over visual polish.** Simple shapes, real *weight*. If it doesn't
   feel heavy, nothing else matters.
2. **The mechanic must be legible in 10 seconds.** A new player should *feel* the
   power/control trade-off on their first swing.
3. **Readable, hackable code.** Small scripts, one responsibility each, tunable
   from the Inspector. Easy for both humans and AI tools to modify.
4. **Honest scope.** Ship the smallest thing that proves the idea. Don't pretend
   it's more finished than it is.

More detail: [`docs/DESIGN_GOALS.md`](docs/DESIGN_GOALS.md).

---

## Planned features

Designed-for but intentionally **not** built yet, roughly in priority order:

- **Spin / tornado attack** — Arthur whirls the stone, clearing space and flinging
  everything outward; drains stamina fast and is dangerous to overuse
- **Puzzle interactions**: knock enemies into each other and into switches, launch
  rocks into weak walls / bridge supports, push boulders onto pressure plates
- Destructible **crates / walls** and persistent **cracked ground / dirt mounds**
- Enemies that move and threaten (right now they're physics dummies)
- Real **rotational inertia** (the stone's mass actually dragging Arthur around)
- Different **stone sizes** as a power/mobility dial, and a **weapon upgrade path**
- Audio + more physics-comedy moments (over-swinging into walls, sliding on the stone)

The full breakdown lives in [`ROADMAP.md`](ROADMAP.md).

---

## Future 3D direction

The 2D build is deliberately structured so the *systems* — not the rendering —
carry the design. Movement, the swing state machine, stamina, knockback, and
camera shake are all expressed in terms that map cleanly to 3D:

- 2D `Vector2` momentum → 3D `Vector3` on a ground plane
- The swept 2D hitbox → a 3D arc volume / shapecast
- Top-down aim angle → yaw, with the same "slow to turn" heaviness
- Screen-space camera shake → trauma-based 3D camera shake (identical math)

Phase 5 in the roadmap documents the translation in detail. The goal is that
moving to 3D is a *rendering and collision* change, not a redesign.

---

## Repository structure

```
arthur-stone-weapon-system/
├── project.godot          # Godot 4 project entry point — open this folder in Godot
├── icon.svg               # project icon (a sword stuck in a liftable stone)
├── scenes/                # .tscn scene files
│   ├── Arena.tscn         #   main scene: walls, Arthur, enemies, props, plate, HUD
│   ├── Arthur.tscn        #   player body + stone weapon (hitbox + stone body) + camera
│   ├── TargetDummy.tscn   #   Dummy enemy (the Enemy script, dummy config)
│   ├── LightSoldier.tscn  #   low-mass enemy — the bowling ball
│   ├── ShieldSoldier.tscn #   blocks frontal hits; crush or flank it
│   ├── HeavyGuard.tscn    #   high-mass enemy — moving cover
│   ├── Rock.tscn          #   a launchable rigid-body prop
│   ├── Crate.tscn         #   a launchable box (same prop script)
│   ├── PressurePlate.tscn #   puzzle plate + gate
│   ├── Shockwave.tscn     #   slam burst (spawned at runtime)
│   ├── FloatingText.tscn  #   hit label (spawned at runtime)
│   └── Hud.tscn           #   stamina + weapon state + Stone Flow
├── scripts/               # GDScript — one responsibility per file
│   ├── Impact.gd          #   AUTOLOAD: impact tuning + scoring formula + Stone Flow + feedback
│   ├── Arthur.gd          #   movement, stamina, slam input, hit-stop, signal routing
│   ├── StoneWeapon.gd     #   visual + swing/slam state machine + hitbox + stone body
│   ├── Enemy.gd           #   rigid-body enemy base: hit/knockback/block/stun, bowling, defeat
│   ├── Rock.gd            #   rigid-body prop/projectile (rock or crate)
│   ├── Shockwave.gd       #   slam radial impulse + fading visual
│   ├── PressurePlate.gd   #   plate → gate puzzle
│   ├── FloatingText.gd    #   rising/fading hit label
│   ├── GameCamera.gd      #   follow + shake
│   ├── Hud.gd             #   HUD wiring
│   └── Arena.gd           #   floor/grid + interior walls, HUD binding, reset
├── tests/                 # headless verification scenes (run in CI)
├── assets/                # placeholder/imported art (shapes are drawn in code for now)
├── docs/                  # concept, controls, design goals, architecture, build
├── devlog/                # short, honest development notes
├── .github/workflows/     # CI: headless import + tests, and the Pages deploy
├── .gitignore  .gitattributes
└── README.md  ROADMAP.md  CHANGELOG.md  CONTRIBUTING.md  LICENSE
```

A guided tour of how the scripts talk to each other:
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

---

## Development philosophy

This repo is also a **portfolio artifact**. The goal is to show how a mechanic
is discovered, not just shipped. So:

- Commits are small and conventional (`feat:`, `docs:`, `release:` …).
- `main` only holds playable milestones; `dev` holds active work. See
  [the git workflow](#git-workflow).
- Each devlog answers four questions: *What was built? What was learned? What
  still feels wrong? What's the next experiment?*
- We'd rather ship a tiny thing that feels right than a big thing that doesn't.

---

## Git workflow

- **`main`** — stable, playable milestones only. Tagged `v0.1.0`, `v0.2.0`, …
- **`dev`** — active development; integrates feature branches.
- **feature branches** — `feat/ground-slam`, `feat/inertia`, … for larger work.
- Merge into `main` only when a playable milestone is reached, then tag it.

---

## License

[MIT](LICENSE) © 2026 DD-Ching. Use it, fork it, learn from it.

---

*Built as a creative-engineering prototype: mythological parody meets physics
combat. It has a funny premise and a serious heart.*
