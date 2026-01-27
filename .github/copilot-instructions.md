# Copilot instructions for 3D-studio

## Repository summary
- **Purpose**: A LÖVE (Love2D) Lua project that renders 3D dice via the vendored 3DreamEngine, with legacy physics helpers in `stars.lua`. The playable entry point is the repo root `main.lua`, with `conf.lua` configuring the LÖVE window.
- **Repo shape**: Small-to-medium repo with the dice demo plus vendored engines (`3DreamEngine/`, `g3d/`, `g3d_fps/`).
- **Languages/runtime**: Lua code targeting LÖVE 11.x; assets are images and models referenced by the Lua modules.

## Build / run / test / lint / validation
> There are no formal build/test/lint scripts. The app runs directly via LÖVE, and there is no CI configuration.

### Bootstrap
- **Install LÖVE 11.x** on the host machine (not available in this container).
- Windows helper script: `run.bat` launches Love2D for the repo root.

### Run (validated command behavior)
- **Always run from the repo root** so relative asset paths resolve.
- Command (expected on a machine with LÖVE installed):
  - `love .`
- **Observed in this environment**:
  - `love --version` → `command not found` (LÖVE not installed).
  - `lua -v` → `command not found` (standalone Lua not installed).

### Build
- No build step; Lua is interpreted by LÖVE.

### Test
- No automated tests present.

### Lint
- No lint tooling configured.

### Cleanup / reset
- No cleanup scripts. If you need to reset diagnostics, delete `physics_log.txt`.

## Project layout / architecture
- **Repo root (top-level files & dirs)**
  - `.github/` (this instructions file + agent configs; no CI workflows).
  - `3DreamEngine/` (vendored 3DreamEngine source + docs + examples).
  - `g3d/` (vendored g3d engine).
  - `g3d_fps/` (vendored g3d FPS controller).
  - `default/` (board textures and `config.lua` used by the dice demo).
  - `textures/` (dice face textures).
  - `main.lua` (LÖVE callbacks and overall dice game logic).
  - `conf.lua` (LÖVE configuration).
  - `render.lua`, `geometry.lua`, `stars.lua`, `view.lua`, `simplest_3d.lua`, `light.lua`, `materials.lua`, `vector.lua`, `loveplus.lua`, `base.lua` (legacy rendering/physics helpers; `stars.lua` is the active simulation).
  - `run.bat` (Windows runner).
  - `physics_log.txt` (runtime logging output).

- **Entry points**
  - `main.lua`: `love.load`, `love.update`, `love.draw`, and input callbacks.
  - `conf.lua`: window + version configuration for LÖVE.

- **Core modules (dice demo)**
  - `render.lua`: software 3D draw pipeline and z-buffer work.
  - `geometry.lua`: dice geometry definitions and face texturing.
  - `stars.lua`: legacy physics helpers for rigid bodies.
  - `view.lua` + `simplest_3d.lua`: camera/projection helpers.
  - `light.lua`: light settings and follow behavior.
  - `materials.lua`: physics/material presets.
  - `vector.lua`, `loveplus.lua`, `base.lua`: math and LÖVE utility helpers.

- **Vendored engines & docs**
  - `3DreamEngine/README.md` + `3DreamEngine/docu/` contain upstream docs (engine overview + usage snippet).
  - `3DreamEngine/3DreamEngine/` holds engine source, with `extensions/`, `examples/`, `libs/`, and `shaders/` under it.
  - `g3d/README.md` documents groverburger’s g3d engine and a short example.
  - `g3d_fps/README.md` documents the g3d FPS controller.

## CI / checks
- No GitHub Actions workflows or other CI config present.
- No pre-commit hooks.

## Inventory hints (fast navigation)
- Root files list (sorted): `.github/`, `3DreamEngine/`, `g3d/`, `g3d_fps/`, `default/`, `textures/`, `base.lua`, `conf.lua`, `geometry.lua`, `light.lua`, `loveplus.lua`, `main.lua`, `materials.lua`, `obb.lua`, `physics_log.txt`, `render.lua`, `run.bat`, `simplest_3d.lua`, `stars.lua`, `vector.lua`, `view.lua`.
- `3DreamEngine/` contains `README.md`, `TODO.md`, `LICENSE`, `docu/`, `examples/`, and engine source under `3DreamEngine/3DreamEngine/` (including `extensions/`, `libs/`, and `shaders/`).
- `g3d/` contains `README.md`, `LICENSE`, and engine source under `g3d/`.
- `g3d_fps/` contains `README.md`, `LICENSE`, and its FPS controller Lua files.

## README inventory
- **No repo-root README**. The closest references are:
  - `3DreamEngine/README.md` (engine overview + usage snippet + screenshots).
  - `g3d/README.md` (engine overview + demo snippet).
  - `g3d_fps/README.md` (FPS controller summary).

## Trust these instructions
These notes are intended to avoid repeated repo-wide searches. **Follow them as the source of truth**, and only search the tree if something is missing or contradicts these instructions.
