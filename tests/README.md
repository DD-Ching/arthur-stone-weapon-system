# tests/

Lightweight, headless verification for the prototype. No framework — just a
scene you can run with the Godot CLI that drives the real game objects and
prints a verdict.

## Swing smoke test

`SwingSmokeTest.tscn` (+ `swing_smoke_test.gd`) spawns Arthur and one dummy,
aims the stone-sword straight at the dummy, drives a full swing through its
state machine, and asserts the core loop actually happened:

- the dummy was **launched** (knockback applied),
- the swing **cost stamina** (measured at its low point, since stamina
  regenerates), and
- `hit_landed` **fired** (the camera-shake / impact signal).

Run it:

```bash
godot --headless --path . res://tests/SwingSmokeTest.tscn --quit-after 600
```

Output ends with a verdict line, and the process exit code reflects it:

```
SMOKE_RESULT moved=195.8 spent_stamina=24.8 hit_signal=true final_state=0
SMOKE_VERDICT PASS
```

CI runs exactly this on every push (see `.github/workflows/validate.yml`), so a
change that silently breaks the swing, the hitbox, or the stamina cost turns the
build red.

## Why so minimal

It's a prototype. This one test guards the single thing that must never break —
*a swing connects and costs something*. As real systems land (ground slam,
destructibles, enemies), add a focused scene per behaviour here rather than
reaching for a heavier test framework before it earns its keep.
