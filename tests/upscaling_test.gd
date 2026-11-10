extends SceneTree
## Test: Upscaling-instelling (stand, band voor de resolutieregelaar, terugval zonder MetalFX).
## Draaien: godot --headless --path . -s tests/upscaling_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0


func _initialize() -> void:
	GameSettings.set_value("quality", "high")
	GameSettings.set_value("upscaling", "quality")
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("UPSCALING TEST: " + msg)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		main.begin()
	if frames == 8:
		var U: GDScript = load("res://scripts/upscaling.gd")
		var atm: Node = get_first_node_in_group("atmosphere")
		var vp := root.get_viewport()
		# geen MetalFX (headless): stand doet niets, beeld blijft zoals de grafiekstand
		U.set("force_support", 0)
		atm.apply_settings()
		_check(not U.call("active"), "zonder MetalFX niet actief")
		_check(vp.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR, "zonder MetalFX bilineair")
		_check(absf(vp.scaling_3d_scale - 1.0) < 0.01, "zonder MetalFX met Graphics 2.0: Hoog op volle resolutie, kreeg %.2f" % vp.scaling_3d_scale)
		GameSettings.set_value("g2", "off")
		atm.apply_settings()
		_check(absf(vp.scaling_3d_scale - 0.8) < 0.01, "zonder MetalFX, klassiek: schaal van Hoog (0,8), kreeg %.2f" % vp.scaling_3d_scale)
		GameSettings.set_value("g2", "on")
		atm.apply_settings()
		_check(U.call("effective_quality") == "high", "zonder MetalFX grafiek Hoog")
		# met MetalFX: Ultra-effecten, band van de stand, SMAA
		U.set("force_support", 1)
		for k in ["quality", "balanced", "performance"]:
			GameSettings.set_value("upscaling", k)
			atm.apply_settings()
			var b: Dictionary = U.call("band")
			var st: Dictionary = U.get("STANDS")[k]
			_check(U.call("active"), k + " actief")
			_check(U.call("effective_quality") == "ultra", k + " geeft Ultra-effecten")
			_check(absf(vp.scaling_3d_scale - st.scale) < 0.01, k + " begint op de schaal van de stand")
			_check(b.min < b.start and b.start < b.max, k + " band klopt")
			_check(vp.screen_space_aa == Viewport.SCREEN_SPACE_AA_SMAA, k + " SMAA")
		GameSettings.set_value("upscaling", "off")
		atm.apply_settings()
		_check(not U.call("active"), "Uit is niet actief")
		_check(vp.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA, "Uit: FXAA")
		U.set("force_support", -1)
		print("KLAAR, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
