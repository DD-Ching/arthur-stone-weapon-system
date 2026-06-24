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
| 7 | **Formation module** — `Formation` (front/support/commander ranks) + `ShieldWall` / `SpearPhalanx` / `OfficerGuard` scenes; the waves arrive as formations | ✅ v0.11.0 |
| 6 | **Ability module** — slash / shield bash / spear thrust / charge / aura as data (wind-up/active/recover/cooldown/hit-area) | ✅ v0.14 |
| 9 | **Wave/spawn system** — a full `WaveSpawner` resource (timed waves, lanes, escalation) + optional `EnemyPool` for a bigger crowd | ✅ (the 5 Three-Kingdoms maps are `WaveSpawner`-driven via `BattleMap`; `EnemyPool` still ⬜) |
| 10 | **Level data structure** — assemble levels from terrain + spawns + formations + objectives + props + params | ✅ (`scripts/maps/BattleMap.gd` — a new map is a thin `extends BattleMap`; 5 maps + the challenge rooms ship on it) |

A **parallel content batch** (12 agents) then landed *additively* on these modules — no
engine rewrite: four challenge rooms (`scripts/rooms/`), a `ChargeGroup` formation, a
`ProtectBanner` objective, placeable `scenes/terrain/` zones (River/Mud/Fence), a KO+time
score screen, the `WaveSpawner`+`Wave` resources, three new raider variants (Archer/Brute/
Outrider), and battlefield-readability draw enrichments. It added 11 new headless tests (the
CI suite was then 23).

## 三國無雙 / Dynasty-Warriors batch (v0.16, shipped)

A second 12-agent batch (a foundation + 12 units) landed *additively* on the shared modules —
no engine rewrite, browser build still single-threaded:
- **Foundation** — `scripts/maps/BattleMap.gd`, a reusable battle-map base (a new map is a thin
  `extends BattleMap`: it wires Arthur + HUD + score screen + boss-healthbar, drives a
  `WaveSpawner`, runs an `ObjectiveManager`, tracks KO/elapsed/breaches, resolves win/lose).
  `Enemy.gd` gained `faction` + `is_general` + `faction_color()`; a `musou` input (Q).
- **5 Three-Kingdoms maps** (`scenes/maps/` + `scripts/maps/`): Hu Lao Gate, Red Cliffs, Guandu,
  Changban, Yellow Turban — adding reusable `FireZone` (`scripts/hazards/`), `Base` +
  `CaptureBasesObjective`, and `SurviveObjective`.
- **Named generals** (`scripts/General.gd` + `scenes/generals/`), **5 new troop configs**
  (`scenes/troops/`), a **musou gauge + Q ultimate** (`Arthur.gd`/`Hud`), a **boss healthbar**
  (`scenes/ui/GeneralHealthbar.tscn`), faction-colour beautification, a **stage-select boot
  menu** (`scenes/ui/StageSelect.tscn`, now the main scene), and **decor props**
  (`scenes/decor/`).
- It added 12 new headless tests (the CI suite is now **36**).

## Conventions for the remaining batches

- New reusable modules live in `scripts/<module>/` + `scenes/<module>/`
  (`terrain/`, `spawning/`, later `formations/`, `objectives/`, `abilities/`).
- Keep existing actor/prop files where they are — relocating them rewrites every
  `.tscn`/`.uid` reference and risks the web build.
- Each batch: implement the smallest slice, keep the 36 headless tests green, run an
  adversarial review of the new code, then ship on `dev`→`main` with a tag.
