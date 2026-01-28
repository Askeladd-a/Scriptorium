# Copilot instructions for 3D-studio

## Repository summary
- **Purpose**: LÖVE (Love2D) Lua app that renders a 2D/3D dice tray with physics-driven D6 dice and a simple UI for rolling and material toggles.
- **Runtime**: LÖVE 11.4 (LuaJIT), configured in `conf.lua`.
- **Languages/tech**: Lua + bundled `g3d` engine (Lua). Assets are OBJ + PNG.
- **Repo size**: ~52 MB (`du -sh .`).

## How to run / build / test / lint (validated commands + notes)
**Important**: This is an interpreted LÖVE project. There is **no build step** and **no automated tests or linters** detected.

### Prerequisites
- **Install LÖVE 11.4** and ensure `love` is on your PATH (macOS/Linux) or installed under `Program Files` (Windows).
- Always run from the **repo root** so relative asset paths resolve.

### Run (macOS/Linux)
1. `love .`
   - **Validation**: `love --version` failed in this environment (`command not found`), so runtime validation is not possible here without installing LÖVE first.

### Run (Windows)
1. `run.bat`
   - The script launches `%ProgramFiles(x86)%\love\love.exe` or `%ProgramFiles%\love\love.exe`.

### Build
- **None** (interpreted Lua). Package builds are not defined in-repo.

### Test / Lint
- **None detected**. No test framework or lint config found.

### Command ordering that works
- Always run `love .` from the repo root after installing LÖVE.

### Failures/notes observed while onboarding
- `love --version` → **failed** (`command not found`) because LÖVE is not installed in this environment.
- No README/CONTRIBUTING/docs were present besides this file.
- No TODO/HACK/FIXME markers found via `rg`.

## Project layout / architecture
### Major elements
- **Entry point**: `main.lua` (app setup, UI, dice initialization, LÖVE callbacks).
- **3D dice tray + physics**: `dice3d.lua` (loads models, updates physics, draws tray/walls/dice).
- **Rendering/engine utilities**: `render.lua`, `geometry.lua`, `light.lua`, `materials.lua`, `view.lua`, `stars.lua`, `vector.lua`.
- **3D engine**: `g3d/` (bundled engine: camera, matrices, model loading, collisions).
- **Configuration**:
  - `conf.lua` (window config, Love version 11.4).
  - `default/config.lua` (defaults for board/texture settings).
- **Assets**:
  - `models/` (OBJ models: `cube.obj`, `plane.obj`).
  - `textures/` and `default/` (PNG textures, including dice faces).

### Checks / CI
- No GitHub Actions workflows or CI configs found under `.github/`.
- Manual validation = launch with LÖVE and visually confirm dice/tray render and physics.

### Hidden/implicit dependencies
- `g3d` is bundled; only external dependency is **LÖVE 11.4**.
- Asset paths are **relative** to repo root; running from elsewhere breaks loading.

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
- `textures/`: `1.png`–`6.png`, `marble.png`, `marble2.png`, `skin.txt`.

## Key file snippets (for quick orientation)
- `main.lua`: loads `dice3d` + rendering modules, creates dice data, and wires `love.load/update/draw`.
- `dice3d.lua`: sets up tray, walls, and dice models and advances physics per frame.
- `g3d/model.lua`: `newModel` loads OBJ or vertex tables and builds LÖVE meshes.

## Trust these instructions
Follow this document first; only search the repo if the information here is missing or inaccurate.
