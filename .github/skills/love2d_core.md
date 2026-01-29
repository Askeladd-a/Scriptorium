---
name: love2d-core
description: LÖVE2D core patterns: entrypoints, state machine, fixed timestep, filesystem, input, debug overlay, seed deterministico. Usa quando crei base progetto o tocchi loop/update/draw.
---

# love2d-core

## Quando usarla
- bootstrap progetto LÖVE
- bug nel loop, input, draw order
- bisogno di seed riproducibile / salvataggi
- creazione debug overlay

## Procedura standard (MVP pulito)
1) Verifica entrypoints in `main.lua`: love.load / love.update / love.draw / input callbacks.
2) Introduci state machine minima: menu → run → gameover.
3) Aggiungi RNG seed run-level (salva seed + riproducibilità).
4) Debug overlay togglable (FPS, seed, state, dt, contatori).
5) Se serve stabilità simulazioni: fixed timestep con accumulator.

## Fixed timestep (template)
- accumulator += dt
- while accumulator >= step do simulate(step); accumulator -= step end
- render interpolato opzionale

## Evidence Gate
- prima leggi `main.lua`, `conf.lua`, e i moduli di stato prima di proporre refactor.
