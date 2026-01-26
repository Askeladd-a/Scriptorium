# Porting to g3d (immediate switch)

This project now prefers the **g3d** backend by default (`config.render_backend = "g3d"`).
When `g3d.lua` is not present in the project root, the app will automatically fall back to the legacy renderer.

## 1) Add g3d to the project
Place the `g3d.lua` file next to `main.lua` (same folder as `conf.lua`).

Directory layout example:

```
dice3d/
  g3d.lua
  main.lua
  render_g3d.lua
  assets/
    models/
    textures/
```

## 2) Models and textures
Basic placeholder models are included:

- `assets/models/die.obj`
- `assets/models/tray.obj`

Textures reuse existing project assets (`textures/1.png` for dice and `default/marble.png` for the tray)
to avoid introducing new binary files. Replace them with proper UV‑mapped textures when ready.

## 3) What still needs work
The g3d renderer now syncs both **positions and rotations** using a stored quaternion on each star.
The remaining work is to ensure the rotation mapping matches your intended dice orientation and
to replace the placeholder assets with proper UV‑mapped models.

## 4) Switching back to legacy
Set `config.render_backend = "legacy"` in `default/config.lua` to return to the old renderer.

## 5) Minimal reference
If you want a tiny 3D reference project while iterating on g3d usage, the author’s
`simplest_3d` repo can be a helpful guide for camera and render setup.
