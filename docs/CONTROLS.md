# Controls

| Input                        | Action                                              |
| ---------------------------- | --------------------------------------------------- |
| `W` `A` `S` `D` / Arrow keys | Move                                                |
| Mouse                        | Aim (the weapon turns *slowly* toward the cursor)   |
| `Space` / Left Mouse Button  | Heavy swing — **hold to charge**, release to commit |
| Right Mouse Button           | Overhead slam — a committed smash with a shockwave  |
| `R`                          | Reset the arena                                     |

These actions are defined in `project.godot` under `[input]`, so you can rebind
them from **Project → Project Settings → Input Map** in Godot.

## Why the controls feel the way they do

The controls are part of the design, not just plumbing.

### Movement is floaty on purpose
Arthur has a **low acceleration** (he's slow to get moving — dead weight) and a
**modest friction** (he keeps sliding after you let go — momentum). You don't
drive Arthur so much as *negotiate* with him. Tunable on the `Arthur` node:
`max_speed`, `accel`, `friction`.

### Aim lags behind the mouse
The weapon doesn't snap to your cursor — it **rotates toward it slowly**, and
even more slowly while you're mid-swing. That lag is the stone's weight
expressed as input. Lining up a big hit on a moving target is a real act of
commitment. Tunable on `StoneWeapon`: `turn_speed_ready`, `turn_speed_busy`.

### One button, two swings
- **Tap** `Space` / LMB → a quick (still heavy) swing at minimum charge.
- **Hold** → the head winds further back and glows; release to unleash a bigger,
  higher-knockback swing that also costs more stamina and a longer recovery.

Because the mouse aims *and* left-click swings, clicking near a target both
points the weapon toward it and begins the swing — so a click is "wind up toward
where I'm pointing." (Use `Space` if you'd rather aim and attack separately.)

There is always a **minimum wind-up** you can't skip — that's the commitment.
And while you're winding up, active, or recovering, your **movement speed is
throttled**. The bigger the swing, the longer you're stuck paying for it.

### The stone has weight even when you're not attacking
The stone head is a real physical body. Just sweeping the mouse drags it *through*
enemies and rocks, shoving them around — and it won't let them pass through it.
This is the "heavy object you steer, not a cursor" feeling, and it opens up
positioning play: nudge an enemy into a wall, line a rock up, herd a group.
Tunable on the `StoneBody` node (collision shape) and `StoneWeapon` (`arm_length`,
`turn_speed_*`).

### Right-click: the overhead slam
A second, heavier commitment. Arthur heaves the stone overhead (a clear telegraph),
holds for a beat, then **smashes it down** in front of him. The impact throws out a
**shockwave** — radial knockback that falls off with distance, stuns nearby enemies,
and leaves a chunk of **debris rock** you can then launch with a normal swing. It
costs a big chunk of stamina and roots you through a long recovery, so pick your
moment. Tunable on `StoneWeapon`: the `Slam` timing group, `slam_*`, and the
`Shockwave` scene (`radius`, `impulse`, `stun_time`).

### Stamina gates the spam
Each swing costs stamina (more for a charged swing; the slam costs a lot). Stamina
regenerates after a short delay. Try to swing with too little stamina and Arthur
**fizzles** — he stumbles into recovery without landing the hit, and the stamina bar
flashes. That fizzle is the "you overcommitted" punish.

### Every hit is different — and that's the game
There's no fixed "sword damage". A hit's force comes from one formula (see
`Impact.gd`):

> **speed × mass × charge × angle × collision bonus × combo**

In practice:
- A **slow touch** just pushes. A **fast swing** launches. A **charged** swing smashes.
- **Wall crush** — hit an enemy with a wall (or the centre pillar) right behind it
  and it can't fly away, so the hit hurts *much* more: `WALL CRUSH` / `STONE PRESS` /
  `NO CUSHION`. This even punches through a Shield Soldier's guard. Shoving enemies
  into a corner *before* you swing is the strongest thing you can do.
- **Bowling** — enemies collide with each other. Launch a Light Soldier into a
  crowd for chain hits: `BOWLING HIT` → `CHAIN IMPACT` → `DOUBLE BONK`.
- **Props** — launch a rock or crate into enemies for a free hit, or push a prop
  onto the **pressure plate** to open the gate.

### Stone Flow (the combo)
The HUD's **STONE FLOW** bar fills as you land meaningful hits and ticks down when
you stop. Stacks give *small* buffs — faster charge, a little mobility, shorter
recovery, more force, and a stack-5 "flow mode". They're intentionally minor:
buffed Arthur is still hauling a rock. The combo **breaks** if you whiff a swing or
run your stamina dry, so the loop is *land → reposition → land again* before it
bleeds.

### Know your enemies
- **Dummy** (red) — a punching bag for testing knockback.
- **Light Soldier** (orange) — low mass, flies far; the best bowling ball.
- **Shield Soldier** (blue, with an arc) — shrugs off frontal hits; flank it or
  crush it into a wall.
- **Heavy Guard** (grey, ringed) — barely flies; useful as moving cover.

### Reset
`R` reloads the arena scene — enemies, props, and Stone Flow reset, stamina refills.
It's a test room; abuse it.
