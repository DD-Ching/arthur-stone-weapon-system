# Devlog 0007 — Hold the Ford

**Date:** 2026-06-21
**Build / tag:** v0.8.0

## 1. What changed?

The ford stopped being a backdrop for a horde and became a **battle with a line to
hold**. Everything the Ford was missing landed at once:

- **Five escalating waves** — light raiders, then a shield wall, then spears behind
  shields, then cavalry and the war cart, then an officer with an escort. Each wave is
  announced and arrives as the field thins.
- **A real lose condition.** Raiders no longer just mob Arthur — they **march toward an
  allied banner** on your bank and try to *cross*. A raider that walks past the defence
  line under its own power is a **breach**; twelve breaches and the ford falls.
- **Allied footmen** fight beside you. One team flag on the enemy script splits the
  field into raiders and allies who hunt each other; Arthur's stone shoves allies but
  never damages them, and a dead ally costs no KO.
- **Smarter raiders** — they spread out instead of stacking, the non-shield ones flank
  to surround, spearmen hold spacing, and everyone keeps re-picking the nearest threat.
- **Bridge collapse, drifting logs, and real audio** — pound the bridge with a launched
  prop and it drops into the river; logs ride the current as launchable hazards; and a
  procedural `SoundBank` finally makes every impact *sound* like something.

## 2. Why does this fit the heavy weapon?

A line you must hold is the perfect frame for a weapon that is **strong but slow**. You
can't be everywhere, and the stone commits you — so positioning is the whole game. Do
you stand on the bridge and bottle the choke, knock chargers into the wheel, collapse
the crossing entirely, or trust the allies to hold one flank while you crush the other?
The raiders marching *past* you (not just at you) is what turns raw strength into a
spatial problem: overwhelming force still has to be in the right place.

## 3. What physics / gameplay idea was tested?

**One script, two armies.** The whole ally system is a `team` field on the existing
`Enemy`: a unit marches toward a *goal* (raiders → the banner; allies → the nearest
raider) and attacks a *foe* when one blocks the way. That single split — goal vs. foe —
gave allies, the "cross the ford" lose condition, and smarter targeting for free,
without a second AI. Separation and flanking are just two extra steering vectors,
recomputed a few times a second so the crowd loop stays cheap on the single-threaded
web build. And the audio is honest synthesis — short PCM tones built at startup — so the
hooks from v0.7 light up with no asset pipeline.

## 4. What still feels wrong?

- **Balance is untuned.** Twelve breaches, six allies, five waves — the numbers are
  first guesses; the difficulty curve needs playtests.
- **No score screen.** Surviving the waves wins, but there's no KO/time summary yet.
- **Crowd ceiling.** The garrison plus waves plus allies is the most bodies yet; a real
  musou wall still wants cheaper enemy updates (pooling / coarser ticks).

## 5. What is next?

- A **KO + time score screen**, a balance pass, and the cheaper enemy update for a
  bigger crowd. Then the **challenge rooms**.

→ Tracked in [`ROADMAP.md`](../ROADMAP.md).
