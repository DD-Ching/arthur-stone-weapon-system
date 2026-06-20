# Design goals

## Prioritise

- **Simple but playable.** A real, hands-on loop beats a pile of half-features.
- **Game feel over visual polish.** Squares are fine. Weight is not optional.
- **Readable code.** Small scripts, one job each, tunable from the Inspector.
- **Clear file structure.** A stranger should find anything in under a minute.
- **Easy for humans *and* AI tools to modify.** Obvious names, short functions,
  comments that explain *why*.
- **Public-friendly docs.** The repo should teach, not just compile.
- **Expandable design.** Today's prototype shouldn't fight tomorrow's features.
- **Visible progress.** Small, honest commits and devlogs over silent big drops.

## Avoid

- **Overcomplicated architecture.** No frameworks for a four-script game.
- **Too many features at once.** One trade-off, tuned well, first.
- **Heavy dependencies.** Stock Godot 4, nothing else.
- **Unclear naming.** If it needs a comment to name it, rename it.
- **Private or non-reproducible assets.** Everything here is openable from a
  clean clone with only Godot installed.
- **Pretending the prototype is more complete than it is.** The README says what
  *isn't* done as loudly as what is.

## How we know a swing "feels right"

The prototype is succeeding when a first-time player, with no instructions:

1. Swings once and immediately *gets* that the weapon is heavy.
2. Whiffs a swing, feels exposed during recovery, and **learns to respect it**.
3. Lands a charged hit, watches a dummy fly, and grins.
4. Runs low on stamina and has to *think* about when to commit.

If all four happen in the first minute, the core mechanic reads. Everything in
[`ROADMAP.md`](../ROADMAP.md) after Phase 1 is in service of making those four
moments land harder.

## Tuning knobs (where the feel lives)

Almost every feel parameter is an exported variable, editable in the Godot
Inspector without touching code:

- **`StoneWeapon`** — wind-up / active / recovery timing, charge time, swing
  geometry, aim turn speeds, knockback range, stamina cost range, shake range.
- **`Arthur`** — `max_speed`, `accel`, `friction`, stamina pool, regen rate/delay.
- **`GameCamera`** — shake `decay` and `max_offset`.
- **`TargetDummy`** — `friction` (how far a hit slides it).

Tuning is a first-class activity here, not an afterthought.
