# Architecture

A guided tour of how the prototype is wired. It's still small — a dozen short
scripts and a handful of scenes — but it now models real top-down physics with a
single impact + combo brain.

## Scene tree

```
(autoload) Impact (Node, Impact.gd)                      ← impact tuning + scoring + Stone Flow + feedback

Arena (Node2D, Arena.gd)
├── Walls (StaticBody2D, layer "world")
│   ├── Top / Bottom / Left / Right (CollisionShape2D)   ← boundary
│   └── (interior walls added at runtime from Arena.WALLS) ← pillar + corner pocket
├── Arthur (CharacterBody2D, Arthur.gd, layer "arthur")  ← instance of Arthur.tscn
│   ├── CollisionShape2D
│   ├── StoneWeapon (Node2D, StoneWeapon.gd)             ← swing + slam, drives the head
│   │   ├── StoneBody (AnimatableBody2D, layer "weapon") ← passive presence: blocks/shoves
│   │   │   └── CollisionShape2D                          ← the stone, follows the head
│   │   └── Hitbox (Area2D)                              ← attack detection, follows the head
│   │       └── CollisionShape2D
│   └── Camera2D (GameCamera.gd)                          ← follow + shake
├── Enemies (RigidBody2D, Enemy.gd, "enemies")           ← Dummy / Light / Shield / Heavy scenes
├── Props (RigidBody2D, Rock.gd, "props")                ← Rock + Crate, launchable
├── PressurePlate (Node2D, PressurePlate.gd)             ← plate (Area2D) + gate (StaticBody2D)
└── Hud (CanvasLayer, Hud.gd)

spawned at runtime:
  Shockwave   (Node2D, Shockwave.gd)   ← slam radial impulse + visual, frees itself
  Rock        (debris)                 ← dropped at a slam impact
  FloatingText(Node2D, FloatingText.gd)← a hit label, rises + fades, frees itself
```

`Arena.tscn` is the **main scene**; `Impact` is an **autoload** (see
`project.godot` `[autoload]`), so any node can reach it as `Impact`. Spawned
nodes are added to `get_tree().current_scene`.

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
| `Hud.gd`           | Stamina bar + weapon-state text + the Stone Flow meter, from signals |
| `Arena.gd`         | Floor/grid visuals, interior walls, HUD binding, `Impact.reset()`, reset hotkey |

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
