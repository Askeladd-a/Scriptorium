# Copilot instructions for `Scriptorium`

## 1) Repository summary (read this first)
- `Scriptorium` is a **LÖVE 2D (Lua)** game prototype: medieval manuscript-themed roguelite loop with dice, folio grids, scene transitions, and progression systems.
- Codebase size is **small/medium**: root engine-style Lua modules + `src/` gameplay modules + `resources/` assets + design docs.
- Main runtime target is **LÖVE 11.4** (`conf.lua` sets `t.version = "11.4"`).

## 2) Tech stack and runtime/tooling
- Language: **Lua**.
- Runtime: **LÖVE 11.4** (required to run).
- Content pipeline scripts for folio/tile cards: **PowerShell** scripts in `resources/tiles/`.
- No package manager, no compile step, no repo-local lint/test framework, no repo-local CI workflow files.

## 3) Validated commands and exact behavior
> Always run commands from repo root.

### Bootstrap
1. Install **LÖVE 11.4** (always required for runtime validation).
2. Install **PowerShell** (`pwsh` or Windows PowerShell) only if you need tile/card generation scripts.

Validated in this environment:
- `love --version` → `command not found` (fails fast, ~0.12s).
- `pwsh ...` → `command not found` (fails fast, ~0.09s).

### Run / Build
- Canonical run command: `love .`
- There is no separate build pipeline; for this repo, build validation is a successful `love .` launch.

Validated in this environment:
- `love .` → `command not found` (fails fast, ~0.12s).

### Tests
- No automated tests are present.
- Manual smoke test to run locally (when `love` exists):
  1. `love .`
  2. Verify splash → main menu.
  3. Start gameplay scene and verify no immediate runtime errors.

### Lint / format
- No lint/format config found (`.luacheckrc`, `stylua.toml`, `.stylua.toml` absent).

### Other scripted flows (tile/card generation)
- `resources/tiles/GenerateFolioCards_v2.ps1`: generates `card.txt` (4x5 folio patterns). High-value params: `-Count`, `-Seed`, `-Mode manuscript|balanced`, `-MinWild`, `-MaxWild`, `-MinDistinctSymbols`, `-UniqueGrids`.
- `resources/tiles/RenderFolioPreviews.ps1`: reads `card.txt` and renders PNG folios to `resources/tiles/FolioPreviews/` using local tile images (`1..6.png`, `w.png`, `O.png`).
- `resources/tiles/BuildFolioPreviews_SINGLE_v2.ps1`: end-to-end generation and now forwards generation controls (`-Mode`, wild limits, distinct symbols, uniqueness).
- `resources/tiles/RUN_FOLIOGEN_v2.bat`: Windows wrapper that prefers `pwsh` and falls back to `powershell`.

Practical rule: if a change touches grid/pattern content, always run the PowerShell generator locally and verify that both `card.txt` and `resources/tiles/FolioPreviews/folio_*.png` are produced.

## 4) Reliable workflow for agents
1. `git status --short`
2. `rg --files` for targeted discovery (avoid broad recursive search unless needed).
3. Edit minimal files.
4. Validate what is available:
   - If `love` installed: run `love .` smoke test.
   - If changing tile pipeline and `pwsh` installed: run generator script.
5. `git status --short` again and ensure no unintended artifacts are staged.

If runtime/tools are missing, explicitly report the limitation and avoid claiming unexecuted validation.

## 5) Project layout map (high-signal paths)
- Entry/config:
  - `main.lua` (effective LÖVE entrypoint; module wiring and callbacks)
  - `conf.lua` (window + `t.version = "11.4"`)
- Engine-like root modules: `core.lua`, `render.lua`, `physics.lua`, `geometry.lua`, `view.lua`, `light.lua`.
- Game modules:
  - `src/content/` (pigments, binders, patterns)
  - `src/game/` (folio/run logic)
  - `src/scenes/` (startup splash, main menu, settings, gameplay, reward)
  - `src/ui/` and `src/ui.lua` (HUD/render helpers)
- Assets:
  - `resources/ui/`, `resources/sounds/`, `resources/font/`, `resources/textures/`, `resources/tiles/`, `resources/shaders/`
- Docs/plans:
  - `docs/toolkit/` (design docs)
  - `plan/feature-ui-mainmenu-1.md` (manual validation expectations using `love .`)

## 6) Check-in / CI expectations
- No `.github/workflows/` directory detected in this repo.
- No Make/Just/npm/cargo pipelines detected.
- Pre-checkin confidence should come from:
  1. Local runtime smoke test (`love .`) when available.
  2. Asset path verification for any changed scene/UI code.
  3. For tile pipeline changes, local script run + generated image sanity check.

## 7) Known pitfalls
- `main.lua` is the real LÖVE entrypoint even if `main_game.lua` exists.
- Asset path/case mismatches are a common breakage source.
- PowerShell scripts assume being run from `resources/tiles` context (scripts generally set location to script root).
- `make` is not a valid project build entrypoint (no Makefile).

## 8) Root inventory quick list
- Files: `main.lua`, `conf.lua`, `main_game.lua`, `core.lua`, `render.lua`, `physics.lua`, `geometry.lua`, `view.lua`, `light.lua`
- Directories: `.github/`, `src/`, `resources/`, `docs/`, `plan/`
- `README.md` and `CONTRIBUTING.md` are currently absent.

## 9) Agent policy
- **Trust this file first** to reduce exploration cost.
- Search beyond it only when (a) requested task needs missing details, or (b) instructions are proven outdated/incorrect.
