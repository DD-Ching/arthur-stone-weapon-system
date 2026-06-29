# Current Game Design Critique

*A grounded audit of the Arthur Stone Weapon System before the Musou-feel / King-Arthur
world rebuild. Written by the lead from an 11-dimension parallel code audit (combat, enemies,
world structure, Arthurian content, Three-Kingdoms leftovers, visuals, objectives/triggers,
juice/audio, props/terrain, tests/CI, tooling). Every claim is backed by `file:line` evidence.*

> **Directive this critique is measured against** (user, authoritative):
> **Genre/feel = Musou (無雙 / Dynasty-Warriors)** — one overwhelming hero shredding hordes,
> generals as bosses, a screen-clearing rage ultimate. **Theme = strictly King Arthur.** The
> Three-Kingdoms content is an off-theme leftover and must not survive as a visible theme.
> The world/map/atmosphere is weak, empty, boring, prototype-like, and reads as *random
> separate levels from a flat list* — it must become a connected, explorable Arthurian journey.

---

## 1. Verdict in one paragraph

**The engine is genuinely good; the *world layer* is what feels like a prototype.** The
combat core, the enemy/ability/formation/wave architecture, the `BattleMap` level base, the
`Campaign` progression autoload, the `ObjectiveManager`, the procedural audio bus, and the
84-test CI net are all clean, modular, "build-once-reuse-many" systems that must be
**preserved and built upon, not rewritten**. What is weak, boring, and off-theme lives almost
entirely *above* the engine: there is **no world/journey** (a flat menu of cards), the
**Three-Kingdoms theme is still visible**, every region shares **one flat near-black floor**
with **no lighting, music, or ambience**, the combat is tuned as the *opposite* of a Musou
power fantasy, bosses fight like fodder, and a pile of already-authored Arthurian content sits
**unused**. None of this requires a rewrite — it requires a focused redesign of the world,
presentation, and feel on top of the existing modules.

---

## 2. Core gameplay loop (what the game *is* today)

Arthur drags a giant stone that follows the cursor as a **spring-damped pendulum**; how hard a
hit lands is read off the head's *real measured speed* (`StoneWeapon.gd:45` `hit_speed_min 420`).
All force resolves through one hub — `Impact.resolve_hit` (`Impact.gd:199-223`): `score =
speed × mass × charge × angle × collision × combo`. He has slam (RMB), spin (Shift/MMB), a
musou gauge + Q "ultimate," stamina, and the **Stone Flow** combo. Levels are wave-survival
arenas with terrain, formations, allied troops, named-general bosses, breach/objective win-lose,
and a KO/time score screen. The macro shape is **boot → StageSelect list → level → ScoreScreen
→ next**.

This loop is *recognizable Musou in its bones* (one strong hero vs. a horde, officers/generals
to fell, rampage callouts) — but it is **tuned and presented against** the Musou fantasy. See §5.

---

## 3. Strengths — what is GOOD and must be PRESERVED

| Strength | Evidence | Why it matters |
| --- | --- | --- |
| **One scoring hub** — every hit (swing/slam/spin/beam/prop/bowling) routes through `Impact.resolve_hit` | `Impact.gd:199-223`; consumers `StoneWeapon.gd:312`, `Shockwave.gd:39`, `Beam.gd:83`, `Impact.collide:305` | Re-tuning the whole game's feel is a **numbers job in one file**, not a rewrite. |
| **The pendulum drag-swing is a unique, ownable identity** | `StoneWeapon.gd:240-265` (follow_stiffness 13, drag_gain 5.2, max_avel 28) | Nothing else plays like it; power genuinely comes from motion. |
| **Impact "language": hit-stop + directional shake + heat-glow + swing-weight lunge** | `Arthur.gd:290-296` (time_scale 0.06), `StoneWeapon.gd:345-346`, `:516-518`, `:337-339` | The meaty, legible juice a Musou lives on — already built. |
| **`Enemy.gd` is ONE script; every unit is a `.tscn` config of it** | `Enemy.gd:1-61`; 12-look enum `:17` | A new Arthurian foe = exports, **zero new code**. |
| **Data-driven Abilities (7 moves, range-banded selection)** | `AbilityLibrary.gd:20-66`, `:107-118` | New movesets/boss kits = a table row. |
| **The physics seam (launch / bowling / parry / stagger) where Arthur always wins** | `Enemy.gd:185-209`, `:273-287`, `:236-243`, MAX_LAUNCH 2600 `:165` | This **is** the Musou power fantasy. |
| **`BattleMap.gd` base + thin subclass pattern** | `BattleMap.gd:53-99`, hooks `:119-150`; maps are 160-280 lines of config | A new region is cheap config, not new systems. |
| **`Campaign.gd` single-source-of-truth autoload** (ordered stages, unlock, persist, blurbs, finale) | `Campaign.gd:34-82`, `:92-207` | The **spine the world map builds on** — extend, don't replace. |
| **`Transition.gd` web-safe scene fade** | `Transition.gd:21-33,68-94` | Reusable for "travel to region" wipes. |
| **`ObjectiveManager` + 8 composable objectives** covering every Musou archetype | `ObjectiveManager.gd:16-29`; RepelWaves/DefeatOfficer/DefeatGeneral/HoldLine/ProtectBanner/ClearRoom/CaptureBases/Survive | Win/lose is a declarative list. |
| **`Breakable.gd` destruction base + modular hazards/terrain** (FireZone, WaterWheel, PressurePlate, TerrainZone) | `Breakable.gd:16-89`, `FireZone.gd`, `WaterWheel.gd:35-52`, `TerrainZone.gd:64-102` | Environmental gameplay is config + placement. |
| **Code-drawn unit art** (`scripts/art/`), incl. strong Arthurian bosses | `UnitArt.gd:11-25`; `ExcaliburArt`/`MordredArt`/`SorceressArt`/`BlackKnightArt` | The most "legendary"-looking layer; already themed. |
| **84-test headless CI net** with a uniform `*_VERDICT PASS` protocol | `.github/workflows/validate.yml` | A dense, binary regression signal for a safe rebuild. |
| **Procedural audio bus** (`Audio.gd` event → `SoundBank.gd` synth), ~30 call sites | `Audio.gd:26-31`, `SoundBank.gd:49-58` | Add spectacle centrally without touching gameplay. |

**Bottom line:** the architecture already satisfies the golden rules. The rebuild is additive
and re-tuning work, *not* a rewrite.

---

## 4. Weaknesses — what is BORING / UGLY / EMPTY / OFF-THEME (rebuild)

### 4.1 No world, no journey *(CRITICAL — the user's core complaint)*
The "campaign" is a `CanvasLayer` of `Button` cards in a `ScrollContainer`, grouped under three
text headers (`StageSelect.gd:149-264`). There is **no map of Britain, no region nodes, no path
between battles, no travelling marker** — nothing spatial anywhere in the repo. Picking a battle
feels like choosing a row from a list. `next_path` even **stops at section boundaries**
(`Campaign.gd:155-168`), so the legend never flows into anything; the "journey" exists only as
section headers + a blurb shown on the *next* battle's score screen.

### 4.2 Three Kingdoms is a first-class, visible theme *(CRITICAL — violates the directive)*
- A literal `— THREE KINGDOMS (BONUS) —` section with 5 playable maps and blurbs naming Lü Bu
  and Cao Cao (`Campaign.gd:28,66-81`; `StageSelect.gd:49,56`).
- **CJK glyphs** in titles/banners across all 5 maps — these **tofu (□□□)** in the
  gl_compatibility web font (`HuLaoGate.gd:28,101`, `RedCliffs.gd:27`, etc.). Off-theme *and*
  visually broken on the live build.
- The **faction colour vocabulary is Three-Kingdoms-native** (`wei`/`shu`/`wu`), and the
  *Arthurian* maps hack it — passing `faction='wei'` to get blue and `'wu'` to get red for
  Briton/Saxon banners (`Enemy.gd:118-120`; `FactionBanner.gd:11,21-26`; `MountBadon.gd:95,120`).
- `BattleMap.gd:2-3` still calls itself a *"Reusable Three-Kingdoms battle-map base."*
- 3 of 4 TK generals and all 5 TK troops are **orphaned** (only referenced by tests).

### 4.3 Every region looks the same flat slab *(CRITICAL — #1 "prototype" cause)*
`BattleMap` fills every floor with `ground_top Color(0.12,0.13,0.12)` → `ground_bottom
Color(0.17,0.15,0.13)` — a ~0.05 value delta that reads as **one flat near-black olive slab** —
and **no map subclass overrides it** (`BattleMap.gd:27-28,410-443`). Per-region identity is
*one translucent film rect + a few flank banners* (`Camlann.gd:207-226`, `MountBadon.gd:250-265`),
so Avalon, Badon, Camlann, the castle, and the ford all stand on the identical mud. The centre
of the field — where fighting happens — is bare dark ground (`BattleMap.gd:316-325`).

### 4.4 The flagship level draws graph-paper *(HIGH)*
Hold-the-Ford (`Battlefield.gd:404-408`) and Arena (`Arena.gd:48-55`) draw flat fill + 100px
white grid lines at alpha 0.03 — the universal "unfinished engine" look. **The live demo opens
on this.**

### 4.5 No lighting, no music, no ambience *(CRITICAL for atmosphere)*
- **No** `Light2D` / `CanvasModulate` / fog / day-night anywhere; braziers and torches draw
  flames that **cast no light** (`Brazier.gd:25-43`).
- **No looping audio at all** — no music, no ambient bed; the battlefield is silent between
  one-shot SFX (confirmed by grep; `SoundBank` players are all one-shot). This is the single
  biggest reason it feels airless.

### 4.6 Combat is tuned the *opposite* of a Musou power fantasy *(CRITICAL for the directive)*
- The drag-swing **hard-gates** below `hit_speed_min 420` to *push only, zero damage*
  (`StoneWeapon.gd:275-282`) and needs fast cursor circling to build torque — a high skill
  floor; a new player flailing **kills nothing**.
- Movement is deliberately slow (`max_speed 158`, `Arthur.gd:28`) and weapon states root him
  (SLAM_HOLD `0.14`, `Arthur.gd:211-224`); the script literally frames Arthur as *"a bit of a
  liability."*
- Stamina chokes everything (spin 28/s, swing 26/s vs. regen 24/s) and ends in a 0.45 crawl
  (`Arthur.gd:230`).
- Stone Flow's crescendo is **imperceptible** (+0.25 force at max, "small on purpose",
  `Impact.gd:181-192`) — no rising power high.
- The **"ultimate" is a narrow aimed beam** (`Beam`, `Arthur.gd:322-340`), not a
  screen-clearing rage burst — and it contradicts its own class doc, which describes a radial
  Shockwave screen-clear (`Arthur.gd:20-22`). The biggest moment is the quietest (it even
  borrows the `wall_crush` SFX).

### 4.7 Bosses fight like fodder *(HIGH)*
`General.gd` is 76 lines: it runs the *same* approach→strike brain plus one periodic war-cry
(`General.gd:31-49`). Bosses use the same generic `bash/pound/slash` as common heavies, with no
signature attack, phase, or duel framing, and **enter as a 1-unit wave in the mob lane** with no
entrance (`MountBadon.gd:184-198`). **Morgan le Fay — the witch — has no magic; she throws a
javelin** (`MorganLeFay.tscn` `moves=['javelin']`).

### 4.8 Formations are spawn-time only *(HIGH)*
`Formation.gd` arranges ranks then units immediately revert to individual steering; the `units`
array is collected *"for future break/morale logic"* that was never written
(`Formation.gd:27,34-43`). A shield wall is N shields that scatter — there is no "kill the
officer → the unit routs" loop, the heart of Musou crowd combat.

### 4.9 Authored Arthurian content sits orphaned *(HIGH — wasted work)*
- Troop scenes `BritonLevy/BritonArcher/SaxonAxeman/SaxonRaider/Merlin` are referenced by **no
  map** — maps spawn generic `LightSoldier/ShieldSoldier/…` and recolour them.
- Decor `RoundTable/CamelotBanner/Torch/SwordInStone(prop)` are referenced by **no map** — maps
  draw crude inline `draw_rect` gold blocks for banners and an inline sword instead
  (`SwordInStone.gd:138-148`, `DefendCamelot.gd:263-267`).

### 4.10 No triggers / story moments / exploration *(HIGH)*
- **No** trigger / checkpoint / dialogue / region-entered / story-moment system exists (grep
  returns only physics areas). In-battle narrative is two auto-popups (`_opening_banner` + "WAVE
  n/N"). Blurbs are shown at the wrong moment (next battle's blurb on the win screen; no
  pre-battle briefing).
- Props are **scattered at random** on the flanks with **no exploration rewards / hidden
  caches** (`BattleMap.gd:300-325`); the `drops_piece` hook exists but only drops ammo. There is
  zero reason to explore.

---

## 5. Preserve vs. Rebuild — the decision table

| Layer | Decision | Notes |
| --- | --- | --- |
| `Impact` / `Arthur` / `StoneWeapon` / `Enemy` / abilities / steering | **Preserve (re-tune up)** | Tune numbers for Musou; do not rewrite. |
| `BattleMap` / `Campaign` / `Transition` / `ObjectiveManager` / objectives | **Preserve (extend)** | The world map + journey build *on* these. |
| `Breakable` / `FireZone` / `TerrainZone` / `WaterWheel` / `PressurePlate` | **Preserve (place with intent)** | Reskin palettes; place deliberately + as exploration rewards. |
| `scripts/art/*` unit silhouettes | **Preserve** | Strongest visual asset; lean in for bosses. |
| 84-test harness + `validate.yml` | **Preserve (update constraint tests in-step)** | See §6. |
| Audio bus + `SoundBank` synth | **Preserve (extend)** | Add Music autoload, ambience, spatialisation. |
| **Three-Kingdoms theme** (sections, CJK, wei/shu/wu, orphaned generals/troops) | **Retire / reskin-in-place** | Reskin the 5 maps to Arthurian regions; migrate factions. |
| **StageSelect flat list** | **Rebuild** | → connected Map-of-Britain overworld. |
| **Region visuals** (flat floor, grids, no light/music) | **Rebuild** | Per-region palette + backdrop + mood + audio. |
| **Combat tuning / ultimate / boss kits / formation morale** | **Rebuild (on existing modules)** | Re-tune toward the Musou fantasy. |
| **Orphaned troop/decor scenes** | **Wire in** | Replace generic blobs + inline draw_rect. |
| **Triggers / story beats / exploration rewards** | **Build (minimal, native)** | Small data-driven additions; no addon. |

---

## 6. The regression trap (read before any change)

The Three-Kingdoms content is **load-bearing in CI**, so it cannot simply be deleted:

- **`stage_arthur_test.gd`** hard-codes the 5 TK maps as `GUARANTEED`, requires `entries >= 10`,
  and requires the `SEC_BONUS` block ordered after `SEC_TRIALS` (`:34-39,58,93-103`). *(critical)*
- **9+ tests `preload` TK scene paths at parse time** — deleting a TK scene breaks even the
  headless `--import` gate, not just an assertion (`guandu_test`, `red_cliffs_test`,
  `hulao_gate_test`, `changban_test`, `yellow_turban_test`, `generals_test`, `troops_test`,
  `map_decor_test`). *(critical)*
- **`beautify_test.gd`** asserts `wei=blue / shu=green / wu=red` faction colours (`:19,70-75`). *(high)*
- **`campaign_test.gd`** pins the stage-table shape and uses **Guandu as the always-open probe**
  (`:12-16,28-46`). *(high)*
- **`finale_audio_test.gd`** requires the finale = last `SEC_ARTHUR` stage (`:54-74`). *(medium)*

**Mandated strategy → reskin-in-place:** keep the TK scene *file paths* (`HuLaoGate.tscn` etc.),
rewrite their *content* to Arthurian, and **update the constraint tests in the same change**.
Add a "no Three-Kingdoms theme leaks" guard test to lock the directive in.

---

## 7. What this unlocks (the opportunity)

Because the TK maps are theme-only skins over `BattleMap`, each already **is** a distinct Musou
mission archetype we can keep and re-flag as an Arthurian region:

| TK map | Archetype (the reusable value) | Reskin target |
| --- | --- | --- |
| Hu Lao Gate | gate chokepoint + funnel-mud + officer guard + boss-finale wave | A Saxon/Pictish frontier fort with an Arthurian warlord boss |
| Red Cliffs | **the only FireZone showcase** + river bands + crossing nav | A burning Saxon longship raid on a tidal ford |
| Guandu | base-capture (Base + CaptureBases) + stockade ring | "Seize the beacon-forts" / burn the Saxon supply camps |
| Changban | **the only ProtectBanner escort showcase** | Escort fleeing folk / a wounded knight to Camelot |
| Yellow Turban | survival horde | A Pict woad warband or Morgan's night-host (distinct from Badon) |

Combined with the five existing legend maps (Stone → Badon → Camelot → Camlann → Avalon), the
strong boss art, the orphaned-but-finished Arthurian troops/decor, and the modular engine, the
raw material for a **legendary connected Arthurian Musou** is *already in the repo*. The work is
to **theme it, light it, connect it, score it, and tune it up** — see
[`creative_direction.md`](creative_direction.md) and [`world_rebuild_plan.md`](world_rebuild_plan.md).
