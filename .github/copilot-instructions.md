# Copilot instructions for 3D-studio

## Repository summary
- **Purpose**: LÖVE (Love2D) Lua project that renders a 2D dice UI plus a 3D dice tray using the bundled g3d engine.
- **Runtime**: LÖVE 11.4 (configured in `conf.lua`).
- **Languages**: Lua (LuaJIT via LÖVE).
- **Assets**: OBJ models in `models/`, textures in `textures/` and `default/` (dice faces are `textures/1.png` through `textures/6.png`).

## How to run / build / test / lint (validated commands + notes)
- **Prerequisite**: Install LÖVE 11.4 and ensure the `love` executable is on PATH.
- **Run (macOS/Linux)**: `love .`
  - **Validation**: `love --version` failed with `command not found` in this environment, so runtime validation was not possible without installing LÖVE first.
- **Run (Windows)**: `run.bat` (expects LÖVE installed under `Program Files` or `Program Files (x86)`).
- **Build**: No build step (interpreted Lua).
- **Test / Lint**: No automated tests or linters detected.
- **Order of operations**: always run from the repository root so asset paths (OBJ/PNG) resolve correctly.

## Project layout / architecture (where to change things)
- **Entry point**: `main.lua` (application setup, UI, and 2D dice logic).
- **3D dice tray**: `dice3d.lua` (loads g3d models, updates 3D dice physics, draws tray/walls/dice).
- **Engine utilities**:
  - `g3d/` (3D engine: model loading, camera, matrices, vectors, collisions).
  - `render.lua`, `geometry.lua`, `light.lua`, `materials.lua`, `view.lua` (rendering, physics visuals, materials).
- **Configuration**:
  - `conf.lua` (LÖVE window + version config).
  - `default/config.lua` (board/texture defaults).
- **Assets**:
  - `models/` (OBJ files: `cube.obj`, `plane.obj`).
  - `textures/` (PNG textures, marble textures, numbered dice faces).
  - `default/` (fallback textures + config).

## CI / validation pipelines
- No GitHub Actions workflows or CI configs detected under `.github/`.
- Validate manually by launching with LÖVE and visually confirming dice render and animation.

## Dependency notes
- g3d is bundled in `g3d/` (no external dependency needed beyond LÖVE).
- Asset paths are relative to repo root; keep working directory at the repo root.

## Root directory inventory
```
.github/
base.lua
conf.lua
default/
dice3d.lua
g3d/
geometry.lua
light.lua
loveplus.lua
main.lua
materials.lua
models/
physics_log.txt
render.lua
run.bat
stars.lua
textures/
vector.lua
view.lua
```

## Next-level inventory (selected)
- `.github/agents/` (agent presets; no workflows).
- `default/`: `bulb.png`, `config.lua`, `marble.png`, `marble2.png`.
- `g3d/`: `camera.lua`, `collisions.lua`, `g3d.vert`, `init.lua`, `matrices.lua`, `model.lua`, `objloader.lua`, `vectors.lua`.
- `models/`: `cube.obj`, `plane.obj`.
- `textures/`: multiple numbered PNGs, `marble.png`, `marble2.png`, `skin.txt`.

## Key file snippets (for quick orientation)
- `main.lua`: loads `dice3d` and wires LÖVE callbacks (`love.load`, `love.update`, `love.draw`).
- `dice3d.lua`: initializes tray + dice models and updates physics per frame.
- `g3d/model.lua`: `newModel` loads OBJ or vertex tables and builds LÖVE meshes.

## Trust these instructions
Follow this document first; only search the repo if the information here is missing or inaccurate.
