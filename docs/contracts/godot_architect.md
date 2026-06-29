# Contract — Godot Architect

*See [game_director.md](game_director.md) for the contract format and the shared-file rule.*

## Mandate
Build and refactor the **systems, scenes, signals, and data schemas** that the journey needs —
safely, on top of the existing engine, web-export-safe. Own the *structure*; hand content to the
World Designer, visuals to Visual Polish, and combat tuning to the Gameplay Integrator.

## Owned systems (new + extended)
- **`scripts/maps/Worldmap.gd` + `scenes/maps/Worldmap.tscn`** — the Map-of-Britain overworld
  (new `run/main_scene`); reads `Campaign`, draws nodes/journey-line/marker, deploys via `Transition`.
- **`Campaign.gd` schema/API** — new fields (`region`, `map_pos`, `links`) + helpers
  (`region_for`, `links_for`, `regions()`); keep persistence/unlock/finale contract.
- **`scripts/triggers/StoryTrigger.gd`** — placed `Area2D` firing one-shot beats + ctx flags.
- **`scripts/objectives/ReachLandmarkObjective.gd`** — completes on a StoryTrigger ctx flag.
- **`BattleMap._story_beats()` hook** + the scan that fires beats against `ctx` (wave/time/ko/boss).
- **`scripts/Music.gd` autoload** + the Music/SFX/Ambience **bus layout** (structure; content
  layers coordinated with Visual Polish/Integrator).
- **`scripts/world/RegionBackdrop.gd`** node *scaffold* (Visual Polish authors the silhouettes).
- **Faction migration**: a single shared Arthurian faction-colour source; add
  `camelot/saxon/pict/rebel/fae` to `Enemy.faction_color`, `FactionBanner`, `WarDrum` enums;
  retire `wei/shu/wu` from the visible path.
- `project.godot`: autoload registration, `run/main_scene`, input map (if new actions needed).
- `BattleMap.gd` base orchestration + new hook signatures; pre-battle briefing wiring in `_ready`.
- Re-theme `BattleMap` class doc away from "Three-Kingdoms".

## MAY modify
- All files in *Owned systems*; `scripts/maps/BattleMap.gd`; `scripts/Campaign.gd` (schema/API);
  `scripts/ui/ScoreScreen.gd` + `scripts/ui/StageSelect.gd` (route to Worldmap / retire flat list);
  `project.godot`; new files under `scripts/systems/`, `scripts/triggers/`, `scripts/world/`.

## MUST NOT modify
- Combat tuning numbers / the ultimate / boss kits / formation morale (Gameplay Integrator).
- `scripts/art/*` silhouettes, ground palettes, decor `_draw`, `CanvasModulate`/glow values
  (Visual Polish) — Architect provides the *hooks*, Visual Polish fills the *look*.
- Story/region *content & data values* (World Designer) — Architect provides the *schema*.
- `tests/**` assertions & `.github/**` (QA) — though Architect notifies QA which tests its schema
  changes break, so QA updates them in the same change.

## Public API it provides
- **`Campaign`**: `region_for(path)`, `links_for(path)`, `regions()`, plus existing
  `stages/next_path/is_unlocked/is_cleared/mark_completed/is_finale/cleared_count/total`.
- **Signals** (per [world_rebuild_plan §3](../world_rebuild_plan.md)):
  `region_entered(region_id)`, `landmark_discovered(landmark_id)`,
  `interaction_triggered(interaction_id)`, `progression_unlocked(progression_id)`,
  `checkpoint_reached(checkpoint_id)`, `story_moment_triggered(story_id)`.
- **`BattleMap` hooks**: `_story_beats()` (data), `_region_backdrop()`, `_region_mood()`,
  pre-battle briefing — for World Designer / Visual Polish to fill.
- **`StoryTrigger`** placement API; **`ReachLandmarkObjective`** for `_compose_objectives`.

## Dependencies
- Lands **first** each phase (schema/hooks/scenes) so World Designer / Visual Polish / Integrator
  can fill data/look/tuning without inventing structure. Coordinates with QA on schema-breaking tests.

## Test checklist
- [ ] `--import` parse gate passes (no broken refs; **no deleted preloaded TK scenes**).
- [ ] `worldmap_test`, `story_trigger_test`, `reach_landmark_test`, `music_test` green.
- [ ] `campaign_test` green against the new schema (coordinated with QA/World Designer).
- [ ] Boots to `Worldmap.tscn`; `Transition` deploy + return-to-map works headless.
- [ ] Faction migration keeps `beautify_test` green (re-id'd + colours updated with QA).
- [ ] No threads / GLES3-only features; web export still builds.

## Rollback plan
- New systems are isolated files + additive hooks; revert the file/commit. Schema changes to
  `Campaign` are additive fields (old saves keyed by id still load); a bad schema reverts without
  data loss. `run/main_scene` flip is a one-line `project.godot` revert back to `StageSelect.tscn`.
