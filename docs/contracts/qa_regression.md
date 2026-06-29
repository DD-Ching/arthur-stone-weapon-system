# Contract — QA / Regression

*See [game_director.md](game_director.md) for the contract format and the shared-file rule.*

## Mandate
Guard the 84-test gate, author new tests for every new system, verify the **live** web build
(things headless can't prove — tofu, atmosphere, console errors), and write the final report.
Own the *safety net and verification*; touch no gameplay/world/art logic.

## Owned systems
- `tests/**` (the headless `*_VERDICT PASS` harness) and `.github/workflows/validate.yml` /
  `pages.yml` (CI), including the optional advisory `gdlint` step.
- **Constraint-test updates** that the rebuild requires (in the same change as the breaking edit):
  `stage_arthur_test`, `campaign_test`, `beautify_test`, `finale_audio_test`, and the **9 preload
  tests** (`hulao_gate`/`red_cliffs`/`guandu`/`changban`/`yellow_turban` map tests +
  `generals_test` + `troops_test` + `map_decor_test`) repointed to the reskinned scenes.
- **New tests** (one per new system + a `validate.yml` step each): `worldmap_test`,
  `region_theme_test`, `story_trigger_test`, `reach_landmark_test`, `music_test`,
  `formation_morale_test`, `musou_feel_test`, **`no_tk_leak_test`** (directive guard).
- **Live verification** via claude-in-chrome on the Pages build; the run/verify desktop checks.
- `docs/final_world_rebuild_report.md`.

## MAY modify
- `tests/**`, `.github/**`, `docs/final_world_rebuild_report.md`. Run (read-only to game code):
  `godot --headless --path . res://tests/<Name>.tscn --quit-after 600` + the live build.

## MUST NOT modify
- Any `scripts/**` or `scenes/**` gameplay/world/art/logic (other roles fix the code; QA only
  changes tests, CI, and reports). If a test reveals a code bug, file it to the owning role.
- `project.godot` (Architect) except via coordination if a test rig needs an input.

## Public API it provides / consumes
- **Provides:** the binary CI verdict per change; the live-build verification report (screenshots,
  console log, tofu/atmosphere checklist); the directive-guard `no_tk_leak_test`.
- **Consumes:** each role's "this change touches test X" note (so the constraint test is updated in
  the same commit); the `*_VERDICT PASS` convention; `battle_map_test.gd` as the template.

## Test checklist (the standing gate)
- [ ] `godot --headless --path . --import` parses clean (no broken/deleted preloaded scenes).
- [ ] All pre-existing module tests (Impact/Enemy/Ability/Objective/HUD/Transition/etc.) stay green.
- [ ] Every new system has a `*_VERDICT PASS` test + a `validate.yml` step (`--quit-after 600`).
- [ ] `no_tk_leak_test` green: no `三國`/`wei`/`shu`/`wu`/`Lü Bu`/`Cao Cao`/`THREE KINGDOMS`
      strings in `Campaign` stages, section labels, or map titles/labels.
- [ ] **Live Pages build**: boots to the Map of Britain; each region visibly distinct; music +
      ambience audible; no tofu glyphs; no console errors; the ultimate clears the screen.
- [ ] `total tests == grep -c '_VERDICT PASS' validate.yml == count(tests/*_test.gd)` (no orphans).

## Rollback plan
- Tests/CI are non-shipping; revert a bad test commit freely. If a phase merge fails the live
  verification after passing headless, QA flags the Director to revert the phase tag (per
  [game_director.md](game_director.md)) rather than disable tests to go green.
