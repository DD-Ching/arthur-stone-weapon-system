# Devlog 0004 — Momentum swing & the battlefield

**Date:** 2026-06-21
**Build / tag:** v0.4.0

## 1. What changed?

Two big things, one feeding the other.

- **The swing stopped being a charge and became momentum.** The stone head is now a
  spring-damped pendulum that hangs behind Arthur and sloshes with real inertia.
  Left-click doesn't "charge" — it *applies force*: an angular kick that flings the
  head from behind, around, to the front. Damage is read straight off the head's
  real speed at contact, so a flat-footed poke pushes and a built-up whip launches.
  Every swing also **lunges Arthur forward**, so attacking is also moving.
- **The arena became a battlefield.** Enemies got an AI brain (approach, keep the
  shield toward Arthur, a telegraphed attack, stagger) on top of the existing
  physics body. There's a shield-wall formation to break, a spear line, a flanking
  charge group, heavy anchors, a banner, mud, fences, and a real objective with
  win/lose and an Arthur health bar.

## 2. Why does momentum improve the heavy-weapon feeling?

Because "heavy" should be something you *fight*, not a number you fill. A charge bar
is a timer; a pendulum is a relationship. Now the weight expresses itself the whole
time — the head lags when you turn, overshoots when you stop, and the only way to
hit hard is to *commit your whole body's motion* into the swing. You feel the mass
because you're constantly negotiating with it. And folding the lunge into the swing
turns the weapon into a traversal tool, which is exactly the "heavy + clever +
rhythmic" fantasy the brief keeps asking for.

## 3. What physics / gameplay idea was tested?

**An AI that knows when to stop being an AI.** The hardest part of mixing steered
enemies with a physics-combat weapon is that the two fight each other — a soldier
walking toward you resists being launched. The rule that made it click: an enemy
steers *only while it's calm*; the instant it's launched (speed over a threshold) or
staggered, it goes limp and the physics carries it. So Arthur's strength always wins
the physical contest, and bowling / wall-crush / knockback all still work on a
"living" army. The shield refactor follows the same spirit: block/break is decided
on the **raw** hit, so a strong enough swing breaks the shield even though the shield
softens the blow — the brief's "a shield can't shut Arthur down forever" rule, made
literal.

## 4. What still feels wrong?

- **The momentum swing needs a learning beat.** The head resting *behind* you is
  correct but unintuitive for the first few swings; it wants a one-time hint or a
  clearer telegraph of the arc.
- **Crowd balance is rough.** With ~17 enemies and i-frames, a careless player can
  get swarmed; the numbers (attack damage, i-frame window, enemy approach speed)
  need a real tuning pass against playtests.
- **Floating labels pile up** when a swing breaks several shields at once.
- **No audio**, so the big swings still under-hit relative to how they look.

## 5. What is next?

- **Cavalry** and the **war cart** — fast charging masses with telegraphed lanes,
  poor turning, and side-vulnerability. Designed in the roadmap; the AI's
  "steer-then-ragdoll" seam is built to host them.
- A **balance pass** on the battlefield, and more objectives (Stop the Cavalry,
  Capture the Banner, Hold the Line).
- The **spin/tornado** attack and audio hooks.

→ Tracked in [`ROADMAP.md`](../ROADMAP.md).
