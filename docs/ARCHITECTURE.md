# Architecture

A guided tour of how the prototype is wired. It's still small — eight short
scripts and a handful of scenes — but it now models real top-down physics.

## Scene tree

```
Arena (Node2D, Arena.gd)
├── Walls (StaticBody2D, layer "world")
│   ├── Top / Bottom / Left / Right (CollisionShape2D)   ← arena boundary
├── Arthur (CharacterBody2D, Arthur.gd, layer "arthur")  ← instance of Arthur.tscn
│   ├── CollisionShape2D
│   ├── StoneWeapon (Node2D, StoneWeapon.gd)             ← swing + slam, drives the head
│   │   ├── StoneBody (AnimatableBody2D, layer "weapon") ← passive presence: blocks/shoves
│   │   │   └── CollisionShape2D                          ← the stone, follows the head
│   │   └── Hitbox (Area2D)                              ← attack detection, follows the head
│   │       └── CollisionShape2D
│   └── Camera2D (GameCamera.gd)                          ← follow + shake
├── TargetDummy ×4 (RigidBody2D, TargetDummy.gd, "enemies")
├── Rock ×2 (RigidBody2D, Rock.gd, "props")              ← launchable
└── Hud (CanvasLayer, Hud.gd)

spawned at runtime by a slam:
  Shockwave (Node2D, Shockwave.gd)  ← radial impulse + visual, frees itself
  Rock (debris)                     ← dropped at the impact point
```

`Arena.tscn` is the **main scene** (set in `project.godot`). Spawned nodes are
added to `get_tree().current_scene`.

## Responsibilities (one job per script)

| Script           | Owns                                                                 |
| ---------------- | ------------------------------------------------------------------- |
| `Arthur.gd`      | Body: momentum movement, stamina, slam input, hit-stop, routing weapon → camera/HUD |
| `StoneWeapon.gd` | The visual, the swing + slam state machine, charge, the hitbox + the passive stone body, dealing impulses |
| `TargetDummy.gd` | A `RigidBody2D` enemy: impulse knockback, stun state, hit counter   |
| `Rock.gd`        | A `RigidBody2D` prop/projectile: launches when hit, tumbles         |
| `Shockwave.gd`   | The slam burst: radial impulse + stun on spawn, then a fading ring/cracks/dust |
| `GameCamera.gd`  | Decaying screen shake (follows Arthur via parenting + the Camera2D's position smoothing) |
| `Hud.gd`         | Drawing the stamina bar + weapon-state text from signals            |
| `Arena.gd`       | Floor/grid visuals, binding the HUD to Arthur, the reset hotkey     |

## The weapon state machine (`StoneWeapon.gd`)

The heart of the prototype. One enum, eight states, driven in `_physics_process`.
Every state ultimately sets two values — the head's **angle** (`aim + swing_offset`)
and its **distance** (`_head_dist`) — and the hitbox + stone body are moved to that
head each frame, so what you see is exactly what hits and shoves.

Swing branch:
```
READY ──press_attack()──► WINDUP ──(min wind-up paid + release, or full charge)──► ACTIVE
  ▲                                                                                  │
  └──────────────────────────── RECOVERY ◄───────────────────────────(active_time)──┘
```
Slam branch:
```
READY ──start_slam()──► SLAM_RAISE ──► SLAM_HOLD ──► SLAM_DROP ──(impact)──► SLAM_RECOVER ──► READY
```

- **WINDUP** — head hauls back, `charge` ramps `0 → 1`. Release after the minimum
  wind-up (or full charge) fires. Movement throttled to 35%.
- **ACTIVE** — head snaps through the arc over `active_time`; the hitbox is live and
  each overlapping body is struck **once**. The solid stone body steps aside here so
  the designed impulse (not the sweep) does the work.
- **RECOVERY** — head eases home over a charge-scaled duration. Movement 22% — the
  punish window.
- **SLAM_RAISE → HOLD → DROP** — the head rears back and "lifts" (it grows + casts a
  shadow), pauses, then smashes out to `slam_reach`. At impact it spawns a
  `Shockwave` + a debris `Rock`. Movement is throttled hard throughout (14–30%).
- **SLAM_RECOVER** — long, exposed return to **READY**.

If stamina can't cover a swing at fire time, the weapon emits `too_tired` and
stumbles **straight into recovery** without enabling the hit. A slam checks stamina
up front. Overcommitting is its own punishment.

## Physics & collision layers

Everything pushable is a `RigidBody2D` with `gravity_scale = 0` and `linear_damp`
for top-down friction, so they collide with walls, each other, and the stone for
free. Named layers (in `project.godot`) keep the interactions legible:

| Body            | Type             | layer    | collides with                |
| --------------- | ---------------- | -------- | ---------------------------- |
| Walls           | StaticBody2D     | world    | (scanned by others)          |
| Arthur          | CharacterBody2D  | arthur   | world, enemies, props        |
| Stone head      | AnimatableBody2D | weapon   | enemies, props (not Arthur)  |
| Enemy (dummy)   | RigidBody2D      | enemies  | everything                   |
| Rock (prop)     | RigidBody2D      | props    | everything                   |

**Passive presence.** The stone head is an `AnimatableBody2D`. Each physics frame
the weapon moves it (and the Area2D hitbox) to the visible head position; because
it's a solid kinematic body it blocks rigid bodies and shoves them as it sweeps —
so the weapon has weight even when you're only aiming. During the **ACTIVE** swing
and **SLAM_DROP** its collision shape is disabled (`_set_solid`) so the chaotic
fast-sweep push gives way to a clean, designed impulse.

## How an attack lands

```
StoneWeapon (ACTIVE)
  └─ hitbox.get_overlapping_bodies()           # detects enemies + props (mask)
       └─ for each body with apply_knockback(), not already hit this swing:
            body.apply_knockback(dir, impulse)  # apply_central_impulse; scales with charge
            body.stun(t)
            emit hit_landed(shake, count) ─► Arthur ─► camera shake + hit-stop

StoneWeapon (slam impact)
  └─ spawn Shockwave at the slam point
       └─ for each nearby target/prop: apply_knockback(out, impulse·falloff) + stun
  └─ spawn a debris Rock
  └─ emit hit_landed(big_shake) ─► strong shake + hit-stop
```

Bodies opt in by implementing `apply_knockback(dir, strength)` (enemies and rocks
both do), so the weapon never needs to know what it hit — that's the seam future
enemies, destructibles, and switches plug into.

## Signals (no polling, loose coupling)

`StoneWeapon` announces what it's doing; nobody reaches into it.

| Signal (`StoneWeapon`) | Carries                | Consumed by                          |
| ---------------------- | ---------------------- | ------------------------------------ |
| `state_changed(state)` | new state enum         | `Arthur` → re-emits a human label    |
| `charge_changed(c)`    | charge `0..1`          | `Arthur` → HUD wind-up %             |
| `hit_landed(shake, n)` | shake strength, count  | `Arthur` → camera shake              |
| `too_tired()`          | —                      | `Arthur` → `exhausted` → HUD flash   |

`Arthur` re-broadcasts to the HUD (`stamina_changed`, `weapon_state_changed`,
`exhausted`). `Arena._ready()` calls `hud.bind(arthur)` to connect them, so the
HUD has no hard path into gameplay nodes.

## Why a few references are deliberately untyped

`StoneWeapon` talks to its parent Arthur and to target bodies through *dynamic*
calls (`_arthur.try_spend_stamina(...)`, `body.call("apply_knockback", …)`).
That's intentional: it keeps the weapon decoupled from concrete classes and
sidesteps GDScript cyclic-type issues, at the cost of a little static checking.
For a prototype this seam is a feature — it's exactly where new content slots in.

## Coordinate / drawing notes

- All character art is drawn in code (`_draw`) with placeholder shapes — no image
  assets to import, nothing to go stale.
- `StoneWeapon` draws its head along local **+X**; the node's `rotation`
  (`aim_angle + swing_offset`) is what sweeps it. The hitbox is parented to the
  same node, so it sweeps in lockstep with the visual — what you see is what hits.
