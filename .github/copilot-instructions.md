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

# Knowledge Base (manuali locali)
Questo repository contiene manuali di riferimento in `docs/manuals/` e `docs/toolkit/`.
Quando rispondi o implementi, usa i manuali come fonte primaria quando rilevante.

## Manuali
- docs/manuals/Basic_Computer_Coding_Lua_Podkovyroff_2024.pdf  (Lua: syntax, functions, tables, libs, error handling, modules)
- docs/manuals/Mathematics_of_Game_Development_Enfield_2024.pdf (math per gamedev: vectors/matrices, trig, dot/cross, reflection)
- docs/toolkit/Game_Design_Toolkit.docx (design: pillars, MDA, loops, variety matrix, test cards)

## Manual Consultation Protocol (obbligatorio)
1) Se la richiesta riguarda Lua/LÖVE, moduli, errori, strutture dati → cerca prima nel manuale Lua.
2) Se riguarda fisica, 3D, collisioni, vettori, facce del dado, dot/cross, trig → cerca prima nel manuale di matematica.
3) Se riguarda design/idee/loop/bilanciamento/varietà/testing → usa il Toolkit.
4) Prima di dare una risposta “definitiva”: fai `search` nei manuali con keyword e apri la sezione rilevante.
5) Nelle risposte: indica “Fonte: <manuale>, capitolo/sezione” (senza copiare lunghi passaggi; parafrasa).
6) Se i manuali non sono presenti nel workspace, chiedi di aggiungerli nella cartella `docs/manuals/`.

## Copyright & quoting
Parafrasa. Se devi citare, usa estratti brevi.
