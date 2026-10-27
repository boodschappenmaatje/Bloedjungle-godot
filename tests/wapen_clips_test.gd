extends SceneTree
## Bewegende wapendelen: slede, hendel en pomp schuiven met echte GLB-clips mee bij een schot (bron/wapens).
## godot --headless --path . -s tests/wapen_clips_test.gd --fixed-fps 60   (vaste tijdstap: een beeld = 1/60 s)
## [wapen, deel, afstand in m]; het wapenmodel heeft de loop langs -Z, dus naar achteren = +Z.
const CASES := [["m1911", "M1911_Slede", 0.034], ["thompson", "Thompson_Repeerknop", 0.022], ["garand", "Garand_Sluiting", 0.045],
	["trench", "Trench_Pomp", 0.07], ["mg42", "MG42_Repeergreep", 0.03]]
var failures := 0


func _check(ok: bool, msg: String) -> void:
	print("%s  %s" % ["OK  " if ok else "FAIL", msg])
	if not ok:
		failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _z(model: SoldierModel, part: String) -> float:
	var gun := model.get("_gun") as Node3D
	return (gun.find_child(part, true, false) as Node3D).position.z


func _run() -> void:
	GameSettings.values["soldaat"] = "vq2"
	for c in CASES:
		var model := SoldierModel.new()
		root.add_child(model)
		model.setup(Color("4b5a2c"), c[0], "speler:uniform")
		await process_frame
		var rest := _z(model, c[1])
		var peak := rest
		model.shoot_recoil(c[0])
		for _i in 30:
			await process_frame
			peak = maxf(peak, _z(model, c[1]))
		_check(absf((peak - rest) - float(c[2])) < 0.003, "%s: %s schuift %.3f m naar achteren (verwacht %.3f)" % [c[0], c[1], peak - rest, c[2]])
		for _i in 30:
			await process_frame
		_check(absf(_z(model, c[1]) - rest) < 0.002, "%s: %s staat weer in rust" % [c[0], c[1]])
		if c[0] == "m1911":
			model.shoot_recoil("m1911", true)
			for _i in 20:
				await process_frame
			_check(absf(_z(model, c[1]) - rest - 0.034) < 0.003, "m1911: slede blijft open bij een leeg magazijn")
			model.gun_reset()
			await process_frame
			_check(absf(_z(model, c[1]) - rest) < 0.002, "m1911: slede sluit na herladen (gun_reset)")
		model.queue_free()
	_check((SoldierModel.new().get("_gun_anim")) == null, "mannetje zonder wapen heeft geen clips")
	print("WAPENCLIPS TEST ", "OK" if failures == 0 else "FAIL: %d" % failures)
	quit(failures)
