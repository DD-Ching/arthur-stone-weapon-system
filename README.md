# Arthur Stone Weapon System

> *What if the chosen one failed the test — but broke the testing system instead?*

A small, playable **2D combat prototype** built in [Godot 4](https://godotengine.org/).
Arthur tried to pull the sword from the stone. He failed. Then he lifted the
**entire stone** out of the ground — sword and all — and decided that was close
enough.

The result is not a sword. It is a giant **stone-hammer / sword-stone hybrid**.
It is devastatingly powerful, and almost unusable. That tension *is* the game.

<p align="center"><em>Status: <strong>v0.1.0 — 2D Heavy Weapon Prototype</strong> · placeholder art · core mechanic playable</em></p>

<p align="center">
  <a href="https://dd-ching.github.io/arthur-stone-weapon-system/"><strong>▶ Play it in your browser</strong></a>
  &nbsp;·&nbsp;
  <a href="https://github.com/DD-Ching/arthur-stone-weapon-system/releases/tag/v0.1.0">Release notes</a>
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

## Current prototype status (v0.1.0)

What's actually in the build right now:

- ✅ Controllable Arthur with **momentum-based movement** (slow to start, slides to stop)
- ✅ The **stone-sword** weapon with a four-state swing: *ready → wind-up → active → recovery*
- ✅ **Hold-to-charge**: tap for a quick heavy swing, hold to wind up a bigger one
- ✅ **Stamina system** with spend-on-swing, a regen delay, and an exhaustion fizzle
- ✅ **Knockback** that launches target dummies (and bounces them off walls)
- ✅ Four **target dummies** with hit counters
- ✅ A walled **test arena** with a reference grid and a follow camera
- ✅ **Camera shake** scaled to hit strength
- ✅ A minimal **HUD**: stamina bar + live weapon-state read-out + control hints
- ✅ **Reset** hotkey to stand the dummies back up

What it is **not** yet: a real game. No enemies that fight back, no levels, no
audio, no win condition, no final art. See [`ROADMAP.md`](ROADMAP.md) for where
it's going.

---

## Controls

| Input                          | Action                                          |
| ------------------------------ | ----------------------------------------------- |
| `W` `A` `S` `D` / Arrow keys   | Move (with weight + momentum)                   |
| Mouse                          | Aim — the weapon turns *slowly* toward the cursor |
| `Space` / Left Mouse Button    | Heavy swing — **hold to charge**, release to commit |
| `R`                            | Reset the arena                                 |

Full notes and the design reasoning behind each control: [`docs/CONTROLS.md`](docs/CONTROLS.md).

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

- Ground-slam attack with a radial **shockwave**
- Real **rotational inertia** (the stone's mass actually swinging Arthur around)
- Destructible **crates / walls** and light terrain damage
- Enemies that move, threaten, and can be juggled by knockback
- **Stamina exhaustion** states (stagger / drop the stone)
- Different **stone sizes** as a power/mobility dial
- A **weapon upgrade path** and the "failed chosen one" narrative thread
- Physics-comedy moments (over-swinging into walls, sliding on the stone)

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
│   ├── Arena.tscn         #   main scene: walls, Arthur, dummies, HUD
│   ├── Arthur.tscn        #   player body + stone weapon + camera
│   ├── TargetDummy.tscn   #   a single knockback target
│   └── Hud.tscn           #   stamina bar + state read-out
├── scripts/               # GDScript — one responsibility per file
│   ├── Arthur.gd          #   movement, stamina, signal routing
│   ├── StoneWeapon.gd     #   the swing state machine + hitbox
│   ├── TargetDummy.gd     #   knockback receiver
│   ├── GameCamera.gd      #   follow + shake
│   ├── Hud.gd             #   HUD wiring
│   └── Arena.gd           #   floor/grid draw, HUD binding, reset
├── assets/                # placeholder/imported art (shapes are drawn in code for now)
├── docs/                  # concept, controls, design goals, architecture, build
├── devlog/                # short, honest development notes
├── .github/workflows/     # CI: a headless Godot import smoke test
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
