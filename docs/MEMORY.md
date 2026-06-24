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

## Levels: a stage select of battles

The game now **boots into a stage select** (`scenes/ui/StageSelect.tscn`) — a 三國無雙 battle
picker. **Hold the Ford** (below) is one of several: it sits alongside the 4 challenge rooms
and 5 Three-Kingdoms maps (Hu Lao Gate / Red Cliffs / Guandu / Changban / Yellow Turban),
each a self-contained level reusing the shared modules. See the 三國無雙 layer above.

### Hold the Ford

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
  `BannerBearer`, `Ally`. `Cavalry.gd` (+`WarCart.gd`) *extend* it with a charge brain. New
  raider archetypes are configs too: `Skirmisher` (javelin kiter), `Berserker` (leap pouncer),
  `Marauder` (pound brute), `Archer` (javelin ranged kiter), `Brute` (pound+bash mini-boss),
  `Outrider` (lunge+slash fast flanker).
- **Enemy navigation** — `scripts/ai/Steering.gd`: a stateless helper that whisker-raycasts the
  **world** layer so a unit flows *around* walls/fences (and unsticks toward the open side) in any
  level, no per-level wiring. `Enemy.gd` routes its march + approach direction through it.
- **Abilities** — `scripts/abilities/` (`Ability` + `AbilityLibrary` + `Javelin`): a data-driven
  move-set. A unit lists `moves` (ability ids: slash/thrust/bash/lunge/leap/javelin/pound); the
  brain picks one by range and runs its windup/strike/recover. Empty `moves` → a synth move from
  the legacy `attack_kind` exports, so old configs are unchanged.
- **Terrain** — `scripts/terrain/TerrainZone.gd`: a reusable placeable `Area2D` rule
  (slow / current / drown-light / dangerous→avoid). The ford river + mud are instances.
  `scenes/terrain/` now ships placeable building blocks: `RiverZone` / `MudZone` (configs
  wrapping `TerrainZone.gd`) and `Fence` (`scripts/terrain/Fence.gd`, a solid `StaticBody2D` wall).
- **Spawning** — `scripts/spawning/Spawner.gd`: shared helper to spawn a group of scenes
  across a lane (waves 1/4 + the ally line).
- **Formations** — `scripts/formations/Formation.gd` + `scenes/formations/` (ShieldWall,
  SpearPhalanx, OfficerGuard, **AlliedHost**, **ChargeGroup** — a wide flanking-charge of
  light chargers led by a Cavalry commander): a placeable body of troops arranged in ranks.
  Waves 2/3/5 arrive as raider formations; the allies deploy as `AlliedHost`.
- **Allies** — `scenes/Ally.tscn` (Footman), `AllyShield`, `AllySpear`, `AllyKnight`
  (champion): `Enemy.gd` configs with `team="ally"`, blue. They fight raiders, take no
  friendly fire, and stay out of the breach/wave/officer counts.
- **Density** — `Battlefield.density` (default 2.5) scales BOTH armies (garrison + waves +
  allied host). Big battles cost web framerate; it's a tunable export.
- **Objectives** — `scripts/objectives/` (`Objective` base + `RepelWaves` / `DefeatOfficer`
  / `HoldLine` / `ProtectBanner` — a constraint that loses if the warded allied banner dies,
  the inverse of `DefeatOfficer` / `ClearRoom` — win once every placed enemy is defeated) +
  `scripts/systems/ObjectiveManager.gd`: a level composes its win/lose by registering
  objectives (completable ones gate the win; constraints only gate losing).
- **Level** — `scripts/Battlefield.gd`: assembles the ford (terrain zones, fences, banner,
  goal), runs the 5-wave manager + log/bridge mechanics, and ticks the ObjectiveManager
  (win/lose is no longer hand-coded here).
- **Hazards/props** — `WaterWheel.gd` (Area2D spinner), `Rock.gd` (rock/crate), `Log.gd`,
  `Shockwave.gd` (slam burst), `PressurePlate.gd`.
- **Audio** — `Audio.gd` (event bus, `Audio.play(name, pos)`), `SoundBank.gd` (synthesises
  a procedural sound per event). Twelve named events fired at impact sites.
- **HUD/camera/text** — `Hud.gd`, `GameCamera.gd`, `FloatingText.gd`.
- **Touch / mobile** — `scripts/ui/TouchControls.gd` (a `Control` instanced inside `Hud.tscn`,
  so every level gets it): a left stick (move) + right stick (aim — *circle it to swing*) +
  SLAM/SPIN/restart buttons. Reuses the existing input — the right stick drives the same aim
  the mouse does and presses the `attack` action — so combat is identical; only the device
  changes. Hidden on desktop (`is_touchscreen_available()` + reveal-on-first-touch). Arthur
  reads it via the `touch_controls` group; `emulate_mouse_from_touch` is off.
- **Challenge rooms** — `scripts/rooms/` + `scenes/rooms/`: small self-contained levels that
  each teach one trick by reusing Arthur + `Enemy` + props + `Impact` + objectives —
  `BowlingRoom` (chain-impact a packed cluster with one launched body), `WallCrushRoom` (pin
  raiders to walls via `Impact.cushion`), `RockLauncherRoom` (clear every placed enemy), and
  `ComboTrialRoom` (race a timer to a Stone Flow stack target).
- **Score screen** — `scripts/ui/ScoreScreen.gd` + `scenes/ui/ScoreScreen.tscn`: a KO + time
  end-of-level summary, shown on victory/defeat via a minimal hook in `Battlefield.gd`.
- **WaveSpawner** — `scripts/spawning/WaveSpawner.gd` + `Wave.gd` + `scenes/data/SampleWaves.tres`:
  data-driven waves that materialise by reusing `Spawner`/`Formation`. Additive — the ford
  level is **not** rewired to use it yet (waves still live in `Battlefield.gd`).
- **Enemy DRAW** now telegraphs more: per-`look` silhouettes (incl. a new `knight` look),
  shield arcs + a distinct broken-shield state, spear thrust warning lines, lunge/leap charge
  lanes, and an officer/morale-aura ring (additive `Enemy.gd` `_draw` work).

### 三國無雙 / Dynasty-Warriors layer (v0.16, additive — no engine rewrite)

- **BattleMap base** — `scripts/maps/BattleMap.gd`: a reusable battle-map base. A new map is a
  thin `extends BattleMap` subclass — the base instantiates Arthur + HUD + score screen + a
  boss-healthbar overlay, drives a `WaveSpawner`, runs an `ObjectiveManager`, tracks
  KO/elapsed/breaches, and resolves win/lose. `Enemy.gd` gained `faction` (魏/蜀/吳/neutral
  colour theming) + `is_general` (joins the "generals" group) exports + `faction_color()`.
- **Five Three-Kingdoms maps** (`scenes/maps/` + `scripts/maps/`): **Hu Lao Gate (虎牢關)**
  gate chokepoint (final wave is warlord 呂武 Lu Bu); **Red Cliffs (赤壁)** fire + river using
  a reusable **`FireZone`** hazard (`scripts/hazards/`); **Guandu (官渡)** base-raid with a
  reusable **`Base`** entity + **`CaptureBasesObjective`**; **Changban (長坂坡)** escort/protect
  (reuses `ProtectBannerObjective`); **Yellow Turban (黃巾之亂)** survival horde with a reusable
  **`SurviveObjective`**.
- **Named generals (武將)** — `scripts/General.gd` (a boss brain) + `scenes/generals/`
  (LuBu / GuanYu / ZhangFei / XiahouDun): `is_general=true`, 300–520 HP, a signature war-cry.
- **Five new troop types** (`scenes/troops/`, pure `Enemy.gd` configs): Halberdier, Crossbow,
  ShockTrooper, Drummer, StandardBearer.
- **Musou gauge + ultimate** — `Arthur.gd` gains a rage gauge (fills on hits/KOs/damage) and a
  Q-triggered (`musou`) screen-clearing ultimate (reuses the Shockwave radial-launch path);
  `Hud.gd`/`Hud.tscn` show a gold MUSOU gauge.
- **Boss healthbar** — `scenes/ui/GeneralHealthbar.tscn`: auto-tracks the "generals" group,
  drawing faction-tinted boss HP bars; `BattleMap` shows it on every map.
- **Faction theming** — `Enemy.gd` `_draw` tints units toward their faction colour with richer
  per-look silhouettes.
- **Stage-select boot menu** — `scenes/ui/StageSelect.tscn` (a 三國無雙 battle picker) is now
  the boot scene (`project.godot run/main_scene`): Hold the Ford + the 4 challenge rooms + the
  5 new maps (guarded by `ResourceLoader.exists`).
- **Decor props** — `scenes/decor/` + `scripts/decor/`: FactionBanner, Brazier, GatePost, WarDrum.

## Folder map

```
CLAUDE.md, README, ROADMAP, CHANGELOG, CONTRIBUTING
docs/        MEMORY, ARCHITECTURE, BATCH_PLAN, CONCEPT, DESIGN_GOALS, CONTROLS, BUILD
devlog/      0001..0007 (dated narrative)
scripts/     actors + systems (flat) + terrain/ + spawning/ + formations/ + objectives/ + ui/ + ai/ + abilities/ + rooms/ + maps/ + hazards/ + decor/
scenes/      actor/prop/level scenes (flat) + terrain/ + formations/ + ui/ (StageSelect + GeneralHealthbar) + rooms/ + data/ + maps/ + generals/ + troops/ + hazards/ + decor/
tests/       headless *_test.gd + *.tscn (36 gate CI)
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
- Preserve the browser build; keep the 36 tests green.

## Known TODOs / next batches

- ~~An `abilities/` data system~~ — **done (v0.14)**: `scripts/abilities/` (Ability + Library +
  Javelin). Possible next: more kinds (aura/buff, ranged volley), per-ability VFX, ability cooldown
  UI. Obstacle nav is `scripts/ai/Steering.gd` (whisker avoidance); a baked navmesh is a future
  option if local steering proves too weak on a concave map.
- Optionally refactor the hand-placed garrison in `Battlefield.tscn` to `Formation`
  instances (kept hand-placed for now so `battle_test`'s `$ShieldWall` group still works),
  and add formation **break/morale** conditions.
- ~~A full `WaveSpawner` resource~~ — **done**: `scripts/spawning/WaveSpawner.gd` + `Wave.gd`
  + `scenes/data/SampleWaves.tres` (additive; **adopt it inside `Battlefield.gd`** — waves
  still live there). Still open: an `EnemyPool` for a bigger crowd.
- ~~KO + time **score screen**~~ — **done** (`scripts/ui/ScoreScreen.gd`). ~~The challenge
  rooms~~ — **done** (`scripts/rooms/`: Bowling / Wall-Crush / Rock Launcher / Combo Trial).
  Still open: per-ability VFX + cooldown UI; a balance pass. See [`../ROADMAP.md`](../ROADMAP.md).
