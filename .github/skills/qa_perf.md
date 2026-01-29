---
name: qa-perf
description: QA e performance per LÖVE2D: strict QA rule, debug root-cause, riduzione GC/stutter, checklist run/package. Usa dopo implementazioni o quando c’è lag/bug difficile.
---

# qa-perf

## Strict QA Rule (sempre)
Dopo ogni edit:
1) sintassi/coerenza
2) require/path/duplicati
3) feature/fix presente davvero
4) verifica contro DoD

## Perf protocol
- identifica hot paths in update/draw
- riduci allocazioni per frame
- caching/pooling dove utile
- verifica con scenario stress + overlay contatori

## Release quick notes
- Packaging `.love` e zip: seguire la wiki “Game Distribution” quando serve.
