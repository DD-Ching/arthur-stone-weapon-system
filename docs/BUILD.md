# Building & running

## Run from source (the normal way)

1. Install **Godot 4.3+** (standard build) from <https://godotengine.org/download>.
2. Open Godot → **Import** → pick this folder's `project.godot` → **Import & Edit**.
3. Press **F5** / ▶ to play. `Arena.tscn` is the main scene.

That's all v0.1.0 needs. The sections below are **pre-documentation for Phase 4**
(public demo) — they're here so future-you isn't starting from scratch.

---

## Export a desktop build (Phase 4)

1. In Godot: **Project → Export…**
2. If prompted, install **export templates** (one-time, matches your Godot version).
3. Add a preset for your platform (Windows / Linux / macOS).
4. Set an export path under `build/` (git-ignored) and **Export Project**.

## Export a Web (HTML5) build (Phase 4)

The web build is what makes a one-click public demo possible.

1. **Project → Export… → Add… → Web.**
2. Set the export path to `build/web/index.html`.
3. **Export Project.** You'll get `index.html`, a `.wasm`, a `.pck`, and JS glue.
4. Web builds must be served over **HTTP with the right COOP/COEP headers** (for
   `SharedArrayBuffer`). Locally:
   ```bash
   # from build/web/
   python -m http.server 8060
   ```
   Then open <http://localhost:8060>. (Some Godot versions need the COOP/COEP
   headers a plain server won't add — GitHub Pages serves them acceptably for
   single-threaded exports, which is the safe default for this prototype.)

## Publish on GitHub Pages (Phase 4)

Two common options:

- **Simple:** commit the contents of `build/web/` to a `gh-pages` branch (or a
  `/docs` folder on `main`) and enable Pages in repo settings.
- **CI:** add a GitHub Action that exports with a headless Godot and deploys to
  Pages on each `main` push. (Deferred until there's a build worth shipping.)

## Publish a GitHub Release (Phase 4)

1. Tag the milestone: `git tag -a v0.x.0 -m "…"` and push the tag.
2. Create a Release from the tag.
3. Attach the desktop build zip and link the Pages demo.
4. Paste the matching `CHANGELOG.md` section as the release notes.

---

## Notes

- `build/`, `export/`, `dist/`, and binary build artifacts are **git-ignored** —
  builds belong on a Release/Pages, not in source history.
- No C#/.NET, no third-party Godot plugins. A clean clone + Godot is the entire
  toolchain.
