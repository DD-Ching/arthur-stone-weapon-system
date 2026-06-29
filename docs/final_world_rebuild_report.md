# Final World-Rebuild Report — *The Stone King*

*The capstone for the Arthurian Musou world rebuild. Pairs with the four planning deliverables
([critique](current_game_design_critique.md) · [creative direction](creative_direction.md) ·
[world rebuild plan](world_rebuild_plan.md) · [tool evaluation](skill_tool_evaluation.md)) and the
six role [contracts](contracts/). It records what was wrong, what shipped, and what remains.*

---

## 1. The mandate

> **Play like Musou (無雙 / Dynasty-Warriors). Feel like King Arthur.** The world/map/atmosphere
> was weak, empty, boring, prototype-like, and read as *random separate levels from a flat list*.
> Rebuild the world into a connected, explorable, atmospheric Arthurian adventure — keep the
> physics-combat core, retire/reskin the off-theme Three-Kingdoms content.

## 2. The starting point (from the audit)

An 11-dimension parallel code audit found: **the engine is excellent; the world layer is the
prototype.** The combat hub (`Impact`), the config-driven `Enemy`, the `BattleMap` base, the
`Campaign` autoload, the `ObjectiveManager`, the procedural audio bus, and an 84-test CI net were
all clean build-once-reuse-many systems — to be *preserved*. What was weak lived above the engine:
no world/journey (a flat menu), a still-visible Three-Kingdoms theme (CJK that tofu'd in the web
font, `wei/shu/wu` factions), one flat near-black floor for every region, no lighting/music/ambience,
combat tuned *against* the Musou fantasy, fodder-like bosses, and orphaned Arthurian content.

## 3. What shipped (six phases, eight deploys, all CI-green on Godot 4.3.0)

| Phase | Outcome | Tag |
| --- | --- | --- |
| Inspect + design | 11-dimension audit → 4 design docs + 6 role contracts | — |
| **A — Theme purge** | Reskinned the 5 ex-TK maps *in place* to Arthurian regions; migrated factions to Arthurian houses (`camelot/briton/saxon/rebel/pict/fae`); stripped all CJK (also fixed web-font tofu); restructured `Campaign` into one connected 10-region legend + a Training Yard; added a `no_tk_leak` guard test. | v0.27.0 |
| **B — Visual identity** | Each of the 10 regions got a distinct ground palette + `CanvasModulate` time-of-day mood + a distant-scenery `RegionBackdrop` silhouette + `AmbientDrift` particles + placed decor. New reusable `scripts/world/{GroundPaint,RegionBackdrop,AmbientDrift}.gd`. Killed the graph-paper grids. | v0.27.0 |
| **C — World map** | A hand-inked **Map of Britain** overworld (`scripts/ui/Worldmap.gd`) as the boot scene + return-to-map hub: region pins from `Campaign` `map_pos`, a journey road that gilds as you clear it (along `links`), Arthur's banner-marker on the reached region, sealed regions ahead. | v0.28.0 |
| **D — Musou combat** | (1) A true screen-clearing **radial ultimate** + KO-milestone screen juice. (2) The juggernaut hero feel: the swing **always shreds** (hit_speed_min 420→190), juggernaut mobility + sustainable stamina, a real spin horde-mulcher, a felt Stone-Flow crescendo. (3) The living battlefield: **formation morale** (cut down the officer → the ranks rout), boss **entrance name-cards**, Morgan le Fay's real caster kit. | v0.28.1–.3 |
| **E — Music & atmosphere** | A new **Music autoload**: procedural looping beds (a war-drum battle bed, a calm map bed) that swell with combat intensity. Pitch-varied SFX, a dedicated musou-ult **roar**, KO-milestone **stingers**. | v0.28.4 |
| **F — Polish & report** | This report; orientation refresh; live-build verification. | v0.29.0 |

## 4. Architecture — preserved vs. new (golden rules honored)

**Preserved, untouched-in-spirit (re-tuned, never rewritten):** `Impact` (combat hub),
`Arthur`/`StoneWeapon` (the pendulum drag-swing identity is intact — only numbers changed),
`Enemy` + abilities + steering, `BattleMap` base, `Campaign`/`Transition` autoloads,
`ObjectiveManager` + objectives, the audio bus + `SoundBank`, the 84 original tests.

**New reusable modules (build-once-reuse-many):** `scripts/world/GroundPaint.gd` (shared floor),
`RegionBackdrop.gd`, `AmbientDrift.gd`; `scripts/ui/Worldmap.gd` (overworld); `scripts/Music.gd`
(autoload). **Extended:** `Campaign` (region/map_pos/links geography + helpers), `BattleMap`
(`_theme()`/`_paint_region()`/`region_mood` + music), `Formation` (morale rout), `General`
(entrance), `Shockwave` (`damage_mult`).

The physics-combat core and the single-threaded gl_compatibility web export are intact; nothing
was rewritten from scratch; new content is config + thin subclasses + placement.

## 5. The five pillars — delivered

1. **JUGGERNAUT** — the swing always shreds; rampages crescendo (KO milestones snap the screen);
   the ultimate clears the screen with a roar.
2. **LIVING BATTLEFIELD** — ranks rout when their officer falls; named generals arrive as events;
   terrain/decor dress the field; the music swells with the fight.
3. **THE JOURNEY** — a connected Map of Britain; ten distinct regions; a road that lights as you
   advance; a marker that travels it.
4. **LEGENDARY MOMENTS** — boss name-cards, the rage ultimate, milestone spectacle, a swelling
   finale, a score behind it all.
5. **DISCOVERY** — *partial* (exploration caches + story triggers remain — see §7).

## 6. Verification

- **89 headless tests** gate CI (`validate.yml`), all green on the CI source-of-truth **Godot 4.3.0**
  and on local 4.7. Six new guard tests were added: `no_tk_leak`, `region_theme`, `worldmap`,
  `formation_morale`, `music` (+ rewritten `musou`/`feel`).
- Every phase was committed on `dev`, merged `--no-ff` to `main`, tagged, and **deployed to GitHub
  Pages** — eight live deploys (v0.27.0 → v0.29.0), each validated on 4.3.0.
- Visuals were verified by windowed frame-captures of all 10 regions + the overworld during the
  build, and the live Pages build was checked for web-font tofu / console errors.
- Live demo: <https://dd-ching.github.io/arthur-stone-weapon-system/>

## 7. What remains (refinements, not core gaps)

- **Deeper boss differentiation** — per-boss signature `AbilityLibrary` rows (spell_bolt /
  arrow_rain / whirlwind / ground_quake), a phase/enrage, the Black Knight's unbreakable guard.
- **Region ambience beds** — per-region looped ambient (river / moor wind / war-din) on the Music bus.
- **Story & exploration** — a `StoryTrigger` Area2D + a `ReachLandmarkObjective` + a `_story_beats`
  hook for environmental storytelling; exploration caches (a `Breakable` config dropping health/Flow).
- **Tooling** — an advisory `gdlint`/`gdformat` CI step (needs `pip install gdtoolkit` — pending
  approval); deleting the now-orphaned `Beam.gd`/`Beam.tscn` (the ult is radial now).

These are scoped in [`world_rebuild_plan.md`](world_rebuild_plan.md) and the role
[contracts](contracts/); the file-ownership matrix lets them be picked up safely in parallel.

## 8. Bottom line

The game no longer feels like a boring prototype of disconnected levels. It is a connected,
atmospheric, strictly-Arthurian world you travel across — and it plays like Musou: one juggernaut
carving through an army that breaks when you fell its officers, to a swelling score, ending in a
screen-clearing roar. The world rebuild the mandate asked for is **done and live.**
