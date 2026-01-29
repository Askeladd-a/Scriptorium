---
name: dice3d
description: Micro-3D (dadi + tray) con collisione/fisica in LÖVE2D. Include API modulo, checklist stabilità, decision matrix tecnologia e gating checks. Usa quando implementi o debugg(i) dice/tray.
---

# dice3d (micro-3D)

## API modulo (stabile)
- dice3d.init(config)
- dice3d.spawnDice(n, params)
- dice3d.roll(id, impulse, torque, seed?)
- dice3d.update(dt)  (fixed timestep)
- dice3d.draw(camera)
- dice3d.getResult(id)  (quando “a riposo”)

## Checklist tecnica
- fixed timestep + accumulator
- sleep robusto: soglie vel lin/ang per N frame
- faccia superiore: max dot(worldUp, faceNormalWorld) → mapping 1..6
- tray collision MVP con forme semplici → refine
- debug overlay: id, vel, sleep, faccia, risultato

## Technology Decision Matrix
Assi (priorità): portabilità/setup, stabilità build, realismo, determinismo, tempo MVP.

| Opzione | Rendering | Collisione/Fisica | Pro | Contro | Quando |
|---|---|---|---|---|---|
| A (Preferita) | 3D leggero | fisica 3D vera | realismo alto | dipendenze native | desktop + build ok |
| B (Pragmatica) | 3D leggero | collision detect 3D + sim controllata | portabile | meno realismo | se A blocca |
| C (MVP ultra) | 2.5D fake | 2D physics + mapping | rapidissima | non vera 3D | solo con consenso |
| D (Controllata) | 3D leggero | roll animato + risultato deterministico | stabile/bilanciabile | non fisico | controllo totale |

Policy: tenta A, se attrito passa a B, C/D solo con consenso.

## Gating checks (obbligatori)
- init ok (no crash)
- spawn 1 dado + tray
- roll con impulse/torque
- sleep + face detection
- demo in `scratch/` osservabile (overlay)

Se fallisce: documenta error/log, proponi fallback (A→B→D), mantieni API invariata.
