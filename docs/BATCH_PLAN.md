# Batch plan — modular battlefield framework

The refactor toward a reusable framework, split into independent batches so no single
change is huge. Status reflects what has actually shipped.

## Audit (the starting point)

Already modular (no rewrite needed):
- **`Enemy.gd` is the shared enemy base.** Light/Shield/Spear/Heavy/Banner/Ally are all
  `.tscn` configs of it; Cavalry/WarCart extend it. "≥2 enemies share base logic" was
  already true for all of them.
- **`Impact.gd`** is the one shared impact/scoring/knockback/combo system.
- **`Audio.gd` + `SoundBank.gd`** are the shared audio bus + synthesiser.

The genuine hard-coding/duplication targeted by the refactor:
- Terrain rules (river/mud/current) were `const`s + a per-body loop **inside
  `Battlefield.gd`** — a second river meant copy-paste. → **`TerrainZone`**.
- Two near-identical spawn loops (`_spawn_wave`, `_spawn_allies`). → **`Spawner`**.
- Movement marched to a goal but never avoided walls/water or recovered from stuck.

## Batches

| # | Batch | Status |
| - | ----- | ------ |
| 1 | **Audit + memory docs** — `CLAUDE.md`, `docs/MEMORY.md`, this file, refresh `ARCHITECTURE.md` | ✅ v0.9.0 |
| 2 | **Shared enemy base** — health/mass/stun/knockback/target/movement/defeat in one configurable script; ≥2 types use it | ✅ already (`Enemy.gd`; all 7 types) |
| 3 | **Reusable movement** — target seeking, stuck recovery, dangerous-terrain avoidance (prefer the bridge), resume after knockback/stun | ✅ v0.9.0 (in `Enemy.gd`) |
| 4 | **Reusable terrain rule** — `TerrainZone` (slow / current / drown-light / dangerous→avoid); the ford river + mud are instances | ✅ v0.9.0 |
| 5 | **Reusable spawner** — `Spawner` helper; the wave + ally spawns use it | ✅ v0.9.0 |
| 8 | **Objective module** — `RepelWaves` / `DefeatOfficer` / `HoldLine` + an `ObjectiveManager`; win/lose lifted out of `Battlefield.gd` | ✅ v0.10.0 |
| 7 | **Formation module** — `ShieldWall` / `SpearLine` / `ChargeGroup` / `ProtectedBanner` as placeable, configurable scenes | ⬜ next |
| 6 | **Ability module** — slash / shield bash / spear thrust / charge / aura as data (wind-up/active/recover/cooldown/hit-area) | ⬜ next |
| 9 | **Wave/spawn system** — a full `WaveSpawner` resource (timed waves, lanes, escalation) + optional `EnemyPool` for a bigger crowd | ⬜ next |
| 10 | **Level data structure** — assemble levels from terrain + spawns + formations + objectives + props + params | ⬜ next |

## Conventions for the remaining batches

- New reusable modules live in `scripts/<module>/` + `scenes/<module>/`
  (`terrain/`, `spawning/`, later `formations/`, `objectives/`, `abilities/`).
- Keep existing actor/prop files where they are — relocating them rewrites every
  `.tscn`/`.uid` reference and risks the web build.
- Each batch: implement the smallest slice, keep the 7 headless tests green, run an
  adversarial review of the new code, then ship on `dev`→`main` with a tag.
