# Contract — Visual Polish

*See [game_director.md](game_director.md) for the contract format and the shared-file rule.*

## Mandate
Make the world **look like mythic Britain** and read clearly in a swarm — per-region identity,
atmosphere, lighting, decoration, and boss legibility — all **code-drawn, web-safe, ASCII+colour**.
Kill the "flat prototype" look. Own the *look*, not the logic, data, or combat tuning.

## Owned systems
- **Per-region ground palettes** — override `ground_top`/`ground_bottom` per map (table in
  [world_rebuild_plan §4](../world_rebuild_plan.md)).
- **`RegionBackdrop` silhouettes** — author the per-region horizon `_draw` (castle, stones, fleet,
  misted hills) into the Architect-provided node scaffold.
- **`CanvasModulate` mood** per region (dawn/dusk/mist) + **additive radial glow** for
  `Brazier`/`Torch`/`FireZone` + an **`AmbientDrift`** particle node (generalised from
  `LadyOfLake:269-272`).
- **Decor placement & reskin**: place the orphaned `CamelotBanner`/`RoundTable`/`Torch`/
  `SwordInStone` prop; delete inline `draw_rect`/`draw_line` banner+sword stand-ins; reskin
  `ClayPot`→Arthurian vessel; ground-scatter decals to fill empty centres.
- **Kill the grids**: replace `Battlefield.gd`/`Arena.gd` graph-paper with the gradient+dapple floor.
- **Unit/boss art**: `scripts/art/*` tweaks for bigger boss silhouettes + faction-gold auras +
  muster-rings + name-card visuals.
- **`StoryCard`/Worldmap visual style** (copy/layout owned by World Designer/Architect).

## MAY modify
- `scripts/decor/*`, `scripts/art/*`, `scripts/ui/Vignette.gd`, `scripts/world/RegionBackdrop.gd`
  (visuals), `scripts/props/*` `_draw` (reskin only).
- `scripts/maps/*.gd` — **theme hooks only**: `ground_top`/`ground_bottom`, `_build_decor`,
  `_region_backdrop`/`_region_mood`, and `_draw` *theming* layers. *(Not titles/blurbs/objectives/
  wave counts/boss tuning.)*
- `scripts/Battlefield.gd` / `scripts/Arena.gd` — **background `_draw` only** (grid→gradient).
- `scripts/maps/BattleMap.gd` — **the ground/dapple/scatter `_draw` only**, coordinated with
  Architect (who owns the base orchestration & hook signatures).

## MUST NOT modify
- Physics/collision/gameplay logic, wave data, objectives, AI, combat numbers, the ultimate
  (Gameplay Integrator / Architect).
- Story/region content & data (World Designer); Campaign schema, Worldmap logic, autoloads,
  `project.godot` (Architect).
- `tests/**`, `.github/**` (QA).

## Public API it provides / consumes
- **Provides:** the visual fill for Architect's `_region_backdrop()`/`_region_mood()` hooks; the
  reusable `RegionBackdrop`/`AmbientDrift`/glow modules; region palettes.
- **Consumes:** the hook signatures + `RegionBackdrop` scaffold (Architect); the region roster +
  biomes (World Designer).

## Test checklist
- [ ] All `*_art_test` and `beautify_test` green (no `_draw` errors after richer art).
- [ ] New `region_theme_test` (each map sets a distinct `ground_top`/`ground_bottom`).
- [ ] **Live build (QA + claude-in-chrome):** each region visibly distinct; no tofu; fires/braziers
      glow; centres no longer bare; no graph-paper grid anywhere.
- [ ] Dirty-redraw / off-screen-skip / `MAX_LABELS` / `DEBRIS_BUDGET` caps still respected (web perf).
- [ ] No new imported assets (all-code `_draw` only).

## Rollback plan
- Visuals are `_draw`/palette/decor-placement changes with no logic impact; revert the commit and
  the region falls back to the base gradient floor (still functional, just plainer). Art tweaks are
  per-file in `scripts/art/` and revert independently.
