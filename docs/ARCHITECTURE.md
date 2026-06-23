# Architecture

A guided tour of how the prototype is wired. It is built from small **reusable
modules** + one **impact/combo brain**, so a new enemy is a `.tscn`, a new river is a
placed `TerrainZone`, and a new level is a scene that assembles modules. See
[`MEMORY.md`](MEMORY.md) for the quick map and [`BATCH_PLAN.md`](BATCH_PLAN.md) for the
refactor status. `Battlefield.tscn` is the **main scene** (the "Hold the Ford" level);
`Arena.tscn` is the older sandbox.

## Scene tree (Battlefield — the current level)

```
(autoloads) Impact (Impact.gd)      ← impact tuning + scoring + Stone Flow + feedback
            Audio  (Audio.gd)       ← named sound-event bus (signal sfx)
            SoundBank (SoundBank.gd)← synthesises a procedural sound per Audio event

Battlefield (Node2D, Battlefield.gd)                     ← the LEVEL: assembles modules + level rules
├── Walls (StaticBody2D, "world")                        ← boundary + fences (built from FENCES)
├── Arthur (CharacterBody2D, Arthur.gd, "arthur")
│   ├── StoneWeapon (Node2D, StoneWeapon.gd)             ← drag-to-swing + slam + spin; hitbox + solid stone
│   └── Camera2D (GameCamera.gd)                          ← follow + shake
├── ShieldWall / SpearLine / Guards / Cavalry / … (Enemy.gd configs)  ← the pre-placed garrison
├── WaterWheel (Area2D, WaterWheel.gd)                   ← spinning hazard: bats overlapping bodies
├── Props (RigidBody2D, Rock.gd)                         ← Rock + Crate, launchable
└── Hud (CanvasLayer, Hud.gd)

built/spawned at runtime by Battlefield:
  TerrainZone (Area2D, terrain/TerrainZone.gd)  ← river + mud RULES, over the drawn rects
  ford_goal / crossing (Node2D markers)         ← what raiders march at / the bridge they aim for
  Ally (Enemy.gd, team="ally")  · wave enemies (via Spawner)  · Log (Log.gd) hazards
  Shockwave · debris Rock · FloatingText        ← self-freeing one-shots
```

`Impact` is an **autoload** (see `project.godot` `[autoload]`), so any node reaches it as
`Impact`; likewise `Audio`/`SoundBank`. Spawned nodes are added to the current scene.

## Responsibilities (one job per script)

| Script             | Owns                                                                 |
| ------------------ | ------------------------------------------------------------------- |
| `Impact.gd`        | **The one tuning hub**: all impact numbers, the scoring formula, the Stone Flow combo, the wall-crush raycast, and the floating-label / shake feedback |
| `Arthur.gd`        | Body: momentum movement, stamina, slam input, hit-stop, Stone-Flow mobility, routing weapon → camera/HUD |
| `StoneWeapon.gd`   | The visual, the swing + slam state machine, charge, the hitbox + the passive stone body; runs each swing hit through `Impact` |
| `Enemy.gd`         | A configurable `RigidBody2D` enemy: take-hit / knockback / shield block / stun / defeat, and **bowling** (scores when flung into another enemy) |
| `Rock.gd`          | A `RigidBody2D` prop/projectile (rock or crate): launches when hit, and scores when it hits an enemy |
| `Shockwave.gd`     | The slam burst: radial impulse + damage + stun on `detonate()`, then a fading ring/cracks/dust |
| `PressurePlate.gd` | A weight-it-to-open-the-gate puzzle (plate Area2D + gate StaticBody2D) |
| `FloatingText.gd`  | A rising, fading hit label (drawn in code)                          |
| `GameCamera.gd`    | Decaying screen shake                                                |
| `Hud.gd`           | Stamina/health bars + weapon-state + Stone Flow + objective/banner/KO, from signals |
| `Battlefield.gd`   | The **level**: assembles terrain zones + spawns, runs the 5-wave script, breach lose / wave win, bridge collapse, log hazards |
| `Arena.gd`         | The older sandbox: floor/grid, interior walls, HUD binding, reset hotkey |

### Reusable modules (build once, reuse many)

| Module | Reused for |
| ------ | ---------- |
| `Enemy.gd` (de-facto **EnemyBase**) | every enemy *type* is a `.tscn` config of it (Light/Shield/Spear/Heavy/Banner/Ally); Cavalry/WarCart **extend** it. Owns health, mass, stun, knockback, shield, morale, defeat, bowling, **and** the team/AI (march-to-goal + attack-foe, flank, separation, retarget, stuck-recovery, terrain-avoidance). Add an enemy by tuning exports — no new code. |
| `terrain/TerrainZone.gd` | every river/mud/ford. A placeable `Area2D` rule: `drag` (slow), `current` (push), `dangerous` (NPCs route around it → chokepoints), `drowns_light` (knock a light unit in → it's removed). Applies forces as **impulses** so a swing's knockback / the wheel's bat still compose. Drop another instance → same rule. |
| `spawning/Spawner.gd` | every spawn site. Static `spawn()/spawn_count()` place a group of scenes across a lane (used by the waves and the allied line). |
| `ai/Steering.gd` | every unit's wall avoidance. Stateless whisker raycasts vs the **world** layer return an adjusted heading that flows *around* solid geometry (and a "most-open direction" for unsticking). `Enemy.gd` pipes its march + approach direction through it; works in any level for free. |
| `abilities/Ability.gd` + `AbilityLibrary.gd` | every attack. A data-driven move (timings/ranges/damage + one `execute`) and a registry of them. A unit's `moves` list is picked-by-range each attack; a new move is a table row, a new fighter is a `.tscn` that lists ids. Empty `moves` → a synth move from the legacy `attack_*` exports (back-compat). |
| `Audio.gd` + `SoundBank.gd` | every sound. `Audio.play("event", pos)` fires one bus signal; `SoundBank` synthesises a procedural voice per event. |

**How to add things** (see also [`MEMORY.md`](MEMORY.md)): a **new enemy** = a `.tscn`
using `Enemy.gd`; a **new terrain rule** = a placed `TerrainZone` (tune its exports) or a
new rule branch; a **new level** = a `Node2D` scene that builds terrain zones + a goal +
spawns, like `Battlefield.gd`. Future batches (`formations/`, `objectives/`,
`abilities/`) are listed in [`BATCH_PLAN.md`](BATCH_PLAN.md).

## The impact pipeline (`Impact.gd`)

Every hit in the game — a swing, a slam, a thrown rock/crate, an enemy bowled
into another — resolves through **one** function so the whole game speaks one
language of force:

```
score = speed_factor × mass_factor × charge × angle × collision_bonus × combo
```

- **speed** — the swing's *measured* head speed (px/s), or a projectile's / bowled
  enemy's collision speed. Slow touch → low; fast sweep → high.
- **mass** — the attacker's effective mass (the stone is huge, a rock less, a
  flung enemy little). Note: knockback is applied as an **impulse**, so the
  *receiver's* `mass` decides how far it actually flies — a light soldier sails, a
  heavy guard barely moves.
- **charge** — 0→1 for a held swing; 0 for collisions.
- **angle** — how head-on the hit is.
- **collision_bonus** — kind-specific (bowling/rock/slam) **plus a wall-crush
  term**: a short raycast (`cushion()`) checks for a wall right behind the target;
  if it can't fly away, the bonus spikes.
- **combo** — `Impact.force_mult()`, driven by the current Stone Flow stacks.

`resolve_hit(ctx)` returns a Dictionary — `knockback, damage, stun, shake, label,
color, flow_gain` — that the caller applies and displays. `collide()` is the
one-call version for non-weapon hits (props, bowling): it resolves, applies to the
target, pops the label, feeds Stone Flow, and requests a shake.

### Stone Flow (the combo)

`Impact` also holds the combo state: `flow` (0–100) → `stacks` (0–5). `add_flow()`
on good hits; it **decays** after a grace period and **breaks** on `note_miss()`
(a whiffed swing) or `note_exhausted()` (stamina ran dry). Stacks return *small*
multipliers — `charge_speed_mult / move_mult / force_mult` — read
by `StoneWeapon` and `Arthur`. They're deliberately tiny: buffed Arthur is still
hauling a rock. The HUD listens to `flow_changed`.

## Physics & collision layers

Everything pushable is a `RigidBody2D` with `gravity_scale = 0` and `linear_damp`
for top-down friction. Named layers (in `project.godot`) keep it legible:

| Body            | Type             | layer    | collides with                |
| --------------- | ---------------- | -------- | ---------------------------- |
| Walls           | StaticBody2D     | world    | (scanned by others)          |
| Arthur          | CharacterBody2D  | arthur   | world, enemies, props        |
| Stone head      | AnimatableBody2D | weapon   | enemies, props (not Arthur)  |
| Enemy           | RigidBody2D      | enemies  | everything                   |
| Rock / Crate    | RigidBody2D      | props    | everything                   |

**Passive presence.** The stone head is an `AnimatableBody2D`; each physics frame
the weapon moves it (and the hitbox) to the visible head, so it blocks and shoves
rigid bodies as it sweeps. During the **ACTIVE** swing and **SLAM_DROP** its
collider is disabled (`_set_solid`) so the chaotic fast-sweep push gives way to a
clean, designed impulse.

**Bowling** uses `contact_monitor`: enemies and props report `body_entered`, and a
fast collision with another enemy is scored through `Impact.collide()`. A
per-target debounce + a "only the faster body initiates" rule keeps one touch =
one hit.

## How an attack lands

```
StoneWeapon (ACTIVE)
  └─ hitbox.get_overlapping_bodies()              # enemies + props (by mask)
       └─ for each body not already hit this swing:
            r = Impact.resolve_hit(speed, charge, angle, wall-crush pin, shield)
            enemy.apply_hit(dir, r.knockback, r.stun, r.damage)  # or prop.apply_knockback
            Impact.popup(r.label) ; Impact.add_flow(r.flow_gain)
            emit hit_landed(r.shake) ─► Arthur ─► camera shake + hit-stop
  └─ a swing that hits nothing → Impact.note_miss()  # the combo bleeds

StoneWeapon (slam impact)
  └─ spawn Shockwave.detonate() → radial Impact-scored hits + stun + flow
  └─ spawn a debris Rock ; big shake + hit-stop

Enemy / Rock (flung into an enemy)
  └─ body_entered → Impact.collide(...) → score + apply + label + flow + shake
```

Bodies opt in by implementing `apply_hit` / `apply_knockback`, so neither the
weapon nor `Impact` needs to know concrete classes — that seam is where future
enemies, destructibles, and switches plug in.

## Signals (no polling, loose coupling)

`StoneWeapon` announces what it's doing; `Impact` announces combo + ambient hits.

| Signal                          | Carries               | Consumed by                       |
| ------------------------------- | --------------------- | --------------------------------- |
| `StoneWeapon.state_changed`     | new state enum        | `Arthur` → human label            |
| `StoneWeapon.charge_changed`    | charge `0..1`         | `Arthur` → HUD wind-up %          |
| `StoneWeapon.hit_landed`        | shake, count          | `Arthur` → camera shake + hit-stop |
| `StoneWeapon.too_tired`         | —                     | `Arthur` → `exhausted` + `Impact.note_exhausted` |
| `Impact.flow_changed`           | flow, stacks, mode    | `Hud` → Stone Flow meter          |
| `Impact.impact_fx`              | shake strength        | `Arthur` → shake + hit-stop for prop/bowling hits |

`Arena._ready()` calls `hud.bind(arthur)` to connect the HUD, so it has no hard
path into gameplay nodes.

## Why a few references are deliberately untyped / dynamic

`StoneWeapon` and `Impact` talk to bodies through duck-typed calls
(`body.apply_hit(...)`, `body.has_method("block_factor")`). That's intentional: it
keeps them decoupled from concrete classes, so new content slots in without
touching the core. (GDScript's `:=` can't infer through these dynamic calls, so
those locals are explicitly typed — see the `var dir: Vector2 = …` spots.)

## Coordinate / drawing notes

- All art is drawn in code (`_draw`) with placeholder shapes — nothing to import,
  nothing to go stale.
- `StoneWeapon` draws its head along local **+X**; the node's `rotation` sweeps it,
  and the hitbox + stone body are parented to the same node — what you see is what
  hits and shoves.
- Interior walls live as `Rect2`s in `Arena.WALLS`: the same data becomes both the
  collision shapes and the drawn rectangles, so they can't drift apart.
