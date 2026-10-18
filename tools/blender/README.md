# Blender models

Every 3D model in Mow A Lawn is a Python script in `models/`, built headless in Blender 4.2:

```bash
blender -b -P tools/blender/build.py -- oak birch      # build some models
blender -b -P tools/blender/build.py -- all            # build everything
```

Output: `assets/models/<name>.glb` (uploaded to Roblox) and `assets/previews/<name>.png` (Cycles render to check the look).

## Conventions (the uploader relies on these)

- 1 Blender unit = 1 Roblox stud. A Roblox character is about 5 studs tall, a door about 7.
- Models stand on the ground at z = 0, centred on x = y = 0. The model's FRONT faces Blender **+Y**.
- Every object gets a material from `lib.material(kind, (r, g, b))`, where `kind` is a Roblox material name
  (`Wood`, `WoodPlanks`, `Grass`, `Metal`, `Neon`, `SmoothPlastic`, `Plastic`, `Fabric`, `Slate`, `Ground`, ...).
  On export all parts with the same material are joined into one mesh named `<Kind>__<RRGGBB>`; in Roblox each
  becomes a MeshPart with that Roblox Material and Color, so models get Roblox's own textures.
- Keep each model under ~4,000 triangles and under ~8 material slots.
- Shapes: `lib.box` (with optional `taper` and `bevel`), `lib.cyl` (with `top_scale` for cones), `lib.wedge`,
  `lib.sphere`, `lib.rotated` for placing things around a centre. Use small bevels (0.05 to 0.3) on everything:
  the reference game's props are chunky, bevelled and readable, never paper-thin.
- `PREVIEW = dict(dist=..., height=..., target_z=..., yaw=...)` in a model file sets its preview camera.

## Look (match the reference game, Chop A Forest)

Chunky low-poly, slightly bevelled blocks with Roblox materials: wood grain on wood, grass texture on leaves and
ground, warm saturated colours, log-cabin buildings with stacked round logs and plank roofs, orange/yellow machines
with black-and-yellow hazard stripes. Reference screenshots are in the session scratchpad `ref/` folder.
