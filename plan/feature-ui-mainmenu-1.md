---
goal: "Import splash and main menu design assets & UI into LÖVE2D project"
version: 1.0
date_created: 2026-02-09
last_updated: 2026-02-09
owner: "Dev: Davide"
status: 'Planned'
tags: ["feature","ui","import","splash","main_menu"]
---

# Introduction

![Status: Planned](https://img.shields.io/badge/status-Planned-blue)

This plan describes deterministic, step-by-step actions to import the provided "main menu design" (external React/Vite design assets) into the existing LÖVE2D Lua project so the project will display a splash screen and a redesigned main menu using the provided assets.

All tasks are fully specified with exact file paths, function names, validation checks and measurable completion criteria so an automated agent or a human can execute them without further interpretation.

## 1. Requirements & Constraints

- **REQ-001**: Import visual assets from the folder at: `C:\Users\Davide\Desktop\main menu design\src\assets` into the project's resources folder: `resources/ui/`.
- **REQ-002**: Import fonts from `C:\Users\Davide\Desktop\main menu design\src\assets\fonts` (if present) into `resources/font/` and register usage in `src/scenes/main_menu.lua`.
- **REQ-003**: Ensure splash image is available at `resources/ui/splash.png` and menu background at `resources/ui/menu.png`.
- **REQ-004**: Main menu must be playable with keyboard and mouse using functions `MainMenu:draw`, `MainMenu:keypressed`, `MainMenu:mousepressed`, `MainMenu:mousemoved` in `src/scenes/main_menu.lua`.
- **REQ-005**: Splash scene must display for a configurable duration and then switch to main menu using `SceneManager.switch("MainMenu")` from `src/scenes/splash.lua`.
- **SEC-001**: Do not change external network dependencies; all assets must be local.
- **CON-001**: The project uses LÖVE 11.x APIs; code must be compatible.
- **GUD-001**: Preserve existing scene manager API: `require('src.core.scene_manager')` and scene lifecycle methods `enter/update/draw/exit`.

## 2. Implementation Steps

### Implementation Phase 1

- GOAL-001: Copy assets and fonts into project resources and verify presence.

| Task | Description | Completed | Date |
| ---- | ----------- | --------- | ---- |
| TASK-001 | Copy folder `C:\Users\Davide\Desktop\main menu design\src\assets` -> `resources/ui/` (preserve filenames). | ✅ | 2026-02-09 |
| TASK-002 | Copy fonts from `...\src\assets\fonts` -> `resources/font/` and ensure `EagleLake-Regular.ttf` or similar is present. | ⛔ skipped (no fonts in source) | 2026-02-09 |
| TASK-003 | If audio assets exist in `...\src\assets\audio` copy to `resources/sounds/` and ensure `maintitle.ogg` is present or convert a provided audio file to OGG named `maintitle.ogg`. | ⛔ skipped (no audio found) | 2026-02-09 |

Completion criteria phase 1: `love.filesystem.getInfo('resources/ui/splash.png') == true` and `love.filesystem.getInfo('resources/ui/menu.png') == true` and a font file exists at `resources/font/*.ttf`.

### Implementation Phase 2

- GOAL-002: Update splash scene to use the imported splash image and add optional fade-in/fade-out.

| Task | Description | Completed | Date |
| ---- | ----------- | --------- | ---- |
| TASK-004 | Edit file `src/scenes/splash.lua`: ensure functions `Splash:enter`, `Splash:update`, `Splash:draw`, `Splash:keypressed`, `Splash:mousepressed` load and use `resources/ui/splash.png`. | ❌ | |
| TASK-005 | Add a configurable `DURATION` constant at top of `src/scenes/splash.lua` and ensure `timer` triggers `SceneManager.switch('MainMenu')`. | ❌ | |

Implementation details (exact edits to perform):
- In `src/scenes/splash.lua` at top, ensure:
  - local DURATION = 1.6 -- (or 2.0 if preferred)
  - local logo = nil
  - function Splash:enter() -> timer=0; if not logo and love.filesystem.getInfo('resources/ui/splash.png') then logo = love.graphics.newImage('resources/ui/splash.png') end
  - function Splash:update(dt) -> timer=timer+dt; if timer>=DURATION then require('src.core.scene_manager').switch('MainMenu') end
  - function Splash:draw() -> clear screen, draw logo centered, or fallback to title text

Validation criteria phase 2: Running the game shows the splash image centered for DURATION seconds then transitions to main menu when run with `love .`.

### Implementation Phase 3

- GOAL-003: Integrate the visual design into `src/scenes/main_menu.lua`.

| Task | Description | Completed | Date |
| ---- | ----------- | --------- | ---- |
| TASK-006 | Ensure `src/scenes/main_menu.lua` references `resources/ui/menu.png` as `menu_bg` and falls back gracefully. | ❌ | |
| TASK-007 | Adjust UI constants in `src/scenes/main_menu.lua`: button size, padding, color values to match the provided design palettes. Exact variables to update: `btn_w`, `btn_h`, `left_x`, `stack_y`, `spacing`. | ❌ | |
| TASK-008 | Use font loaded from `resources/font/<name>.ttf` by setting `menu_font = love.graphics.newFont('resources/font/<name>.ttf', 32)` inside `MainMenu:enter()`. | ❌ | |
| TASK-009 | Wire up menu actions to existing scenes: `Start Game` -> `Scriptorium` (ensure exact case matches existing scene file name), `Quit` -> `love.event.quit()`. | ❌ | |

Implementation details (exact edits):
- In `src/scenes/main_menu.lua` within `MainMenu:enter()` ensure code block that loads menu_bg checks `love.filesystem.getInfo('resources/ui/menu.png')` and then `menu_bg = love.graphics.newImage('resources/ui/menu.png')`.
- Replace color literals with design palette (if palette files present in the assets, copy or transcode CSS `theme.css` color tokens into the RGBA values). Example replacements:
  - Selected color -> {0.93,0.8,0.28,1}
  - Hover color -> {0.95,0.85,0.45,1}
  - Default button -> {0.33,0.24,0.12,1}
- Ensure `MainMenu:mousemoved`, `MainMenu:mousepressed`, and `MainMenu:keypressed` behave as interactive hooks (they already exist; verify indices and `menu_items` labels match desired actions).

Validation criteria phase 3: Starting the game lands on the main menu with background image (if present), styled buttons, and input works by keyboard and mouse.

### Implementation Phase 4

- GOAL-004: Optional polish: add fade transitions, button hover sounds, and small animated logo.

| Task | Description | Completed | Date |
| ---- | ----------- | --------- | ---- |
| TASK-010 | Add fade alpha variable in `Splash` and `MainMenu` and draw overlay with love.graphics.setColor(0,0,0,alpha) for smooth transitions. | ❌ | |
| TASK-011 | If `resources/sounds/ui` includes click/hover samples, wire them in `MainMenu:mousepressed` and `MainMenu:mousemoved`. | ❌ | |

Validation criteria phase 4: transitions show smooth fade and click sounds play.

## 3. Alternatives

- **ALT-001**: Re-implement entire menu UI using an HTML/CSS overlay via an embedded browser (not chosen because it adds heavy native deps and breaks LÖVE portability).
- **ALT-002**: Use a lightweight Lua UI library (suit, quickie) for buttons (not chosen to keep custom drawn look and prevent extra dependency).

## 4. Dependencies

- **DEP-001**: Local asset folder: `C:\Users\Davide\Desktop\main menu design\src\assets` (source of images/fonts/CSS)
- **DEP-002**: LÖVE runtime available to run and visually test the scenes.

## 5. Files

- **FILE-001**: `resources/ui/` - target folder to receive copied visual assets (splash.png, menu.png, other images)
- **FILE-002**: `resources/font/` - target folder to receive fonts
- **FILE-003**: `src/scenes/splash.lua` - edited to ensure image load, DURATION, and transition
- **FILE-004**: `src/scenes/main_menu.lua` - adjusted to use imported assets and design palette

## 6. Testing

- **TEST-001**: Run the game: `love .` from project root. Verify visually: splash image appears centered and after DURATION seconds transitions to main menu.
- **TEST-002**: On main menu, verify keyboard Up/Down and Enter/Space navigate and activate items. Verify mouse hover highlights buttons and clicking activates.
- **TEST-003**: If audio copied, verify `maintitle.ogg` plays on loop at lowered volume.

Automated verification steps (scriptable):
1. File existence checks:
   - `love.filesystem.getInfo('resources/ui/splash.png')` -> truthy
   - `love.filesystem.getInfo('resources/ui/menu.png')` -> truthy
   - `love.filesystem.getInfo('resources/font/<font>.ttf')` -> truthy
2. Start the game headless assertion (if supported) or run an integration smoke test and assert `SceneManager.current == 'MainMenu'` after DURATION+0.5s.

## 7. Risks & Assumptions

- **RISK-001**: Asset filenames in the provided design folder may not match the names used in the current Lua code (assumption: we will copy and/or rename them to `splash.png` and `menu.png`).
- **ASSUMPTION-001**: The project uses standard LÖVE filesystem layout; runtime can access `resources/` paths directly.

## 8. Related Specifications / Further Reading

- LÖVE API: https://love2d.org/wiki/Main_Page
- Project guidelines: `docs/toolkit/GAME_PILLARS.md`

---

Execution note (deterministic):
- To execute: copy asset folder as listed in TASK-001/TASK-002, then apply the Lua edits described in TASK-004..TASK-009. Each edit is atomic and includes exact file paths and function names. After copying assets run `love .` to validate.
