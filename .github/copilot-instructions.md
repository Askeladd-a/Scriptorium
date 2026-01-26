# Copilot instructions for 3D-studio (dice3d)

## Repository summary
- **Purpose**: A small LÖVE (Love2D) 3D dice demo featuring custom physics and software-rendered projection (now adapted to use a minimal `simplest_3d`-style camera helper). Entry point is `dice3d/main.lua`.
- **Size**: ~256 KB (`du -sh dice3d`).
- **Languages**: Lua (LÖVE 11.x runtime).
- **Runtime**: LÖVE 11.5 (configured in `dice3d/conf.lua`).

## Build / run / test / lint / validation
> There are no formal build/test/lint scripts in this repo. The app is run directly via LÖVE.

### Bootstrap
- **Install LÖVE 11.5** locally (not available in this container).
  - Windows helper: `dice3d/run.bat` runs the game by launching Love2D.

### Run
- **Always run from the `dice3d/` directory** so relative asset paths resolve correctly.
- Command (expected to work on a machine with LÖVE installed):
  - `love .`
- **Observed in this environment**: `love --version` fails with `command not found` (Love2D not installed), so runtime validation is not possible here.

### Build
- No build step. The project is interpreted Lua for LÖVE.

### Test
- No automated tests are present.

### Lint
- No lint tooling is configured.

### Cleanup / reset
- No cleanup script exists. If you need to reset runtime state, delete `dice3d/physics_log.txt` and re-run.

## Project layout / architecture
- **Repo root**
  - `.github/` (Copilot instructions)
  - `.git/`
  - `dice3d/` (all game source and assets)

- **Entry points**
  - `dice3d/main.lua`: LÖVE callbacks and overall game logic.
  - `dice3d/conf.lua`: LÖVE 11.5 configuration (window, vsync, identity).

- **Core modules**
  - `dice3d/simplest_3d.lua`: Minimal camera + projection helper inspired by simplest_3d.
  - `dice3d/view.lua`: Compatibility wrapper that exposes `simplest_3d` as `view`.
  - `dice3d/render.lua`: Software 3D drawing pipeline (project, z-sort, draw faces/shadows/board).
  - `dice3d/stars.lua`: Physics simulation, rigid star bodies, box collisions.
  - `dice3d/geometry.lua`: D4/D6/D8 star geometry and textured face rendering.
  - `dice3d/light.lua`: Light position, shading helpers, follow behavior.
  - `dice3d/vector.lua`: Vector + quaternion math.
  - `dice3d/loveplus.lua`: LÖVE helpers (image cache, setColor compatibility, transform).
  - `dice3d/materials.lua`: Physics material presets (wood/metal/rubber/bone).
  - `dice3d/base.lua`: Utility helpers (`clone`, `math.bound`, etc.).

- **Assets**
  - `dice3d/default/`: Board/bulb textures and `default/config.lua`.
  - `dice3d/textures/`: Dice face textures (1–6).
  - `dice3d/physics_log.txt`: Runtime physics logging output.

## CI / checks
- No GitHub Actions workflows or CI configuration found.
- No pre-commit or validation pipeline is configured.

## Key implementation notes
- Rendering is a software projection pipeline. World → screen transform uses `simplest_3d.project` (exposed as `view.project`).
- **Always** load `base.lua` before anything that depends on `math.bound`.
- The physics engine (`stars.lua`) is self-contained and updates per-frame inside `love.update`.
- Assets are loaded relative to the `dice3d/` directory; avoid changing working directory when running.

## Inventory hints (for fast navigation)
- Root files: `.git/`, `.github/`, `dice3d/`.
- `dice3d/` contents:
  - `main.lua`, `conf.lua`, `base.lua`, `loveplus.lua`, `vector.lua`, `render.lua`, `view.lua`, `simplest_3d.lua`, `geometry.lua`, `stars.lua`, `light.lua`, `materials.lua`, `physics_log.txt`, `run.bat`, `default/`, `textures/`.

## Trust these instructions
These notes are intended to avoid repeated repo-wide searches. **Follow them as the source of truth**, and only search the tree if something is missing or contradicts these instructions.
