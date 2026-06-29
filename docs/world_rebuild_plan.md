# World Rebuild Plan

*The concrete, phased, test-safe plan to turn the flat level-list into a connected Arthurian
Musou world. Reads on top of the [critique](current_game_design_critique.md) (evidence) and the
[creative direction](creative_direction.md) (vision). Every phase is incremental, keeps the
single-threaded web build working, and keeps the 84-test CI gate green (updating constraint tests
in the same change). Build-once-reuse-many: new content is config + thin subclasses, not rewrites.*

---

## 1. Goals & guardrails

**Goal:** a connected, explorable, atmospheric Arthurian journey with a Musou power fantasy,
built **on** the existing engine. Success = the five pillars in [creative_direction §5](creative_direction.md).

**Guardrails (every PR respects):**
- Don't rewrite the combat core or the level base — extend/tune.
- Keep gl_compatibility, single-threaded, web-export safe. No threads.
- All art code-drawn; all UI text ASCII+colour (verify tofu on the live build).
- **Reskin Three-Kingdoms in place** — never delete a `.tscn` that a test `preload`s.
- Update the relevant constraint test **in the same commit** as the change that breaks it.
- Land work on `dev`, gate on `validate.yml`, ship `dev`→`main` with a tag (CLAUDE.md workflow).

---

## 2. Architecture map (what's reused vs. what's new)

```
EXISTING (preserve/extend)                         NEW (add, minimal)
──────────────────────────────                     ───────────────────────────────
Impact (autoload) ........ combat hub  ──tune──▶
Arthur / StoneWeapon ..... hero        ──tune──▶    (no new files; re-tune + revive ult)
Enemy / Ability / Steering bombs        ──cfg──▶    Arthurian troop/boss .tscn configs + Ability rows
Formation ................ ranks       ──extend─▶   formation cohesion + morale (in Formation.gd)
BattleMap ................ level base   ──extend─▶   _story_beats() hook; ground/backdrop/mood theming
Campaign (autoload) ...... progression ──extend─▶   region + map_pos + links data (the world graph)
Transition (autoload) .... scene fade  ──reuse──▶
ObjectiveManager + objs .. win/lose    ──add────▶   ReachLandmarkObjective
Audio + SoundBank ........ sfx bus     ──extend─▶   Music (autoload): looping theme + ambience layers
GameCamera ............... camera juice──tune──▶
Breakable/FireZone/Terrain env          ──place──▶   exploration caches; new TerrainZone rule branches
scripts/art/* ............ unit art    ──reuse──▶    bigger boss silhouettes / auras
                                                    Worldmap (scene+script): the Map of Britain (new main_scene)
                                                    RegionBackdrop (node): per-region horizon silhouette
                                                    StoryTrigger (Area2D): landmark/story moment on enter
                                                    StoryCard (Control): between-battle / pre-battle narrative card
                                                    Faction colour: one shared Arthurian source (camelot/saxon/pict/rebel/fae)
```

**Net new code is small and data-driven.** The bulk of the rebuild is *config, placement,
theming, tuning, and one overworld scene.*

---

## 3. The requested manager systems — mapped, not multiplied

The brief listed `WorldManager / RegionManager / ProgressionManager / TriggerManager /
DialogueManager / CheckpointManager`. Per "don't over-engineer," we **map these onto the
existing architecture** and add only what's genuinely missing:

| Requested manager | How we deliver it | New file? |
| --- | --- | --- |
| **ProgressionManager** | **Existing `Campaign.gd`** (ordered stages, unlock, persist, finale). Extend with region/map_pos/links. | No (extend) |
| **WorldManager** | **`Worldmap.gd`** — the overworld scene; reads Campaign, draws the map, deploys via Transition. | Yes (1) |
| **RegionManager** | **Region data on Campaign** + each region's thin `BattleMap` subclass owns its theme. No central singleton needed. | No (data) |
| **TriggerManager** | **`StoryTrigger.gd`** (placed `Area2D`, like `TerrainZone`) + `BattleMap._story_beats()`. Placement-based, no central manager. | Yes (1) |
| **DialogueManager** | **Native `StoryCard.gd`** (code-drawn card) + `_story_beats` popups. *Not* the Dialogue Manager addon (stays on 4.3, zero deps). | Yes (1) |
| **CheckpointManager** | **Deferred** — `Campaign` already persists per-battle clears; in-battle checkpoints aren't needed for wave arenas. Revisit only if a long escort region wants mid-mission saves. | No (deferred) |

**Signals** (the brief's vocabulary), emitted by the systems above — loose-coupled, no polling,
matching the existing `Impact`/`StoneWeapon` signal style:

| Signal | Emitter | Consumer |
| --- | --- | --- |
| `region_entered(region_id)` | `Worldmap` (on node focus/deploy) | ambience/music selection, analytics |
| `landmark_discovered(landmark_id)` | `StoryTrigger` | `StoryCard`/popup, `ReachLandmarkObjective`, exploration reward |
| `interaction_triggered(interaction_id)` | `StoryTrigger` / `PressurePlate` | gates, caches, story beats |
| `progression_unlocked(progression_id)` | `Campaign` (on `mark_completed`) | `Worldmap` node state, travel animation |
| `checkpoint_reached(checkpoint_id)` | `BattleMap` (optional, per wave) | HUD beat, music intensity step |
| `story_moment_triggered(story_id)` | `BattleMap._story_beats` / `StoryTrigger` | `StoryCard`/popup, music ducking |

---

## 4. Per-region theming spec (kills the "prototype" look)

Each region is its existing/reskinned `BattleMap` subclass, given a **one-screen identity** via:
`ground_top`/`ground_bottom` override · a `RegionBackdrop` silhouette · a `CanvasModulate` mood ·
ambient drift · placed Arthurian decor · region ambience track · Arthurian troop rosters.

| Region (scene) | Ground palette | Backdrop silhouette | Mood (CanvasModulate) | Ambience | Signature dressing |
| --- | --- | --- | --- | --- | --- |
| Churchyard (`SwordInStone`) | grey flagstone | chapel + yew trees | cold dawn (pale blue-gold) | birdsong + wind | sword-in-stone prop, headstones, Pendragon banner |
| The Marches (`HuLaoGate`*) | churned mud-brown | palisade + watchtower | overcast dusk | frontier wind, distant horn | torches, Saxon vs Camelot banners, funnel gate |
| Burning Fords (`RedCliffs`*) | wet slate + sand | burning longships on water | smoke-red | river burble + fire crackle | FireZone fleet, water bands, beacon |
| The Long Road (`Changban`*) | rain-dark earth | broken hedgerow, far Camelot | rainy grey | rain + footfalls | escorted folk/cart, mud, fallen gear |
| Beacon-Forts (`Guandu`*) | hill turf | stockade ring on a ridge | flat overcast | wind + crows | capturable forts, supply caches, signal-fires |
| Mount Badon (`MountBadon`) | green hillside | standing stones on the crest | bright noon | larks + war-din | hill slope, muster banners, Cerdic's standard |
| Camelot (`DefendCamelot`) | stone courtyard | castle towers + curtain wall | golden torch-dusk | torch-flutter, hall murmur | gate, Round Table, lit braziers, Pendragon |
| Night-Host (`YellowTurban`*) | moonlit moor | jagged tor + cairns | moonlit blue (eerie) | owl, low drone | wraith fires / Pict totems, mist |
| Camlann (`Camlann`) | ashen mauve | blasted oaks, far smoke | blood-red dusk | crows, wind, distant clash | corpse-strewn field, fallen banners, blood seam |
| Avalon (`LadyOfLake`) | pale shore | misted hills across water | silver mist | water lap, ethereal tone | shimmering lake, Lady's arm + Excalibur, mist |

`*` = reskinned Three-Kingdoms scene (file path kept).

**Reusable visual modules to build once:** `RegionBackdrop` (Node2D `_draw` horizon), an
`AmbientDrift` decor node (generalised from `LadyOfLake:269-272`), an additive-glow mixin for
`Brazier`/`Torch`/`FireZone`, and a `ground scatter` decal pass in `BattleMap` (non-colliding,
fills the empty centre).

---

## 5. The connected world map (the journey)

**`Worldmap.tscn` / `Worldmap.gd`** (new `run/main_scene`), a `Node2D`:
- Draws a **parchment map of Britain** in code (aged vellum fill, ink coastline, region labels in
  ASCII+gold per the tofu rule).
- Places **one node per region** at `Campaign` `map_pos`; draws the **journey line** (dotted ink
  road) along `links`; node state straight from `Campaign.is_unlocked` (grey/sealed),
  `is_cleared` (banner planted), and "next" (glowing).
- A **travelling Arthur banner-marker** that, on return-from-victory, advances along the line to
  the newly-unlocked node (reusing `Transition` for the wipe) — the *felt* sense of travel.
- Reuses `StageCard`/`MenuList` interaction patterns and `Transition.change_scene` to deploy.
- The **Camelot node** opens a small sub-menu = the **Training Yard** (Hold the Ford + 4 rooms),
  demoting Trials out of the legend spine.

**Flow changes:** `ScoreScreen`'s "Next" returns to the Worldmap and animates travel (instead of
hard-cutting to the next list row); a **pre-battle briefing** shows the *current* stage's blurb on
deploy (`BattleMap._ready` via `Campaign.blurb_for(scene_file_path)`), fixing the
"blurb at the wrong moment" gap; optional **`StoryCard` interstitial** between Acts.

---

## 6. Phased delivery (each phase ships green)

> Ordering rationale: purge the off-theme + migrate factions **first** (it touches the most
> files and unblocks everything), then make it *look* like a world, then *connect* it, then make
> it *feel* Musou, then *story/exploration*, then polish. Each phase = one `dev`→`main` tag.

### Phase A — Theme purge & faction migration *(unblocks the directive)*
1. **Reskin the 5 TK maps in place** (keep scene paths): rewrite titles/blurbs/objective+wave
   labels to Arthurian; **strip all CJK** (tofu); rename `LuBu` etc. → Arthurian warlords
   (reuse `WarlordArt`/`BlackKnightArt`).
2. **Faction migration:** add `camelot/saxon/pict/rebel/fae` to a **single shared colour source**
   + the `FactionBanner`/`WarDrum` enums; replace every `faction='wei'/'wu'/'shu'` hack; retire
   the TK keys from the visible path. Update `beautify_test`.
3. **Campaign restructure:** remove `— THREE KINGDOMS (BONUS) —`; regroup stages into Arthurian
   regions/acts; add `region`/`map_pos`/`links` fields (data only this phase). Update
   `campaign_test`, `stage_arthur_test`, `finale_audio_test`.
4. **Repoint the 9 preload tests** + `generals_test`/`troops_test` to the reskinned scenes.
5. Re-theme `BattleMap` class doc; collapse the duplicated `SEC_*` consts.
6. **Add a "no-TK-leak" guard test** (assert no 三國/wei/shu/wu/Lü Bu strings in Campaign/labels).
- *Exit:* 84 tests green (constraint tests updated); live build shows no TK theme, no tofu.

### Phase B — Visual identity pass *(kills the prototype look)*
1. Per-region `ground_top/ground_bottom` overrides (table §4).
2. Replace `Battlefield.gd`/`Arena.gd` graph-paper grids with the gradient+dapple floor.
3. Build `RegionBackdrop` + `AmbientDrift` + additive-glow mixin + `CanvasModulate` mood; apply per region.
4. Place orphaned decor (`CamelotBanner`/`RoundTable`/`Torch`/`SwordInStone` prop); delete inline `draw_rect`/`draw_line` banner+sword stand-ins.
5. Wire Arthurian troop scenes (`SaxonRaider`/`BritonLevy`/…) into wave rosters; bigger boss silhouettes/auras.
6. Ground-scatter decal pass to fill empty centres.
- *Exit:* each region visibly distinct on the live build; art tests green; new `region_theme_test`.

### Phase C — The connected world map *(the journey)*
1. Build `Worldmap.tscn`/`.gd`; set as `run/main_scene`.
2. Journey line + travelling marker + node states from Campaign; Camelot → Training Yard sub-menu.
3. Route `ScoreScreen` "Next" → Worldmap travel beat; pre-battle briefing in `BattleMap._ready`.
4. Optional `StoryCard` Act interstitial.
5. **`WorldmapTest`** (instantiate overworld, assert nodes/links/state, `WORLD_VERDICT PASS`); add CI step.
- *Exit:* boot lands on the map of Britain; clearing a region advances the marker; tests green.

### Phase D — Musou feel: combat tune + spectacle *(the power fantasy)*
1. **Swing accessibility:** assisted/auto-swing layer (reuse the touch auto-torque); soften the hard `hit_speed_min` zero-damage gate.
2. **Mobility/stamina:** raise base speed, soften weapon-state rooting, rebalance stamina for sustained flow.
3. **Stone Flow crescendo:** make force/speed/visual juice escalate with the streak.
4. **True rage ultimate:** revive the radial Shockwave screen-clear (the class doc's intent) at gauge-dump scale; reserved top-tier shake/zoom + a dedicated roar + center-screen announce.
5. **Spin** becomes a real horde-mulcher while Flow is high; tie KO milestones to escalating screen juice.
6. **Bosses:** signature Ability rows (`spell_bolt`/`arrow_rain`/`whirlwind`/`ground_quake`), entrance name-card + cleared arena, phase/enrage; **Morgan gets real sorcery**.
7. **Formation cohesion + morale:** wire the unused `Formation.units` — ranks hold; **officer falls → unit routs** (scale the existing banner-death stun).
- *Exit:* the stone always shreds; the ult clears the screen; bosses feel like fights; combat tests + new `musou_feel`/`formation_morale` tests green.

### Phase E — Audio, story & exploration *(legendary + discovery)*
1. **`Music` autoload:** looping theme + intensity layers (Flow/wave/boss) + swelling finale; region ambience beds; bus split (Music/SFX/Ambience).
2. **SFX:** spatialise (use `world_pos`), pitch-vary, raise voice pool, horde death-shouts, wire dead escalation voices + KO-milestone stingers + boss entrance stingers.
3. **`StoryTrigger`** + `ReachLandmarkObjective` + `BattleMap._story_beats()`; place environmental beats (the stone, a fallen banner, the lake); foreshadow Mordred (recurring nemesis).
4. **Exploration caches** (a `Breakable` config dropping health/Flow/relic, placed off-lane); new `TerrainZone` rule branches (sacred-water heal, cursed bog) for mythic regions.
- *Exit:* the world has music+ambience; story beats fire; exploration rewards exist; tests green.

### Phase F — Polish & QA *(verify before claiming done)*
1. Add advisory `gdlint`/`gdformat` step to `validate.yml`.
2. **Live web-build verification** (claude-in-chrome): screenshot every region, read console, confirm no tofu/atmosphere regressions.
3. `/code-review` (high) on the integration merges; `/simplify` to enforce build-once-reuse-many.
4. Write [`docs/final_world_rebuild_report.md`](final_world_rebuild_report.md).

---

## 7. Test strategy (keep CI green throughout)

- **Reskin-in-place** preserves the `--import` parse gate (no deleted preloaded scenes).
- Each phase **updates its constraint tests in the same commit** — see
  [critique §6](current_game_design_critique.md) for the exact blocking tests
  (`stage_arthur_test`, `campaign_test`, `beautify_test`, `finale_audio_test`, the 9 preload tests).
- **New tests** (one per new system, `*_VERDICT PASS` + a `validate.yml` step): `worldmap_test`,
  `region_theme_test`, `story_trigger_test`, `reach_landmark_test`, `music_test`,
  `formation_morale_test`, `musou_feel_test`, `no_tk_leak_test`.
- `--quit-after 600` (idle frames) per the harness gotcha.
- Modules that don't change (Impact/Enemy/Ability/Objective/HUD/Transition) keep their tests
  green untouched — the safety net for the tune-up.

---

## 8. Risk register

| Risk | Likelihood | Mitigation |
| --- | --- | --- |
| Deleting a TK scene breaks the `--import` gate | high if done naively | **Reskin in place**; never delete preloaded `.tscn`. |
| Combat re-tune trivialises difficulty (too easy) | medium | Shift challenge to *battlefield pressure* (numbers, terrain, objectives), not hero clumsiness; tune via Impact in one place; playtest on live. |
| Web framerate at higher horde density | medium | Keep `active_cap`/mobile density caps + dirty-redraw gates; lean launch/bowling so small hordes *feel* big. |
| Tofu in new UI/menu/world-map text | medium | ASCII+colour only; verify on the live Pages build (claude-in-chrome). |
| Parallel agents collide on shared files | medium | The role [contracts](contracts/) assign file ownership + must-not-modify lists; integrate centrally on `dev`. |
| Scope creep across 6 phases | medium | Each phase is an independently shippable tag; stop-and-ship between phases. |

---

## 9. Execution model

This rebuild is a multi-phase, multi-agent effort (matching the user's established
[multi-agent feature workflow](../../.claude/projects/C--Users-DD-Downloads-auth/memory/multi-agent-feature-workflow.md)
memory). Each phase is decomposed across parallel agents bounded by the **role
[contracts](contracts/)** (game director / world designer / godot architect / visual polish /
gameplay integrator / QA regression), integrated centrally on `dev`, gated by `validate.yml`,
and shipped to Pages on `main`. The lead holds the creative vision and integrates; agents own
slices. See [`docs/contracts/`](contracts/) for each role's owned files, must-not-modify list,
public API/signals, test checklist, and rollback plan.
