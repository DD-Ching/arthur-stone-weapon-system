# Devlog 0005 — Going musou

**Date:** 2026-06-21
**Build / tag:** v0.5.0

## 1. What changed?

The battlefield turned into a **musou** (Dynasty-Warriors) playground: one absurd
hero vs an endless army.

- **Spin / tornado attack** — hold a button and Arthur whirls the stone around
  himself, launching the whole crowd outward in a ring. It's the signature
  crowd-clear: it breaks shields it sweeps through and bowls launched bodies into
  the rest for chains.
- **KO counter** with milestones (`RAMPAGE!` → `ONE-MAN ARMY!`) — the scoreboard
  that makes mowing feel like an achievement.
- **Reinforcement horde** — the field refills from the back rank, so there's
  always more to cut down.
- **Cavalry charges** — telegraphed mounted chargers that barrel through everything,
  including their own ranks, but commit to the charge and can be broken.

## 2. Why does this fit the heavy weapon?

A musou hero and a heavy weapon are a surprisingly good match. The fantasy of the
genre is *overwhelming force applied to a crowd*, and that's exactly what a giant
liftable stone is for. The momentum swing already sends one enemy flying; pointed
at a horde, the same physics turns into a chain reaction. The spin didn't need new
combat rules — it's the existing impact formula sampled in a circle. The weight
keeps it honest: even spinning, Arthur is a slow, committed tornado, not a blur.

## 3. What physics / gameplay idea was tested?

**Reusing one impact system for a totally different-feeling move.** The spin, the
swing, the slam, bowling, and a cavalry charge all resolve through the same
`Impact.resolve_hit`. The spin is just "launch radially outward, re-sample the
overlap every quarter second"; the cavalry charge is just "a fast heavy body" that
the existing bowling code already turns into a crowd-plough. The seam that paid off
again: enemies that go limp the moment they're launched, so a whirlwind or a
stampede scatters a *living* army without fighting their AI.

## 4. What still feels wrong?

- **Crowd size vs the web build.** ~26 live AI enemies is the current cap; pushing
  for a true musou wall of bodies needs a cheaper enemy update (pooling, coarser
  AI ticks) before the single-threaded web build will hold framerate.
- **The objective vs the horde.** "Break the Shield Wall" can get lost under the
  reinforcement pressure — musou wants *layered* objectives (officers, morale,
  capture points), not one wall.
- **Spin is a little too safe.** It wants a wind-down/recovery so it's a commitment,
  not a hold-to-win.

## 5. What is next?

- The **war cart / relic chariot** (designed in the roadmap) — a flippable,
  breakable charging mass.
- **Officer / banner objectives** and a KO/time score screen.
- A pass on **enemy-update cost** so the horde can grow, and **audio**.

→ Tracked in [`ROADMAP.md`](../ROADMAP.md).
