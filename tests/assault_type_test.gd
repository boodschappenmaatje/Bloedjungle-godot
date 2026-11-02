extends SceneTree
var failures := 0
func _initialize() -> void:
	var wave := Data.build_wave(1)
	_check(wave.has("assault"), "first wave does not include the canonical Assault")
	_check(Data.ETYPES.has("assault"), "assault enemy data missing")
	_check(String(Data.ETYPES.assault.get("gun", "")) == "garand", "Assault is not assigned the existing Garand system")
	var enemy: Node = load("res://scenes/enemy.tscn").instantiate()
	enemy.setup("assault", 1)
	_check(enemy.type == "assault", "enemy scene does not retain the assault class id")
	_check(float(enemy.max_hp) == float(Data.ETYPES.assault.hp), "Assault health differs from standard rifle balance")
	enemy.free()
	if failures == 0: print("ASSAULT TYPE TEST PASS: first-wave spawn data, class identity, Garand config and rifle balance")
	quit(1 if failures > 0 else 0)
func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("ASSAULT TYPE TEST: " + message)
