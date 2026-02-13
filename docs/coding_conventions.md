# Coding Conventions

## Scope

These rules apply to `main.lua`, `core.lua`, and everything under `src/`.

## Language

- Use English for identifiers, module names, comments, and log messages.
- Use English for all player-facing UI text.

## Naming

- Modules/classes: `PascalCase` tables (example: `Run`, `Scriptorium`).
- Public methods on module/class tables: `camelCase` (example: `commitWetBuffer`).
- Local/private helpers and variables: `snake_case` (example: `get_controls_dock_height`).
- Constants: `UPPER_SNAKE_CASE` (example: `REF_W`, `CONSTRAINT_LINES`).
- File names: `snake_case.lua`.

## Project Lexicon

- Use `folio_set` for run size progression (`BIFOLIO`, `DUERNO`, ...).
- Use `wet_buffer` for temporary, not-yet-committed placements.
- Use `turn_risk` for stain risk accumulated during the current turn.
- Use `preparation_guard` for guard points created by PREP.
- Use `*_button` suffix for clickable UI hitboxes in `ui_hit` (example: `roll_button`).
- Use `dice_value` / `dice_color` for die payload fields and parameters.

## Structure

- Keep modules focused:
  - `src/features/*` for gameplay/UI feature slices (main menu, settings, scriptorium, reward).
  - `src/features/<feature>/*` for internal split (`module`, `actions`, `layout`, `hud`, `overlays`, ...).
  - `src/domain/*` for gameplay domain models and rules (`folio`, `run`, turn logic, scoring).
  - `src/core/*` for engine/runtime plumbing.
- Avoid duplicated domain classes across files (single source of truth).

## Formatting

- Canonical formatter config: `stylua.toml`.
- Canonical lint config: `.luacheckrc`.
- Run checks with:
  - `powershell -File scripts/lint.ps1`
  - `powershell -File scripts/test.ps1`

## Exceptions

- Keep exceptions minimal and explicit in config files.
- Do not add one-off disables in source unless strictly required by runtime constraints.
