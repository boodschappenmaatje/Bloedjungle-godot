extends SceneTree
## Verify the active viewport after quality changes, not only project defaults.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var atmosphere: Node3D = (load("res://scripts/atmosphere.gd") as GDScript).new()
	root.add_child(atmosphere)
	for quality in ["high", "low", "ultra", "low", "high"]:
		atmosphere.call("_apply_quality", quality)
		var expected := Viewport.MSAA_DISABLED if quality == "low" else Viewport.MSAA_4X
		_check(root.msaa_3d == expected, "Quality change must apply geometry antialiasing to the active viewport: " + quality)
	for path in ["dry_earth/base_color.jpg", "dry_earth/normal_gl.jpg", "grass/base_color.jpg", "jungle_ground/base_color.jpg", "gravel_rock/base_color.jpg", "gravel_rock/normal_gl.jpg", "gravel_rock/roughness.jpg", "surfaces/gravel_rock.png"]:
		var texture := load("res://assets/textures/terrain/" + path) as Texture2D
		_check(texture != null and texture.get_image().has_mipmaps(), "Terrain texture needs mipmaps: " + path)
	atmosphere.free()
	print("SURFACE FILTERING TEST %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(0 if failures == 0 else 1)
