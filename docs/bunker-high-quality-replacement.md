# High Quality Showcase bunker replacement

`BaseProps._bunker()` now attaches the baked **High Quality Showcase** GLB as its visible model. The existing gameplay body remains a separate `StaticBody3D` at the same origin, with the same `Kit.LAYER_BUNKER` layer, disabled collision mask, 4.6 × 2.0 × 4.6 m `BoxShape3D`, and `scripts/bunker.gd` damage/FX behavior. The surrounding sandbag ring and all gates, walls, routes and purchase interactions are unchanged.

The source bunker is 8.4 × 4.85 × 7.2 m. Its Godot visual scale fits the previous 4.6 m X/Z footprint (`0.547619, 0.55, 0.638889`), retaining a 2.67 m authored roof silhouette. The original collider remains 4.6 × 2.0 × 4.6 m; this intentionally preserves the established pathing and targeting contract. Roof geometry therefore remains visual and does not add a new roof collision surface, matching the previous bunker.

The entrance door is part of the baked GLB and faces the existing south/+Z approach. This bunker has no player-enter/door-open action in the game code; its existing interaction is as the base damage target. The replacement test verifies the GLB door material and that damage remains routed through the original bunker script.

Run the targeted contract test with the project's Godot 4.7.2 binary:

```sh
godot --headless --path . -s tests/bunker_hq_replacement_test.gd
```

See [`assets/bunker/README.md`](../assets/bunker/README.md) for the pipeline source, game blend, export command and GLB validation receipt. No shared OTA publication is performed by this change.
