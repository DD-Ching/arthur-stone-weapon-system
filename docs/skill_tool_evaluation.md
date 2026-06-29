# Skill / Tool / Addon / Workflow Evaluation

*Evaluation of skills, MCP tools, Godot addons, asset sources, and Claude Code workflows for the
Arthurian Musou rebuild. Decisions weighed against the project's hard constraints: Godot 4.3.0 on
CI (local 4.7), **single-threaded gl_compatibility web export**, **all art drawn in code via
`_draw`**, **procedural audio**, a **bespoke 84-test headless harness**, **zero third-party
addons today**, and the golden rule "**prefer native Godot over plugins.**" Format per candidate:
name · purpose · why it may help · ACCEPTED/REJECTED · reason · install/usage.*

---

## TL;DR

The biggest accelerators are **already in this session** (skills + MCP): the multi-agent
**Workflow** orchestrator, **deep-research**, **code-review**/**simplify**, **run**/**verify**,
and **claude-in-chrome** for live web-build/tofu checks. The only genuinely tempting *external*
addition is a narrative tool, and we **build that natively** (a code-drawn `StoryCard`) to stay on
4.3 and zero-deps. Almost every imported-asset / engine-addon pipeline is **rejected on
principle**, because this project draws all art in code and already has a working QA harness.

---

## A. Claude Code skills & MCP (session-native) — mostly ACCEPTED

| Tool | Purpose | Decision | Reason | Usage |
| --- | --- | --- | --- | --- |
| **Workflow orchestrator** | decompose a feature across parallel agents, integrate centrally | **ACCEPTED** | Already the operating model (this audit was one); the phased rebuild is exactly this shape. Matches the user's `multi-agent-feature-workflow` memory. | Per-phase fan-out; integrate on `dev`; gate on `validate.yml`; ship on `main`. |
| **deep-research** | fan-out web research + adversarial verification + cited report | **ACCEPTED** | Best way to gather authentic Arthurian lore (regions, knights, villains, Saxon foes) + Musou design references to ground the world/story without guessing. | `Skill deep-research` with a narrowed question, e.g. *"Arthurian regions + named knights/villains suitable as Musou stages/bosses, with sources."* |
| **code-review** | review the working diff for bugs + reuse cleanups | **ACCEPTED** | The rebuild lands large diffs across agents; protect the 84-test gate before `dev`→`main`. | `/code-review` (medium fast / high or ultra for big integration merges); `--comment` or `--fix`. |
| **simplify** | reuse/efficiency/altitude cleanup (no bug hunt) | **ACCEPTED** | Enforces build-once-reuse-many — catches copy-paste level/enemy logic during a fast rebuild. | `/simplify` after a feature lands, paired with `/code-review`. |
| **run** + **verify** | launch the real app, observe a change working | **ACCEPTED** | CLAUDE.md rule 6 (verify before claiming done) for gameplay/visual changes headless tests can't prove. | `Skill run` / `verify` for desktop Godot; pair with claude-in-chrome for web. |
| **claude-in-chrome (MCP)** | drive the live Chrome web build; screenshot; read console | **ACCEPTED** | *The* tool for the atmosphere/polish goals and the **web-font tofu gotcha** (▶ 🔒 ★ box out in the gl_compatibility fallback) — only the live Pages build reveals these; also catches JS/console errors headless misses. | `ToolSearch select:mcp__claude-in-chrome__*`; navigate to the Pages URL; screenshot UI/HUD; `read_console_messages`. |
| **update-config** | settings.json hooks/permissions | **ACCEPTED (minor)** | Optional post-edit hook to auto-run the matching verdict test; allowlist common godot/git commands to cut friction. | `Skill update-config`; e.g. a PostToolUse hook running the relevant `tests/*.tscn`. |
| **fewer-permission-prompts** | allowlist common read-only Bash/MCP calls | **ACCEPTED (minor)** | A long rebuild session runs many `godot --headless` tests; cut the prompt friction once. | Run once; commits an allowlist to `.claude/settings.json`. |
| **Playwright (MCP)** | scripted headless browser automation | **REJECTED** | Redundant with claude-in-chrome for live verification; adds a second browser stack. Reconsider only for unattended screenshot-in-CI. | n/a |
| **Figma (MCP)** | design-to-code / code-to-design | **REJECTED** | Violates the all-code `_draw` art principle — there is no imported-asset/component pipeline; HUD/menus are GDScript. Mockups wouldn't translate. | n/a |
| **loop / schedule** | recurring/cron task execution | **REJECTED** | No polling/recurring need for a hands-on creative rebuild; would add noise. | n/a |
| **Supabase / Vercel / Gmail / Linear / claude-api / security-review** | backend/email/issue/LLM/security | **REJECTED** | Off-domain: offline single-player Godot game, no backend/network/LLM/sensitive surface. | n/a |

---

## B. Native Godot capabilities (built-in, no dep) — ACCEPTED where useful

| Capability | Purpose | Decision | Reason | Usage |
| --- | --- | --- | --- | --- |
| **`CanvasModulate`** | per-region time-of-day / mood tint | **ACCEPTED** | Single node, near-zero cost, web-safe; dramatically differentiates atmosphere (dawn/dusk/mist). A pillar of the visual rebuild. | One per region scene; set `color`. |
| **`Light2D` (optional)** | soft glow pools for fires/braziers | **ACCEPTED (light touch)** | Native; but gl_compatibility 2D lighting can be finicky on web — prefer a **code-drawn additive radial glow** first; use `Light2D` only if the draw approach is insufficient and it verifies on the live build. | Test on Pages before committing. |
| **`FastNoiseLite`** | procedural variation (ground tint, fog density, scatter) | **ACCEPTED** | Built-in, web-safe; seeds varied region floors/scatter deterministically without imported assets. | Deterministic per region; render via `_draw`. |
| **`AudioStreamPlayer` (looping) + bus layout** | music + ambience beds | **ACCEPTED** | Plain looping players on Music/Ambience buses are single-threaded and web-safe — the basis of the new `Music` autoload. | New `scripts/Music.gd` autoload; loop a procedural/synth bed; intensity layers. |
| **`Tween` / `AnimationPlayer`** | game-feel juice (pops, eases, hit-stop) | **ACCEPTED** | Built-in, web-safe; layer onto the Impact feedback for Musou-grade juice without deps. | `create_tween()` for scale/colour pops on KO/combo/ultimate. |
| **`TileMapLayer` (4.3+)** | tile-based ground authoring | **REJECTED (conditional)** | Native, but a `TileSet` needs a texture atlas (imported art), conflicting with all-code `_draw`. Prefer code-drawn ground/parallax. Revisit only if a programmatic 1px TileSet is acceptable to the lead. | n/a unless art principle relaxed |

---

## C. External Godot addons — mostly REJECTED (prefer native)

| Addon | Purpose | Decision | Reason | Install/usage |
| --- | --- | --- | --- | --- |
| **Dialogue Manager** (Nathan Hoad, MIT, pure GDScript) | branching dialogue editor + runtime | **REJECTED → native instead** | Directly addresses the narrative gap and is web-safe in principle, **but** current versions target Godot **4.4+ (v3.x) / 4.6+ (v4)** while CI is pinned at **4.3.0**, and it cuts against prefer-native/zero-deps. We build a **native code-drawn `StoryCard`** instead. (Only revisit a 4.3-compatible v2.x if the native card proves insufficient.) | n/a (native `StoryCard.gd`) |
| **GUT / gdUnit4** (test frameworks, MIT) | GDScript unit testing | **REJECTED** | A working **84-test headless harness** with a clear `*_VERDICT PASS` convention already gates CI; adopting these is redundant churn and risks destabilising the gate. Extend the existing runner. | n/a |
| **Phantom Camera** | advanced 2D/3D camera rigs | **REJECTED** | `GameCamera.gd` already does follow + decaying shake + kick natively; an addon over-engineers against prefer-native. | n/a |
| **Beehave / LimboAI** | behaviour trees / state machines for AI | **REJECTED** | `Enemy.gd` is a working config-driven brain + data-driven abilities; LimboAI also needs a custom engine module that would break the stock 4.3 web-export template. Don't rewrite working AI. | n/a |

---

## D. Asset sources — REJECTED on principle

| Source | Purpose | Decision | Reason |
| --- | --- | --- | --- |
| **Kenney (CC0)** | free sprites/tiles/audio | **REJECTED** | All art is drawn in code via `_draw` (ARCHITECTURE.md); audio is procedural (`SoundBank.gd`). Importing sprites would fork the visual language. Licence is fine (CC0); the *principle* is the blocker. |
| **OpenGameArt** | free art/audio (mixed licences) | **REJECTED** | Same all-code principle; plus mixed/unclear licences add review burden for no gain here. |
| **Aseprite / texture atlases** | pixel art pipeline | **REJECTED** | No imported-art pipeline exists; conflicts with `_draw`. |

> If the lead ever **relaxes the all-code art rule**, the first reconsideration would be Kenney
> CC0 (clean licence) + `TileMapLayer`. Until then, every region's identity comes from code-drawn
> palette + backdrop + mood (see [world_rebuild_plan §4](world_rebuild_plan.md)).

---

## E. Recommended *new* additions (native, low-risk)

| Addition | Purpose | Decision | Notes |
| --- | --- | --- | --- |
| **`gdtoolkit` (gdlint + gdformat)** — pip CLI | static lint/format for GDScript | **ACCEPTED** | Pure Python CLI; touches no runtime, web build unaffected. Catches the documented `:=`-on-`Variant` inference traps across high-volume parallel-agent GDScript **before** a CI round-trip. **Requires user OK to `pip install`** (see below). | `pip install gdtoolkit`; add an **advisory** `gdlint scripts/ tests/` step to `validate.yml`; run `gdformat` locally. |
| **Native `StoryCard.gd`** | between-battle / pre-battle narrative cards | **ACCEPTED** | The recommended narrative layer — stays on 4.3, zero deps, matches all-code art, reuses `Transition` + menu patterns. One component drives every story beat. ASCII+colour only. | New `scripts/ui/StoryCard.gd` sequenced by `Campaign` between stages. |
| **`Music.gd` autoload + bus split** | music + ambience + ducking | **ACCEPTED** | Fills the "silent battlefield" gap; single-threaded, web-safe; reuses the synth approach. | New autoload sibling of `Audio`; Music/SFX/Ambience buses. |

---

## F. Permission requests (need user approval before installing)

Only **one** optional install is proposed; everything else is native or session-native:

> **`gdtoolkit`** (GDScript linter/formatter) — *optional, advisory.*
> Command: `pip install gdtoolkit`
> Reason: pre-empt the `:=`/Variant inference traps across parallel-agent GDScript and keep style
> consistent, before each CI round-trip. It runs only as an advisory CI step + local formatting;
> it does **not** ship in the game and cannot affect the web build.
> **If you'd rather stay strictly zero-tooling, we skip it** — the 84-test `--import` gate already
> catches parse errors, just later in the loop.

No other installs are requested. No game dependencies are added.

---

## G. Cross-cutting guidance (carry into every task)

- **Web-font tofu gotcha:** fancy glyphs (▶ 🔒 ◆ ★ ↑↓) box out in the gl_compatibility fallback
  font. All new UI/world-map/dialogue text is **ASCII + colour**, verified on the **live Pages
  build** via claude-in-chrome (headless tests only assert "`_draw` runs without error," never
  appearance).
- **Reskin-in-place, not delete:** 9+ tests `preload` the Three-Kingdoms scene paths; deleting
  them breaks the `--import` gate (see [critique §6](current_game_design_critique.md)).
- **Extend the test harness, don't replace it:** every new system gets a `*_VERDICT PASS` test +
  a `validate.yml` step (`battle_map_test.gd` is the cleanest template).
- **Prefer native; verify on web:** every accepted tool above is native or session-native; the
  one external CLI (`gdtoolkit`) never enters the build.
