# Contract — Game Director

*Role contracts govern the multi-agent rebuild so parallel work doesn't collide. Each lists owned
systems, files it MAY modify, files it MUST NOT modify, the public API/signals it provides or
consumes, dependencies, a test checklist, and a rollback plan. See the
[world rebuild plan](../world_rebuild_plan.md) for phases and the shared-file rule.*

## Mandate
Hold and protect the vision: a **Musou power fantasy** in a **strictly King-Arthur** world that
feels like a **connected journey**. Decide what is fun, what is boring, what ships, and the
acceptance bar. Arbitrate scope and cross-role conflicts. **Does not write game code.**

## Owned systems
- The creative vision & the **five pillars** (JUGGERNAUT · LIVING BATTLEFIELD · THE JOURNEY ·
  LEGENDARY MOMENTS · DISCOVERY) — [creative_direction §5](../creative_direction.md).
- Phase scope/sequencing and the per-phase **exit/acceptance gates**
  ([world_rebuild_plan §6](../world_rebuild_plan.md)).
- The "no Three-Kingdoms theme, no self-sabotaging combat" invariants.

## MAY modify
- `docs/creative_direction.md`, `docs/current_game_design_critique.md`,
  `docs/world_rebuild_plan.md`, `docs/contracts/*.md`, `docs/final_world_rebuild_report.md`.

## MUST NOT modify
- Any `scripts/**`, `scenes/**`, `tests/**`, `project.godot`, `.github/**`. (Direction is
  expressed through docs + review sign-off, not commits to code.)

## Public API it provides
- **Acceptance gates** per phase (a checklist other roles must pass before `dev`→`main`).
- **Conflict rulings** when two roles contend for a file or a design call.
- The **directive invariants** the QA `no_tk_leak_test` and `musou_feel_test` encode.

## Consumes
- The audit reports, the live build (via QA), and each role's phase deliverables.

## Dependencies
- All roles report phase completion here for sign-off. Director unblocks QA's final report.

## Test checklist (sign-off, not authored here)
- [ ] Live build boots to the Map of Britain; a region reads as a *place* within 10s.
- [ ] Combat reads as *"nothing can stand in front of this stone"* within 30s.
- [ ] No Three-Kingdoms theme anywhere player-facing; no tofu glyphs on the live build.
- [ ] Each shipped phase meets its [plan §6](../world_rebuild_plan.md) exit criteria.
- [ ] All five pillars are demonstrably served before the finale tag.

## Rollback plan
- Direction is doc-only; revert the doc change. If a *shipped phase* fails its gate, the Director
  rules to revert that phase's `dev` merge (git revert of the phase tag) rather than patch
  forward under time pressure.
