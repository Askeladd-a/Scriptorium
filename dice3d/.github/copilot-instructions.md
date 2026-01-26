# Copilot coding agent instructions for dice3d

## Overview
- **Project type:** LÖVE (Love2D) 11.4 game written in Lua.
- **Purpose:** 3D dice simulation/rendering using g3d (immediate switch; legacy renderer is no longer used).
- **Repo size:** Small, single-module game; no build system, no package manager.
- **Key dependency:** `g3d.lua` must live next to `main.lua` (same folder as `conf.lua`).

## Environment & bootstrap
1. **Install LÖVE 11.4** for your OS (the game targets 11.4).
2. **Drop `g3d.lua`** in the repo root (same folder as `main.lua`). The app hard-errors if missing.
3. Optional: On Windows, `run.bat` launches LÖVE from `%ProgramFiles%` or `%ProgramFiles(x86)%`.

### Commands (validated)
> These commands were executed in the current environment.
- `love --version` **fails** with `command not found` because LÖVE is not installed in this container.

### Commands (expected to work once LÖVE is installed)
- **Run (dev):** `love .` from the repo root.
- **Run (Windows):** double-click `run.bat` or `love.exe .` in this folder.

### Build / test / lint
- **Build:** Not applicable (LÖVE loads Lua directly).
- **Tests:** None in repo.
- **Lint:** None configured.

> Always install LÖVE **before** trying to run the game. Always add `g3d.lua` in the repo root; otherwise `main.lua` throws a fatal error at startup.

## Project layout (key files)
- **Entry points:**
  - `main.lua` – LÖVE callbacks, gameplay, materials UI, g3d renderer wiring.
  - `conf.lua` – LÖVE window config, target version 11.4.
- **Rendering:**
  - `render_g3d.lua` – g3d camera + model setup; syncs dice star position & quaternion rotation.
  - `render.lua` – legacy renderer (kept but no longer used).
- **Simulation & helpers:**
  - `geometry.lua`, `light.lua`, `materials.lua`, `stars.lua`, `vector.lua`, `view.lua`, `base.lua`.
- **Assets:**
  - `assets/models/` – `die.obj`, `tray.obj`.
  - `textures/` – dice number textures and marble textures.
  - `default/` – `config.lua` plus default textures.
- **Docs:**
  - `PORTING_G3D.md` – states g3d-only renderer and how to add `g3d.lua`.
- **Other:**
  - `run.bat` – Windows launcher.
  - `physics_log.txt` – notes/logs.

## Validation / CI
- No GitHub Actions workflows or CI scripts are present in this repo.
- No local validation scripts are present. If you add one for debugging, remove it before finishing.

## Root contents (repo root)
`PORTING_G3D.md`, `assets/`, `base.lua`, `conf.lua`, `default/`, `geometry.lua`, `light.lua`, `loveplus.lua`, `main.lua`, `materials.lua`, `physics_log.txt`, `render.lua`, `render_g3d.lua`, `run.bat`, `stars.lua`, `textures/`, `vector.lua`, `view.lua`.

## Next-level directories (high priority)
- `assets/models/` – OBJ models used by g3d.
- `default/` – shared config and marble textures.
- `textures/` – dice face textures (0-190 series) + marble variants.

## Notes to future agents
- Trust this file first. Only search the repo if a needed detail is missing or incorrect.
