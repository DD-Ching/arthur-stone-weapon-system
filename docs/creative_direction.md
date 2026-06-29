# Creative Direction — *The Stone King*

*The high-level vision for the rebuilt game. Authored by the lead (game director) from the
project audit, the user's directive, and the existing content. Inspired by Arthurian legend —
not a fixed story dictated by the user. Companion docs: the
[critique](current_game_design_critique.md) (what to keep/change) and the
[world rebuild plan](world_rebuild_plan.md) (how to build it).*

---

## 0. One line

> **Play like *Dynasty Warriors*. Feel like *Excalibur*.**
> You are Arthur — the boy who could not draw the sword, so he tore the **whole stone** from the
> earth. Carry that impossible weight across a Britain at war, shatter Saxon hosts and traitor
> ranks like a force of nature, and live the legend from the churchyard where you claimed the
> stone to the misted shore of Avalon.

This is a **Musou (無雙) power fantasy wearing the clothes of Arthurian myth.** Both halves are
non-negotiable: the *feel* is one juggernaut versus an army; the *theme* is strictly King Arthur.

---

## 1. Genre contract (the feel we owe the player)

We are a **Warriors-style action game.** That means, concretely:

1. **Overwhelming power, *aimed*.** The challenge is never "can I hurt them?" — it's *where* and
   *when*. The audit found the opposite (a high skill floor; weak swings do nothing): we re-tune
   so the stone **always** shreds, and mastery is about positioning, terrain, and timing, not
   fine-motor cursor circling.
2. **A living army, not a crowd of clones.** Ranks that hold and **rout when their officer
   falls**; visible officers and named generals to hunt; cavalry wedges; ranged volleys to
   deflect. Cutting toward the officer is the core tactical pulse.
3. **Escalating spectacle.** A rampage *crescendos* — KO milestones (RAMPAGE! → ONE-MAN ARMY!)
   pulse bigger shake/zoom/sound; Stone Flow visibly ramps power; the **rage ultimate is a
   true screen-clearing burst** with reserved top-tier juice and a signature roar.
4. **Generals are *events*.** A named boss arrives with a name-card, a cleared arena, a signature
   kit, and a duel rhythm (telegraph → clash → opening), not as another mob with a big HP bar.

If a change makes Arthur feel *weaker, fiddlier, or slower*, it is wrong, regardless of how
"realistic" the heavy-stone conceit makes it. **Power is the point.** Weight is *flavour on top
of* power, never a tax that cancels it.

> Note: this is a deliberate re-pointing of the original "power vs. control / Arthur is a
> liability" prototype framing. We keep the unique pendulum *identity* and the heavy-stone
> *fantasy*; we drop the self-sabotage.

---

## 2. Theme contract (the world we owe the player)

**Mythic Britain — the matter of Arthur.** Lances and longships, hill-forts and holy water,
treachery and destiny. Reference register: Malory by way of *Excalibur* (1981) — rain-bright
steel, banners in the mist, a land that is itself a character. **Zero** Three-Kingdoms residue:
no 三國, no Lü Bu/Cao Cao, no wei/shu/wu, no CJK glyphs in player-facing text.

**Factions:**

| Faction | Who | Colour (existing) | Role |
| --- | --- | --- | --- |
| **Camelot / Pendragon** | Arthur, the Round Table, Briton levies | regal gold `(0.92,0.78,0.30)` | the player's host (allies) |
| **Saxons** | Cerdic's invaders | moss green `(0.40,0.46,0.27)` | the external war (Acts I–II) |
| **The Rebellion** | Mordred, Morgan, the Black Knight, turncoat knights | rebel purple/black `(0.52,0.33,0.60)` | the internal fall (Act III) |
| **Picts / the Old North** *(new)* | woad raiders, painted skirmishers | cold blue-grey | a wild frontier flavour (reskinned horde) |
| **The Fae / Avalon** *(new, light touch)* | wraiths, the Lady's water | spectral cyan | the mythic edge (Avalon, Morgan's magic) |

The faction colour vocabulary is migrated from `wei/shu/wu` to these names (one shared source);
the bespoke **Pendragon red-dragon banner** (`CamelotBanner`) becomes the game's single royal
motif, replacing the inline gold rectangles.

---

## 3. The world: Logres, a connected map of Britain

The flat menu becomes a **hand-inked parchment map of Britain (Logres)** — the new boot scene.
Battles are **places on a road**, lit as you clear them, with Arthur's banner-marker travelling
the line between them. This is the single biggest fix for "random separate levels / no journey."

**The land, west-to-east, south-to-north (suggested layout):**

```
                 ( the misted mere )
                       AVALON ✦ ────────────────╮
                          │                      │ (passage, finale+1)
   MOUNT BADON ▲          │        CAMLANN ✗ ────╯
      (great victory)     │       (the last field)
            ╲             │          ╱
             ╲     CAMELOT ♜ ───────╱   ← hub: castle + Training Yard
              ╲     (crown & siege)
   THE MARCHES ⚔ ── THE BURNING FORDS 🜂 ── THE LONG ROAD ⛟
   (frontier war: fort / forts / night-host)
              ╲
        THE CHURCHYARD ✟  ← start (claim the stone)
```

**Regions** (each a distinct biome + palette + backdrop + mood + ambience — see
[world_rebuild_plan §4](world_rebuild_plan.md)):

| Region | Source map | Biome / mood | Premise (environmental story) |
| --- | --- | --- | --- |
| **The Churchyard** | `SwordInStone` | grey dawn flagstones, chapel, headstones | The boy lifts the whole stone; a kingdom finds its king. |
| **The Marches** | `HuLaoGate` (reskin) | muddy frontier palisade, dusk | Hold the frontier fort against the first Saxon push; fell their warlord. |
| **The Burning Fords** | `RedCliffs` (reskin) | tidal river, fire on the water, smoke-red | Saxon longships put to the torch at a crossing — the *only* fire-battle. |
| **The Long Road** | `Changban` (reskin) | broken country, rain, retreat | Escort the folk of a sacked town to Camelot under pursuit. |
| **The Beacon-Forts** | `Guandu` (reskin) | hill stockades, overcast | Seize/burn the Saxon supply camps to break the invasion's back. |
| **Mount Badon** | `MountBadon` | green hillside, bright noon | The legendary stand; outlast the tide, fell Cerdic. |
| **Camelot** | `DefendCamelot` | stone courtyard, golden torch-dusk | The crowned king holds his own gate against treachery (Black Knight). |
| **The Night-Host** | `YellowTurban` (reskin) | moor, moonlit, eerie | Morgan's wraith-host / a Pict war-band swarms — survival under a curse. |
| **Camlann** | `Camlann` | ashen field, blood-red dusk | The last battle: Mordred and Morgan. The legend ends — or is forged anew. |
| **Avalon** | `LadyOfLake` | silver mist, shimmering water | Carry the stone to the lake; let the legend rest. |

The **Trials** (Hold the Ford + 4 challenge rooms) are demoted out of the legend into a
**"Training Yard" at the Camelot node** — one click away, never padding the journey.

---

## 4. The story arc (environmental + light text — invented, not dictated)

A two-act rise-and-fall, told through **place, banners, boss rivalries, and short beats**, never
cutscenes the player must read:

- **Act I — The Boy King (rise).** Claim the stone (Churchyard) → blood the frontier (Marches,
  Burning Fords, Long Road, Beacon-Forts) → the great victory (Mount Badon) → crowned, you hold
  Camelot. The Saxon Cerdic is the face of the external war.
- **Act II — The Fall.** Treachery festers: **Mordred** is foreshadowed by his lieutenants (the
  **Black Knight** at Camelot, **Morgan le Fay**'s night-host) before he takes the field at
  **Camlann**. Then **Avalon** — not a defeat screen but a passage: the stone laid to rest.

**Recurring nemesis thread (Musou staple):** Mordred is named and foreshadowed in earlier
regions' story beats so the final duel pays off. Each region ends on a **duel-able named general**
so the journey is a string of legendary rivals.

We do **not** write a long fixed script. Story is delivered as: a **pre-battle briefing line**, a
few **in-battle beats** (boss-arrival taunt, turning point), a **between-region travel card**, and
**environmental triggers** on landmarks (the sword-in-the-stone, a fallen banner, the lake).

---

## 5. The five experience pillars (the acceptance bar)

Every rebuild task must serve at least one; the final game is judged on all five:

1. **JUGGERNAUT** — *"I am a force of nature."* The stone always shreds; rampages crescendo; the
   ultimate clears the screen.
2. **LIVING BATTLEFIELD** — *"This is an army, and a place."* Ranks rout when officers fall;
   terrain is a weapon; the field is dressed and inhabited, not an empty slab.
3. **THE JOURNEY** — *"I am crossing Britain and living a legend."* A connected map; distinct
   regions; visible progress; a felt rise and fall.
4. **LEGENDARY MOMENTS** — *"That was epic."* Boss entrances, the rage ultimate, milestone
   spectacle, story beats, a swelling finale.
5. **DISCOVERY** — *"It rewards me for looking."* Hidden caches, exploration rewards, optional
   regions, environmental storytelling.

---

## 6. Visual & audio identity (web-safe, all-code)

Hard constraints (do not break): **gl_compatibility, single-threaded web export, all art drawn
in code (`_draw`), ASCII+colour UI text** (the web-font tofu gotcha — verify on the live build).

**Visual direction:**
- **Per-region ground palette** (override `ground_top/ground_bottom`) — kill the shared
  near-black slab; give each region a real material colour.
- **`RegionBackdrop`** — a far horizon silhouette per region (castle towers, standing stones,
  misty hills, a burning fleet) drawn once behind the swarm, for depth and place.
- **`CanvasModulate` mood** per region (dawn gold, dusk blood-red, silver mist) — near-zero cost,
  huge atmosphere.
- **Additive glow** on braziers/torches/fire (they currently cast none) + **ambient drift**
  particles (embers, mist) — generalise `LadyOfLake`'s proven drifting-shimmer technique.
- **Intentional dressing**: place the orphaned Pendragon banners, Round Table, torches, the
  sword-in-the-stone prop; replace inline `draw_rect` stand-ins; fill the empty centre with
  non-colliding battlefield decals; wire the real Arthurian troop silhouettes into the hordes.
- **Bosses read as legends**: bigger silhouettes, a faction-gold aura, a muster-ring, a name-card.

**Audio direction (the silence is the enemy):**
- **`Music` autoload** — a looping, web-safe battle theme with **intensity layers** swapped by
  Stone Flow / wave / boss state; a swelling finale.
- **Region ambience beds** (river burble, moor wind, war-din) via the existing synth approach.
- **Spatialise + pitch-vary** SFX (currently flat, machine-gun identical), raise the voice pool,
  give the horde death-shouts.
- **Wire the dead escalation voices** (combo_tier, KO-milestone stingers) and give the
  **ultimate a dedicated roar** + a center-screen "MUSOU!"-style announce (ASCII).

---

## 7. What we explicitly will NOT do

- **Not** rewrite the engine, the combat core, or the level base. (Golden rule #1.)
- **Not** add threads, GLES3-only features, or anything that breaks the single-threaded web build.
- **Not** import sprite/tile/audio assets — all art stays code-drawn (this rejects Kenney/
  OpenGameArt/Figma/TileSet pipelines on principle; see [skill_tool_evaluation.md](skill_tool_evaluation.md)).
- **Not** add a heavyweight dialogue addon — a native code-drawn `StoryCard` covers the narrative
  layer on Godot 4.3.
- **Not** delete the Three-Kingdoms *scene files* (tests preload them) — **reskin in place**.
- **Not** over-build managers. The user listed `WorldManager/RegionManager/ProgressionManager/
  TriggerManager/DialogueManager/CheckpointManager`; we **map most onto existing systems** rather
  than inventing six new singletons (see [world_rebuild_plan §3](world_rebuild_plan.md)). Smallest
  stable slice that delivers the journey.

---

## 8. North star

When a player loads the live build, within ten seconds they should think: *"This is a real
place, and I am about to do something legendary in it."* And within thirty seconds of combat:
*"I am Arthur, and nothing can stand in front of this stone."* Today the build delivers neither.
Everything in the [rebuild plan](world_rebuild_plan.md) exists to deliver both.
