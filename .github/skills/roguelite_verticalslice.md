---
name: roguelite-vertical-slice
description: Guida per costruire un vertical slice roguelite da zero in incrementi verificabili (menu→run→reward→gameover→meta). Usa quando pianifichi o costruisci gameplay loop.
---

# roguelite-vertical-slice

## Output atteso
- Un playable minimo end-to-end
- Contenuti data-driven in `src/content`
- Checkpoint di verifica ad ogni step

## Milestones
1) Skeleton LÖVE + state machine
2) Arena/room + player movement + una meccanica base
3) Un nemico + spawn + morte + reset
4) Reward + scelta (UI) + applicazione effetto
5) Gameover + meta-progression stub + save/load

## Regole
- Ogni milestone ha DoD e test manuale riproducibile.
- Niente “feature enorme” senza prototipo minimo.
