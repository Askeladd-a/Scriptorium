# Copilot instructions for Scriptorium

## Summary
- This repository is a LÖVE2D (Lua) game project for **Scriptorium**, with a module-driven UI flow (splash screen, main menu, gameplay modules) and 3D dice rendering. The entry point is `main.lua`, with configuration in `conf.lua` targeting LÖVE **11.4**.

## High-level repository info
- **Project type:** LÖVE2D (Lua) game.
- **Primary languages:** Lua.
- **Runtime/framework:** LÖVE 11.4 (see `conf.lua`).
- **Assets:** `resources/` (textures, UI, sounds), `imported_patterns/`.

## Build / Run / Test / Lint
> **Always install the LÖVE runtime locally before attempting to run the game.** The container does not have `love` installed.

### Bootstrap / Setup
- Install LÖVE 11.4 from https://love2d.org/ (required).
- No other bootstrap scripts are present in the repo.

### Run (validated command)
- **Run the game:**
  - Command: `love .`
  - **Validation in this container:** `love --version` failed with `command not found` because LÖVE is not installed.
  - **Workaround:** install LÖVE locally, then run `love .` from repo root.

### Build
- There is no build system (no `Makefile`, `package.json`, `Cargo.toml`, etc.). Use the LÖVE runtime to launch directly.

### Test
- No automated tests were found.

### Lint / Format
- No lint or format scripts were found.

### Cleaning
- No clean script or build artifacts were found. If you create temporary artifacts, remove them manually before committing.

## Project layout and architecture
- **Entry point:** `main.lua` (LÖVE callbacks, scene loading). LÖVE always starts from `main.lua` unless you rename files.
- **Configuration:** `conf.lua` sets window/title and targets LÖVE **11.4**.
- **Core systems:** `src/core/` (dice faces, reward registration, legacy scene manager).
- **UI modules:** `src/scenes/` (splash, main menu, settings, scriptorium, reward, desk prototype).
- **Game logic:** `src/game/` (run loop, folio state, scriptorium).
- **UI:** `src/ui/` and `src/ui.lua`.
- **Assets:** `resources/` (textures, UI, sounds, shaders). UI images expected at `resources/ui/`.
- **Design docs & plans:** `docs/toolkit/` and `plan/feature-ui-mainmenu-1.md`.

### CI / Validation pipelines
- No GitHub Actions workflows are present (no `.github/workflows/`). If CI exists elsewhere, it is not in this repo.

## Key files at repo root (inventory)
- `main.lua` (entry point)
- `conf.lua` (LÖVE configuration)
- `core.lua`, `render.lua`, `physics.lua`, `geometry.lua`, `view.lua`, `light.lua` (engine/graphics utilities)
- `main_game.lua` (alternative entry point / reference)
- `docs/`, `plan/`, `resources/`, `src/`, `imported_patterns/`
- **No `README.md` or `CONTRIBUTING.md` found.**

## First-level directories (inventory)
- `src/` → core/game/scene/UI code
- `resources/` → textures, UI art, sounds, shaders
- `docs/` → manuals and toolkit documentation
- `plan/` → implementation plan(s)
- `imported_patterns/` → external pattern references

## Notes for efficient changes
- Prefer editing scene files in `src/scenes/` for UI flow changes.
- Asset paths used in code generally assume direct access under `resources/` (e.g., `resources/ui/splash.png`).
- If you add new assets, ensure they follow existing naming conventions and are referenced from scene code.

## Final guidance
- Trust the instructions above; only search further if information is missing or incorrect.
