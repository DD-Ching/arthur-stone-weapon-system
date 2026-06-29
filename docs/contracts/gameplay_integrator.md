# Contract — Gameplay Integrator

*See [game_director.md](game_director.md) for the contract format and the shared-file rule.*

## Mandate
Preserve the working combat core and **re-tune it into a Musou power fantasy**; make bosses feel
like fights; wire formation morale; reconnect the existing mechanics into the reskinned regions
and balance the horde. Own the *feel and balance*, not the world structure or the rendering.

## Owned systems
- **Combat re-tune** (numbers, via `Impact` where possible): swing accessibility (assisted/auto-
  swing reusing the touch auto-torque; soften the `hit_speed_min` zero-damage gate), mobility,
  weapon-state rooting, stamina balance, **Stone Flow crescendo** (felt escalation).
- **The true rage ultimate**: revive the radial `Shockwave` screen-clear (the `Arthur.gd:20-22`
  intent) at gauge-dump scale, with reserved top-tier shake/zoom; `Beam` optional secondary.
- **Spin as a horde-mulcher** while Flow is high; **KO-milestone → escalating screen juice**.
- **Boss differentiation**: new `AbilityLibrary` rows (`spell_bolt`/`arrow_rain`/`whirlwind`/
  `ground_quake`), per-general signature kits, phase/enrage, entrance framing; **Morgan's sorcery**.
- **Formation cohesion + morale** (`Formation.gd`): ranks hold; **officer falls → unit routs**
  (scale the existing banner-death stun).
- **Horde balance & rosters**: `_build_wave_spawner` counts/density/timing tuning; cavalry-as-Ability.
- **Environmental gameplay**: exploration caches (a `Breakable` config dropping health/Flow/relic),
  new `TerrainZone` rule branches (sacred-water heal, cursed bog); promote `WaterWheel`/
  `PressurePlate` into placeable region set-pieces.

## MAY modify
- `scripts/Arthur.gd`, `scripts/StoneWeapon.gd`, `scripts/Impact.gd`, `scripts/Beam.gd`,
  `scripts/Shockwave.gd`, `scripts/GameCamera.gd` (juice tuning), `scripts/Enemy.gd` (AI/balance),
  `scripts/Cavalry.gd`, `scripts/WarCart.gd`, `scripts/General.gd`, `scripts/formations/Formation.gd`,
  `scripts/abilities/*`, `scripts/terrain/TerrainZone.gd` (new rule branches), `scripts/props/*`
  (cache configs/tuning), `scripts/WaterWheel.gd`, `scripts/PressurePlate.gd`.
- `scripts/maps/*.gd` — **tuning hooks only**: `_build_wave_spawner` counts/density/timing, boss
  config, set-piece placement. *(Not titles/blurbs/labels, not ground palette/`_draw`.)*
- Boss/troop `.tscn` exports under `scenes/generals/`, `scenes/villains/`, `scenes/troops/`,
  `scenes/arthur/` (stats/abilities/look — coordinated with World Designer's roster choices).

## MUST NOT modify
- World-map/UI structure: `Worldmap.gd`, `StageSelect.gd`, `ScoreScreen.gd`, `Campaign` schema,
  autoloads, `project.godot` (Architect).
- Story/region content & data (World Designer); ground palettes, `RegionBackdrop`, decor `_draw`,
  `scripts/art/*` silhouettes (Visual Polish).
- `tests/**`, `.github/**` (QA).

## Public API it provides / consumes
- **Provides:** the tuned combat feel; boss Ability rows; formation morale behaviour; cache/terrain
  set-pieces other roles place.
- **Consumes:** `Impact.resolve_hit`/`explode`/`collide`, the `Shockwave`/`Beam` scenes, the
  `Ability` table, the `generals`/`officers` groups + `GeneralHealthbar`, `Audio.play` events
  (new ult roar / stingers coordinated with Architect's Music buses).
- **Signals:** consumes `Impact.flow_changed`/`kills_changed`/`impact_fx`; may emit
  `checkpoint_reached` for music intensity steps (with Architect).

## Test checklist
- [ ] `swing_smoke_test`/`impact_test`/`spin_test`/`musou_test`/`behavior_test`/`battle_test`
      green after re-tune (update expected numbers in-step where intentional).
- [ ] New `musou_feel_test` (a weak/slow swing still scores; ultimate clears a radius; Flow
      escalates force) and `formation_morale_test` (officer death routs the unit) green.
- [ ] Boss kits: each named general fields its signature Ability; `boss_healthbar_test`/
      `generals_test` green against reskinned generals.
- [ ] Web perf: `active_cap`/mobile density/debris budgets respected; no frame collapse on a slam/ult.
- [ ] Verify on the **real app** (run/verify skills) that the power fantasy lands — not just headless.

## Rollback plan
- Combat changes are concentrated in `Impact` constants + a few weapon/hero numbers; revert the
  tuning commit to restore prior feel. The ultimate revival is additive (the `Beam` path remains);
  formation morale is gated behind a flag so it can be disabled without reverting the spawn logic.
