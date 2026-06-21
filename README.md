# Arthur Stone Weapon System

> *What if the chosen one failed the test — but broke the testing system instead?*

A small, playable **2D combat prototype** built in [Godot 4](https://godotengine.org/).
Arthur tried to pull the sword from the stone. He failed. Then he lifted the
**entire stone** out of the ground — sword and all — and decided that was close
enough.

The result is not a sword. It is a giant **stone-hammer / sword-stone hybrid**.
It is devastatingly powerful, and almost unusable. That tension *is* the game.

<p align="center"><em>Status: <strong>v0.7.0 — The Ford of the Stone King</strong> · placeholder art · hold a river crossing, knocking soldiers into the current and the mill wheel, vs an endless raider warband</em></p>

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

## Current prototype status (v0.7.0)

What's actually in the build right now:

- ✅ **The Ford of the Stone King** — the arena is now a **river crossing**, and the
  terrain is a physics weapon. A **river with a downstream current** drags and drifts
  anything in it (cavalry and carts lose their line; props float away); a **wooden
  bridge** is the one dry crossing — the choke; and a spinning **water wheel** on the
  bank **bats any soldier or prop knocked into it** clear across the field. Built from
  Godot physics areas + impulses — no fluid sim
- ✅ **Audio event hooks** — a named-event bus (`stone_scrape`, `heavy_swing`,
  `shield_break`, `wall_crush`, `enemy_launch`, `chain_impact`, `cavalry_charge`,
  `banner_down`, `water_splash`, `water_wheel_creak`, `stone_flow_gain`, …) wired at
  every impact, ready for real sounds to drop in
- ✅ **Musou crowd combat**: a **spin / tornado** attack (hold Shift / middle-mouse) that
  whirls the stone and launches the whole crowd outward, a **KO counter** with milestones
  (`RAMPAGE!` … `ONE-MAN ARMY!`), an endless **reinforcement horde**, telegraphed
  **cavalry charges**, and a **war cart** that plows the field and **flips into launchable
  debris** — all chargers can be broken mid-charge with a timed hit
- ✅ Controllable Arthur with **momentum-based movement** + **health** and i-frames
- ✅ The **stone-sword**, drawn correctly: Arthur grips the **sword handle**; the blade
  runs *through* a heavy **stone head** swung like a hammer
- ✅ **Drag-to-swing control** (physics-sandbox feel): the head **follows the cursor with
  lag**, and to attack you **hold + drag** the mouse around Arthur — drag clockwise → swing
  clockwise. No attack button, no charge bar; damage comes purely from the head's **real
  speed** (slow drag pushes, hard whip launches). Plus an **overhead slam** (right-click)
- ✅ **Passive physical presence** — the resting stone *blocks and shoves* enemies/props
- ✅ **Enemy AI**: soldiers approach, keep shields toward you, land **telegraphed** attacks,
  and **stagger** — but go limp the instant they're launched, so your strength always wins
- ✅ **Enemy types** that play differently: **Light Soldier** (rush, flies far), **Shield
  Soldier** (front block + bash + `SHIELD BREAK` on a strong hit), **Spearman** (spacing +
  thrust), **Heavy Guard** (slow, hard to stagger), **Banner Bearer** (morale; on death the
  line panics)
- ✅ **Battlefield**: a **shield-wall** to break, a spear line, a flanking charge group,
  heavy anchors, a banner, **mud** that drags charges, funnel **fences**, and launchable props
- ✅ **Objective** — *Break the Shield Wall* — with a win/lose banner
- ✅ Momentum-based **impact**, **wall crush**, **bowling**, the **Stone Flow** combo, floating
  **hit labels**, defeat fades, and **shake** + **hit-stop** scaled to the impact
- ✅ The v0.3 **sandbox arena** (pillar, pressure-plate puzzle) is still there as `Arena.tscn`

What it is **not** yet: cavalry and the war cart are **designed in [`ROADMAP.md`](ROADMAP.md)**
but not built; the battlefield wants a real balance pass; no audio, no final art.

---

## Controls

| Input                          | Action                                          |
| ------------------------------ | ----------------------------------------------- |
| `W` `A` `S` `D` / Arrow keys   | Move (with weight + momentum)                   |
| Mouse                          | The heavy head **follows the cursor with lag** — it never snaps. Slow contact just pushes/blocks |
| **Hold** `Space` / Left Mouse **+ drag** | **Swing** — drag the mouse *around* Arthur to whip the head: drag **clockwise → swing clockwise**, counter-clockwise the other way. Faster drag = more speed = more damage |
| **Right Mouse Button**         | **Overhead slam** — a committed smash with a shockwave |
| **`Shift`** / **Middle Mouse** (hold) | **Spin / tornado** — whirl the stone, launching the whole crowd outward. Drains stamina fast |
| `R`                            | Reset                                           |

There's no attack button and no charge bar — you **physically drag and swing** the
heavy stone, and damage comes straight from how fast it's actually moving (a plain
click does nothing; a real whip launches). Full notes and the design reasoning:
[`docs/CONTROLS.md`](docs/CONTROLS.md).

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
│   ├── Battlefield.tscn   #   MAIN scene: shield wall, formations, terrain, objective, HUD
│   ├── Arena.tscn         #   v0.3 sandbox: walls, pressure-plate puzzle, passive dummies
│   ├── Arthur.tscn        #   player body + stone weapon (hitbox + stone body) + camera
│   ├── TargetDummy.tscn   #   passive Dummy (the Enemy script, AI off)
│   ├── LightSoldier.tscn  #   rush + quick melee, flies far (bowling ball)
│   ├── ShieldSoldier.tscn #   front block + bash + SHIELD BREAK; flank or crush it
│   ├── Spearman.tscn      #   holds distance, telegraphed thrust
│   ├── HeavyGuard.tscn    #   slow, high-mass, hard to stagger — moving anchor
│   ├── BannerBearer.tscn  #   support; on death nearby enemies panic
│   ├── Cavalry.tscn       #   telegraphed mounted charger (Cavalry.gd extends Enemy)
│   ├── WarCart.tscn       #   heavy charging mass; flips into debris (WarCart.gd extends Cavalry)
│   ├── Rock.tscn / Crate.tscn      #   launchable props (same script)
│   ├── PressurePlate.tscn #   puzzle plate + gate (Arena)
│   ├── Shockwave.tscn / FloatingText.tscn   #   spawned at runtime
│   └── Hud.tscn           #   stamina + weapon power + Stone Flow + health + objective
├── scripts/               # GDScript — one responsibility per file
│   ├── Impact.gd          #   AUTOLOAD: impact tuning + scoring formula + Stone Flow + feedback
│   ├── Arthur.gd          #   movement, stamina, health, swing lunge, hit-stop, signal routing
│   ├── StoneWeapon.gd     #   the momentum swing (pendulum head) + slam + hitbox + stone body
│   ├── Enemy.gd           #   rigid-body enemy + AI (approach/attack/stagger) + block/break, bowling
│   ├── Battlefield.gd     #   battlefield stage: AI on, terrain, objective, win/lose
│   ├── Rock.gd            #   rigid-body prop/projectile (rock or crate)
│   ├── Shockwave.gd       #   slam radial impulse + fading visual
│   ├── PressurePlate.gd   #   plate → gate puzzle
│   ├── FloatingText.gd    #   rising/fading hit label
│   ├── GameCamera.gd      #   follow + shake
│   ├── Hud.gd             #   HUD wiring
│   └── Arena.gd           #   v0.3 sandbox floor/walls, HUD binding, reset
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
