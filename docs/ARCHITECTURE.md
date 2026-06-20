# Architecture

A guided tour of how the prototype is wired. The whole thing is six small
scripts and four scenes — small enough to hold in your head.

## Scene tree

```
Arena (Node2D, Arena.gd)
├── Walls (StaticBody2D)
│   ├── Top / Bottom / Left / Right (CollisionShape2D)   ← arena boundary
├── Arthur (CharacterBody2D, Arthur.gd)                  ← instance of Arthur.tscn
│   ├── CollisionShape2D
│   ├── StoneWeapon (Node2D, StoneWeapon.gd)             ← the swing + hitbox
│   │   └── Hitbox (Area2D)
│   │       └── CollisionShape2D                          ← sweeps with the head
│   └── Camera2D (GameCamera.gd)                          ← follow + shake
├── TargetDummy ×4 (CharacterBody2D, TargetDummy.gd)     ← instances of TargetDummy.tscn
└── Hud (CanvasLayer, Hud.gd)                            ← instance of Hud.tscn
```

`Arena.tscn` is the **main scene** (set in `project.godot`).

## Responsibilities (one job per script)

| Script           | Owns                                                                 |
| ---------------- | ------------------------------------------------------------------- |
| `Arthur.gd`      | Body: momentum movement, the stamina pool, routing weapon → camera/HUD |
| `StoneWeapon.gd` | The swing state machine, charge, the sweeping hitbox, knockback dealing |
| `TargetDummy.gd` | Receiving knockback, sliding to a stop, wall rebound, hit counter   |
| `GameCamera.gd`  | Decaying screen shake (it follows Arthur by being parented to him, with the Camera2D's own position smoothing) |
| `Hud.gd`         | Drawing the stamina bar + weapon-state text from signals            |
| `Arena.gd`       | Floor/grid visuals, binding the HUD to Arthur, the reset hotkey     |

## The swing state machine (`StoneWeapon.gd`)

The heart of the prototype. One enum, four states, driven in `_physics_process`:

```
READY ──press_attack()──► WINDUP ──(min wind-up paid + release, or full charge)──► ACTIVE
  ▲                                                                                  │
  └──────────────────────────── RECOVERY ◄───────────────────────────(active_time)──┘
```

- **READY** — idle; aim tracks the mouse quickly. The head rests along the aim.
- **WINDUP** — the head hauls back and `charge` ramps `0 → 1` over `charge_time`.
  Releasing after the minimum wind-up (or hitting full charge) fires the swing.
  Movement is throttled to 35%.
- **ACTIVE** — the head snaps through the arc (ease-out) over `active_time`. The
  hitbox is live; each overlapping target is struck **once** (tracked by instance
  id). Movement 60% — you're carried by the swing.
- **RECOVERY** — the head eases back to rest over a charge-scaled duration.
  Movement 22% — this is the punish window. Then back to **READY**.

If stamina can't cover the swing at fire time, the weapon emits `too_tired` and
stumbles **straight into recovery** without enabling the hit. Overcommitting is
its own punishment.

## How damage/knockback flows

```
StoneWeapon (ACTIVE)
  └─ hitbox.get_overlapping_bodies()
       └─ for each body in group "targets", not already hit this swing:
            body.apply_knockback(dir, force)   # dir = away from Arthur; force scales with charge
            emit hit_landed(shake, count)
                 └─ Arthur._on_weapon_hit → camera.add_shake(shake)
```

Targets opt in by joining the `targets` group (in `TargetDummy._ready`), so the
weapon never needs to know what a "dummy" is — anything that joins the group and
implements `apply_knockback(dir, strength)` can be hit. That's the seam future
enemies and destructibles will plug into.

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
