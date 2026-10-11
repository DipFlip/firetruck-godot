# Colour-aware model blending

The game starts with 25% blending for reusable trees, people and hydrants on both maps. Press **B** while driving to compare 25% with the original art instantly. The pause menu's **Toy shapes** control also offers Original / 10 / 15 / 25 / 50 / 75 / 100%. Comparisons reuse cached meshes and preserve world state and colliders. Roof tiles, the truck and other props retain their authored shapes.

Open the web release with `?models=blend` for the side-by-side comparison, initially at 25%. The optional **Join moving shoulders** checkbox demonstrates the earlier rest-pose experiment; it does not change the game's joint-safe rule. A `?blend=0` URL starts the game with original art, while `?blend=25` explicitly selects the default.

The offline baker uses the same rules for every candidate:

- Only source surfaces that actually touch may join. Identical colours across a gap remain separate.
- People join identical paint colours within one rigid joint. Skin, hair and clothing keep hard boundaries. Dot eyes, buttons, noses and trim retain their original geometry.
- Tree foliage can join across green and golden foliage shades in both tree variants. The trunk and branches retain their exact original triangles and colours. Each rotated leaf ellipsoid is recovered from its source vertices, rather than replaced by its larger bounding box.
- Hydrant red barrels and crossbars join; their yellow caps remain separate. Their smaller geometry uses a finer bake grid.
- Moving shoulders stay separate in gameplay. Joining the arm and torso can be skinned, but it stretches the armpit during raised-arm poses. The preview's optional experiment retains that comparison.

A signed distance field and polynomial smooth minimum generate the joined surfaces; marching tetrahedra extracts the final mesh. Bone weights and rigid-joint membership retain the existing arm, head, walking-leg and blink animations. Held drinks and sandwiches remain separate. Palette uniforms reuse one person mesh across different clothing, skin and hair colours, including the bun hairstyle. Baked LODs reduce geometry in wide views.

There is no voxel or distance-field work in the browser. To regenerate after changing source toys:

```sh
Godot --headless --path . --script tools/export_blend_primitives.gd
python3 tools/build_blend_preview.py
Godot --headless --path . --script tools/bake_blend_preview.gd
```

The Python baker requires NumPy and SciPy. Preview and gameplay resources live in `assets/scenery/blend_*.res`; intermediate buffers live under ignored `builds/blend/`. `tests/colour_blend_rules_test.py` checks source contacts, paint boundaries, exact foliage recovery and joint weights. Run `tests/colour_blending_test.gd` with the Compatibility renderer to verify runtime switching, animations and preserved colliders.
