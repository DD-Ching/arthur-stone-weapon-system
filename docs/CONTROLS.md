# Controls

| Input                        | Action                                              |
| ---------------------------- | --------------------------------------------------- |
| `W` `A` `S` `D` / Arrow keys | Move                                                |
| Mouse                        | The heavy head **follows the cursor with lag** (never snaps); slow contact just pushes |
| **Hold** `Space` / Left Mouse **+ drag** | **Swing** — drag *around* Arthur to whip the head (drag clockwise → swing clockwise) |
| Right Mouse Button           | Overhead slam — a committed smash with a shockwave  |
| **`Shift`** / **Middle Mouse** (hold) | **Spin / tornado** — whirl the stone, launching the crowd outward |
| `R`                          | Reset                                               |
| **Touch** (phone / tablet)   | **Left stick** move · **right stick** aim — *circle it to swing* · **SLAM** / **SPIN** buttons · **R** button resets |

These actions are defined in `project.godot` under `[input]`, so you can rebind
them from **Project → Project Settings → Input Map** in Godot.

## Touch / mobile

On a touchscreen, an on-screen overlay (`scripts/ui/TouchControls.gd`, shown via the HUD)
appears automatically — desktop is unaffected:

- **Left stick** (floating, left half of the screen) — analog movement, same weight + momentum.
- **Right stick** (right half) — points the stone where you push it, and **circling your
  thumb whips the head around Arthur**. This is the *exact same control as the mouse*: the
  swing is the drag *around* you, so a fast circle is a hard swing and just holding the stick
  out only pushes. Flicking the stick out is a quick swing in that direction.
- **SLAM** / **SPIN** buttons (bottom-right) — the overhead smash and the whirlwind.
- **R** button (top-right) — restart (the touch stand-in for the `R` key).

The sticks reuse the existing input model (the right stick presses the same `attack` action
and feeds the same aim the mouse gives), so the feel — and every combat number — is identical
to playing with a mouse; only the input device changes. Hold the phone **landscape**.

## Why the controls feel the way they do

The controls are part of the design, not just plumbing.

### Movement is floaty on purpose
Arthur has a **low acceleration** (he's slow to get moving — dead weight) and a
**modest friction** (he keeps sliding after you let go — momentum). You don't
drive Arthur so much as *negotiate* with him. Tunable on the `Arthur` node:
`max_speed`, `accel`, `friction`.

### You drag the weapon — there's no attack button
The stone head is a heavy pendulum on the end of Arthur's arm. **Move the mouse**
and the head **springs toward the cursor with weight and lag** — it follows where
you point, but slowly, never snapping. While it's just following, slow contact only
**pushes and blocks** (the solid stone shoves things aside); it deals no real damage.

To **attack**, **hold** the button and **drag the mouse around Arthur**. The drag
itself applies torque to the heavy head:

- Drag **clockwise** → the head swings **clockwise**; drag the other way → it swings
  the other way. It follows your *drag*, not the shortest path to the cursor.
- A faster drag builds **more angular speed** — and damage comes straight off the
  head's **real speed at contact**. A slow drag pushes; a hard whip **launches**; a
  whip into a wall still **wall-crushes**. The stone glows hot and the HUD shows live
  **POWER** so you can read the speed you've built.

A plain click does nothing — you have to actually *swing*. It should feel like a
physics sandbox: you are dragging and whipping a heavy stone, not pressing "attack".
Dragging a swing costs stamina. Tunable on `StoneWeapon`: `follow_stiffness`,
`rest_damping`, `drag_gain`, `hit_speed_min`, `max_avel`.

### Spin / tornado — the crowd-clear
Hold **`Shift`** (or **middle mouse**) and Arthur whirls the stone around himself,
launching everything in a ring **outward**. It's the musou panic button: it bowls
launched enemies into the rest, breaks shields it sweeps through, and racks up the
**KO counter** fast. The cost: it **drains stamina quickly**, so it's a burst, not a
state — and even spinning, Arthur is a slow, committed tornado (still no ninja).
Tunable on `StoneWeapon`: the `Spin` group (`spin_rate`, `spin_cost`, `spin_stretch`…).

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
