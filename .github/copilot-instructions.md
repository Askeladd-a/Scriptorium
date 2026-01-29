# Project rules (LÖVE2D roguelite + micro-3D)

## Evidence Gate (anti-risposte generiche)
- Non proporre soluzioni “finali” senza prima leggere file rilevanti.
- Ogni risposta deve includere una sezione **Evidence**:
  - Files read: …
  - Commands run: …
  - Docs consulted: …

## Workflow
- Prima: riformula richiesta + DoD + piano breve.
- Poi: cambi piccoli e verificabili.
- Dopo ogni edit: verifica (run/test/checklist).

## Architettura (guardrail)
- Mantieni separati: src/core, src/game, src/content, src/render, src/dice3d, src/ui, src/input.
- Contenuti e bilanciamento devono essere data-driven (src/content).
- Ogni run deve avere seed riproducibile (salvabile).

## Dice3D
- La parte dadi/tray deve stare in src/dice3d con API stabile.
- Se la scelta tecnologica è incerta: fai un “proof-of-life” in scratch/ prima di adottarla.

## Docs
- Preferisci prima: codice del repo.
- Poi: LÖVE API reference (love-api) e wiki LÖVE.
- Web/issue tracker solo per troubleshooting, poi verifica localmente.
