
# Copilot instructions for 3D-studio (aggiornate 2026)

## Repository summary
- **Purpose**: Love2D Lua project, gameplay 2D roguelite, dadi 3D fisici e vassoio 3D con pipeline moderna (g3d). Legacy helpers in `stars.lua`. Entry point: `main.lua`.
- **3D pipeline**: Solo dadi e vassoio sono 3D (mesh, fisica, materiali, texture, ombre, animazione lancio, suoni impatto, rilevamento faccia superiore). Tutto il resto è 2D.
- **Librerie**: g3d (mesh, camera, materiali, collisioni), texture PNG per facce dadi, suoni WAV/OGG opzionali.
- **Languages/runtime**: Lua (Love2D 11.x, LuaJIT compatibile).

## Build / run / test / lint / validation
- **Run**: `love .` dalla root (necessario per asset path). Usa `run.bat` su Windows.
- **No build step**: Lua interpretato da Love2D.
- **No test/lint/CI**: Tutto manuale.

## Project layout / architecture
- **Root**: `.github/`, `g3d/`, `default/`, `textures/`, `main.lua`, `dice3d.lua`, `conf.lua`, `render.lua`, `geometry.lua`, `stars.lua`, ecc.
- **3D core**: `dice3d.lua` (gestione dadi, tray, animazione lancio, fisica, materiali, ombre, suoni, faccia superiore).
- **Assets**: `cube.obj`, `plane.obj`, `textures/dice_face1.png` ... `dice_face6.png`, suoni in `sounds/`.
- **Entry points**: `main.lua` (richiama dice3d), `conf.lua` (config Love2D).


## 3D dice/tray best practices
- **Camera 3D**: la scena dadi/vassoio richiede una camera 3D (es. `g3d.newCamera`).
	- Setup tipico: camera fissa o orbitale, posizione sopraelevata e centrata sul vassoio.
	- Attiva la camera con `camera:activate()` prima del rendering 3D e `camera:deactivate()` dopo.
- **Import**: `local dice3d = require("dice3d")` in `main.lua`.
- **Init**: `dice3d.load()` in `love.load`.
- **Update**: `dice3d.update(dt)` in `love.update`.
- **Draw**: `dice3d.draw()` in `love.draw`.
- **Roll**: `dice3d.roll()` per animazione lancio e lancio fisico.
- **Faccia superiore**: usa `dice3d.getTopFace(i)` (se implementato) per sapere il valore del dado i.

## Features 3D attuali
- Mesh dadi e tray da OBJ
- Texture PNG sulle facce dei dadi
- Colori/materiali diversi per dadi, tray, bordi
- Ombre semplici sotto i dadi
- Animazione di lancio (shake pre-roll)
- Fisica base: collisioni, attrito dinamico, rallentamento
- Suoni di impatto/collisione (se presenti in `sounds/`)
- Rilevamento faccia superiore (in sviluppo)

## TODO 3D
- Migliorare rilevamento faccia superiore (orientamento mesh)
- Effetti particellari (pigmenti, polvere)
- UI integrata con risultati dadi

## Trust these instructions
Queste note sono la fonte di verità per la pipeline dadi 3D. Aggiorna qui ogni nuova feature o best practice.
