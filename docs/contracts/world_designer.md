# Contract — World Designer

*See [game_director.md](game_director.md) for the contract format and the shared-file rule.*

## Mandate
Redesign the **world, map, regions, landmarks, progression order, and story content** so the game
reads as a connected Arthurian journey, not a flat list. Own *what the places are, where they sit,
how they connect, and what they say* — not how they're rendered or how combat is tuned.

## Owned systems
- The **region roster + biomes + premises** ([creative_direction §3](../creative_direction.md),
  [world_rebuild_plan §4](../world_rebuild_plan.md)).
- The **world graph** (region ids, `map_pos`, `links`, acts/sections) — the *data* in `Campaign`.
- The **journey/story content**: titles, pre-battle briefings, blurbs, objective/wave *labels*,
  `_story_beats` text, `StoryCard` copy, the recurring-nemesis (Mordred) thread.
- **Reskin text** for the 5 Three-Kingdoms maps → Arthurian regions; the Worldmap *layout/content*.
- Which Arthurian troop/boss scenes each wave *uses* (the roster choice, not the tuning).

## MAY modify
- `scripts/Campaign.gd` — **data only**: the `STAGES` entries (titles/blurbs/region/map_pos/
  links/section), `SECTION_LABELS`. *(Schema/new fields are added by the Architect first; fill data after.)*
- `scripts/maps/*.gd` — **content hooks only**: `_map_title`, `_opening_banner`,
  `_compose_objectives` *labels*, `_story_beats`, and the *roster selection* inside
  `_build_wave_spawner`/`_spawn_allies` (which unit `.tscn` to field). *(Not ground palette, not
  `_draw` theming, not wave counts/density/boss tuning.)*
- `scripts/ui/StoryCard.gd` — **copy/sequence only** (visual style is Visual Polish's).
- `scenes/maps/Worldmap.tscn` content/region placement *(Architect owns the `Worldmap.gd` logic)*.
- Faction **names** in reskin (`'wei'→'saxon'` etc. at call sites within map content hooks).
- `docs/` (region/story notes).

## MUST NOT modify
- Combat core: `Impact.gd`, `Arthur.gd`, `StoneWeapon.gd`, `Beam.gd`, `Shockwave.gd`, `Enemy.gd`
  internals, `abilities/*`, `Cavalry.gd`, `General.gd`, `Formation.gd` logic.
- Rendering/theme: `BattleMap` `_draw`/ground mechanics, `scripts/art/*`, `RegionBackdrop`,
  decor `_draw`, `CanvasModulate`/glow (Visual Polish).
- `BattleMap.gd` base orchestration & new-hook *signatures*, `Worldmap.gd` logic, `Campaign`
  *schema/API*, autoloads, `project.godot` (Architect).
- `tests/**`, `.github/**` (QA).

## Public API it provides / consumes
- **Provides:** the world graph data (`region`, `map_pos`, `links` on each stage) the Worldmap
  reads; the story-beat data tables; reskin naming.
- **Consumes:** `Campaign` schema + helper API (from Architect); the `_story_beats()`/
  `StoryTrigger`/`ReachLandmarkObjective` hooks (from Architect); region palettes (Visual Polish).
- **Signals consumed:** `progression_unlocked`, `region_entered`, `story_moment_triggered`.

## Dependencies
- **Architect must land first:** Campaign schema fields, `Worldmap.gd`, `StoryTrigger`,
  `ReachLandmarkObjective`, `_story_beats()` hook. World Designer then fills the data/content.

## Test checklist
- [ ] `campaign_test` / `stage_arthur_test` / `finale_audio_test` updated to the Arthurian
      structure and green.
- [ ] `no_tk_leak_test` green (no 三國/wei/shu/wu/Lü Bu/Cao Cao strings in stages/labels).
- [ ] `worldmap_test` sees the expected region nodes + links + states.
- [ ] Every Arthurian stage has a non-empty briefing blurb and an unlock predecessor.
- [ ] No CJK in any player-facing string (grep + live-build check via QA).

## Rollback plan
- Content/data changes are isolated to `Campaign` data + map content hooks + `StoryCard` copy;
  revert the specific commit. World graph is data, so a bad layout reverts without touching logic.
