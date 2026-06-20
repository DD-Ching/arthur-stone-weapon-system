# Contributing

This is a personal prototype and portfolio piece, but it's public and
fork-friendly. If you're poking at it, here's the lay of the land.

## Branches & workflow

- **`main`** — stable, playable milestones only. Each is tagged (`v0.1.0`, …).
- **`dev`** — active development. Branch features off here.
- **feature branches** — `feat/<thing>`, `fix/<thing>`, `docs/<thing>`.
- Open PRs into `dev`. `dev` merges into `main` only at a playable milestone,
  which then gets a version tag.

## Commit style

Short, conventional, present-tense:

```
init: create Godot project structure
feat: add Arthur movement controller
feat: add heavy weapon swing
fix:  stop double-hits within a single swing
docs: add roadmap and concept notes
release: prepare v0.1.0 prototype
```

## Code conventions

- **One responsibility per script.** If a file grows two jobs, split it.
- **Tunable feel = exported variable.** Anything you'd want to tweak by hand
  belongs in `@export`, grouped with `@export_group`, so it's editable in the
  Inspector.
- **Comment the *why*, not the *what*.** The code says what; comments say why a
  number or a seam exists.
- Match the surrounding style. Keep functions short.

## Before you push

- Open the project in Godot 4.3+ and run `Arena.tscn` (F5). It should launch with
  no errors in the Output panel.
- Update `CHANGELOG.md` (under `[Unreleased]`) if you changed behaviour.
- If you changed how something *feels*, jot a devlog entry (`devlog/TEMPLATE.md`).

## Definition of "done" for a feature

It runs, it's tunable, it's documented where it matters, and it sharpens the core
trade-off — *power vs control*. If it doesn't sharpen that, it probably belongs in
the roadmap backlog instead.
