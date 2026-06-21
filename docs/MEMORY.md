# Project memory — Arthur Stone Weapon System

Compact, durable notes so a session can get oriented fast. Start with
[`../CLAUDE.md`](../CLAUDE.md); this file is the map + system list.

## Concept

Arthur lifted the whole **stone** instead of the sword — a giant heavy physics weapon.
Overwhelming strength, terrible control. The fun is the tension: power vs. weight.
Top-down 2D, Godot 4, placeholder art, browser-playable.

## Core gameplay loop

Drag the heavy stone (it follows the cursor with lag); **hold + drag** to swing — damage
is **real head speed**, not a button press. Push/block when slow, launch when fast, crush
into walls. Build **Stone Flow** combo on good hits. Slam (R-click), spin/tornado (Shift).
Manage **stamina**. On the battlefield: hold a line against waves, protect allies, knock
enemies into terrain (river, mill wheel), break formations, defeat the officer.

## Current level: Hold the Ford

A river crossing. Five escalating waves (raiders → shields → spears → cavalry+cart →
officer) march to cross toward an **allied banner**; **allied footmen** fight at your
side; letting too many raiders past the defence line (**breaches**) loses the ford.
Terrain is a weapon: river current, a **water wheel** that bats bodies, a **bridge** that
can be collapsed, drifting **logs**.

## Implemented systems (where the code is)

- **Combat brain** — `scripts/Impact.gd` (autoload): one scoring formula
  (`speed × mass × charge × angle × collision × combo`), Stone Flow combo, KO counter,
  wall-crush raycast (`cushion`), floating labels, shared collision debounce. All hits
  (swing, slam, prop, bowling) resolve here.
- **Player** — `scripts/Arthur.gd` (CharacterBody2D): momentum movement, stamina, health,
  i-frames, hit-stop, routes weapon → camera/HUD. `scripts/StoneWeapon.gd`: drag-to-swing
  pendulum, slam + spin state machines, the hitbox + passive solid stone body.
- **Enemies** — `scripts/Enemy.gd` is the **shared base** (a config-driven `RigidBody2D`):
  health, mass, stun, knockback, shield block/break, morale, defeat, bowling, **and** the
  team/AI (march-to-goal + attack-foe, flanking, separation, retarget). Each type is just
  a `.tscn` of it: `LightSoldier`, `ShieldSoldier`, `Spearman`, `HeavyGuard`,
  `BannerBearer`, `Ally`. `Cavalry.gd` (+`WarCart.gd`) *extend* it with a charge brain.
- **Terrain** — `scripts/terrain/TerrainZone.gd`: a reusable placeable `Area2D` rule
  (slow / current / drown-light / dangerous→avoid). The ford river + mud are instances.
- **Spawning** — `scripts/spawning/Spawner.gd`: shared helper to spawn a group of scenes
  across a lane. Used by the wave + ally spawns in `Battlefield.gd`.
- **Objectives** — `scripts/objectives/` (`Objective` base + `RepelWaves` / `DefeatOfficer`
  / `HoldLine`) + `scripts/systems/ObjectiveManager.gd`: a level composes its win/lose by
  registering objectives (completable ones gate the win; constraints only gate losing).
- **Level** — `scripts/Battlefield.gd`: assembles the ford (terrain zones, fences, banner,
  goal), runs the 5-wave manager + log/bridge mechanics, and ticks the ObjectiveManager
  (win/lose is no longer hand-coded here).
- **Hazards/props** — `WaterWheel.gd` (Area2D spinner), `Rock.gd` (rock/crate), `Log.gd`,
  `Shockwave.gd` (slam burst), `PressurePlate.gd`.
- **Audio** — `Audio.gd` (event bus, `Audio.play(name, pos)`), `SoundBank.gd` (synthesises
  a procedural sound per event). Twelve named events fired at impact sites.
- **HUD/camera/text** — `Hud.gd`, `GameCamera.gd`, `FloatingText.gd`.

## Folder map

```
CLAUDE.md, README, ROADMAP, CHANGELOG, CONTRIBUTING
docs/        MEMORY, ARCHITECTURE, BATCH_PLAN, CONCEPT, DESIGN_GOALS, CONTROLS, BUILD
devlog/      0001..0007 (dated narrative)
scripts/     actors + systems (flat) + terrain/ + spawning/
scenes/      actor/prop/level scenes (flat) + terrain/
tests/       headless *_test.gd + *.tscn (7 gate CI)
.github/     validate.yml (tests), pages.yml (web deploy)
```

Existing actor/prop scripts stay flat in `scripts/`; **new reusable modules** go in
`scripts/<module>/` (e.g. `terrain/`, `spawning/`). Don't relocate working files (it
breaks `.tscn`/`.uid` references and risks the browser build).

## Design rules (don't violate)

- Build once, reuse many. No copy-paste enemy/terrain/level logic.
- One shared damage/force system (`Impact`) — don't add per-object damage.
- Config + placement over new code. New enemy = a `.tscn`; new river = a `TerrainZone`.
- Use Godot physics; don't hand-roll. Don't over-engineer.
- Preserve the browser build; keep the 7 tests green.

## Known TODOs / next batches

- Extract `formations/` (ShieldWall etc.) as reusable placeable scenes; today the garrison
  is hand-placed in `Battlefield.tscn` and waves spawn flat lists via `Spawner`.
- An `abilities/` data system (slash / bash / thrust / charge / aura); today attacks are
  branches in `Enemy.gd`.
- A full `WaveSpawner` resource (waves still live in `Battlefield.gd`) + an `EnemyPool`.
- KO + time **score screen**; a balance pass; the challenge rooms. See
  [`../ROADMAP.md`](../ROADMAP.md).
