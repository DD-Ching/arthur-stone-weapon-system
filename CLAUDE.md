# CLAUDE.md — orientation for AI sessions

Read this first. It is the fast path to being productive in this repo without
re-reading everything. Pair it with [`docs/MEMORY.md`](docs/MEMORY.md) (compact project
memory) and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) (how the code is wired).

## What this is

**Arthur Stone Weapon System** — a top-down 2D physics-combat prototype in **Godot 4**
(authored against 4.3; CI runs 4.3.0). Arthur failed to pull the sword from the stone,
so he lifted the **whole stone** — a heavy, absurd physics weapon. He is overwhelmingly
strong; the challenge is *battlefield pressure*: formations, terrain, objectives,
stamina, timing, and protecting allies. The current playable level is **Hold the Ford**,
a river crossing defended against five waves of raiders.

Live demo: <https://dd-ching.github.io/arthur-stone-weapon-system/>

## The golden rules

1. **Do not rewrite the game from scratch.** Build incrementally on the working version.
2. **Keep the browser build working.** The web export is single-threaded (GitHub Pages);
   don't add threads or anything that breaks the GL-compatibility/web export.
3. **Build once, reuse many.** No copy-paste enemy/terrain/level logic. New enemies are a
   `.tscn` config of `Enemy.gd`; new terrain is a `TerrainZone` you place; shared force
   goes through `Impact`. If a shared module improves, everything using it improves.
4. **Prefer config + placement over new code.** Tune exported parameters; place reusable
   scenes. Avoid one-off hard-coded level rules inside unrelated scripts.
5. **Don't over-engineer.** Smallest stable slice that works. Lean on Godot physics.
6. **Verify before claiming done.** Run the headless tests (below); for gameplay/visual
   changes, capture a frame or run the live build and check for console errors.

## Workflow

- Branches: **`dev`** for active work, **`main`** for stable releases. Merge with
  `git merge --no-ff --no-commit dev` then `git commit -F -` (NOT `git merge -F -`).
- Tag semver (`vMAJOR.MINOR.PATCH`); a new MINOR lands a playable milestone on `main`.
  Push tag, let CI + Pages run, then `gh release create`.
- End commit messages with the Co-Authored-By trailer; end PR bodies with the Claude Code
  line (see the harness instructions).

## Tests (gate CI — keep them green)

Headless, on Godot 4.3. Run one with:
`godot --headless --path . res://tests/<Name>.tscn --quit-after 600` and grep the
`*_VERDICT PASS` line. **80 headless tests** now gate CI
(`.github/workflows/validate.yml`) — the original `SwingSmokeTest` / `BehaviorTest` /
`ImpactTest` / `BattleTest` / `SpinTest` / `FordTest` / `HoldFordTest` plus the
formations / objectives / abilities / nav / touch / challenge-room / module suites. Local
dev Godot is newer (4.7); CI is the source of truth (4.3.0).

`--quit-after` counts *idle* frames, which outrun physics frames in headless — use 600,
not a small number, or a test's report (fired on a physics-frame counter) won't run.

## GDScript gotchas (these have bitten us)

- `:=` type inference **fails on `Variant`** — a loop var over a `const`/untyped array,
  or `Object`-typed params, or `load().instantiate()`. Use an explicit type (`var x: float =`)
  or untyped `var`.
- `--quit-after` idle-vs-physics frames (above).
- `Date.now()`/`randf()` are fine in *game* runtime; only Workflow *scripts* restrict them.

## Where things live / where to add things

| You want to add a… | Do this |
| --- | --- |
| **New enemy type** | New `scenes/<Name>.tscn` using `scripts/Enemy.gd`, tune exports (mass, speed, attack, shield, `team`). Only write a script if it needs a unique brain (see `Cavalry.gd`). |
| **New terrain rule** | Place a `scenes/terrain/*Zone.tscn` (`TerrainZone.gd`) and set its rule exports, or add a new rule branch in `TerrainZone.gd`. |
| **New tunable** | Add an `@export` (per-instance) or a `const` in `Impact.gd` (global combat numbers). |
| **New audio** | Call `Audio.play("event", pos)`; add a procedural voice in `SoundBank.gd`. |
| **New level** | A `Node2D` scene that places terrain zones, props, spawn points, formations, and a banner/goal; keep logic thin (see `Battlefield.gd`). |
| **New challenge level** | A self-contained `scenes/rooms/<Name>.tscn` + `scripts/rooms/<Name>.gd` that reuses Arthur / `Enemy` / props / `Impact` / objectives (see `BowlingRoom`). |
| **New objective** | A `scripts/objectives/<Name>Objective.gd` (extend `Objective`); set `required`/`completable` and register it with the `ObjectiveManager` (see `ProtectBannerObjective`, `ClearRoomObjective`). |
| **New formation** | A `scenes/formations/<Name>.tscn` config of `Formation.gd` — tune the front/support/commander roster + spacing (see `ChargeGroup`). |

Folder map and system list: [`docs/MEMORY.md`](docs/MEMORY.md). Refactor batches and
status: [`docs/BATCH_PLAN.md`](docs/BATCH_PLAN.md).
