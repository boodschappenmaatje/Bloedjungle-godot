extends SceneTree
## De truck rijdt strak recht de nieuwe garage uit: tot hij helemaal buiten de poort is blijft hij in lijn (yaw en x),
## en de slot-regel (exit_lock) valt daarna weg. Ook bij een garage die gedraaid staat.
## godot --headless --path . -s tests/garage_truck_uit_test.gd --fixed-fps 60

var main: Node
var frames := 0
var fails := 0
var gar: Variant
var v: Node3D
var max_dev := 0.0
var max_yaw_dev := 0.0
var lock_cleared_at := -1.0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _check(name: String, ok: bool) -> void:
	print(("OK   " if ok else "FOUT ") + name)
	if not ok:
		fails += 1


func _process(_d: float) -> bool:
	frames += 1
	var g = root.get_node("Game")
	if frames == 2:
		main.get_node("Hud/Sticks").set_process(false)
	if frames == 4:
		main.begin()
		g.player.global_position = Vector3(-6, 0, -9)
	if frames == 8:
		var b = g.builds
		g.points = 100000
		g.build_credit = 100000
		b.place("kazerne", Vector3(-6, 0, -8), PI)
		gar = b.place("garage", Vector3(16, 0, 2), 0.0)
		b.buy_vehicle(gar, "truck")
	if frames > 8 and gar != null:
		if v == null and is_instance_valid(gar.veh):
			v = gar.veh
			_check("truck heeft een uitrijslot", not v.exit_lock.is_empty())
		if v != null and is_instance_valid(v):
			var rel: Vector3 = v.global_position - gar.at
			if not v.exit_lock.is_empty():
				max_dev = maxf(max_dev, absf(rel.x - g.builds.DOOR_U))
				max_yaw_dev = maxf(max_yaw_dev, absf(wrapf(v.rotation.y - (gar.yaw + PI), -PI, PI)))
			elif lock_cleared_at < 0.0:
				lock_cleared_at = rel.z
	if frames == 8 + 700:
		_check("zijwaartse afwijking in de poort %.3f m" % max_dev, v != null and max_dev < 0.05)
		_check("draaiing in de poort %.4f rad" % max_yaw_dev, max_yaw_dev < 0.01)
		_check("slot valt weg als hij buiten is (z=%.1f)" % lock_cleared_at, lock_cleared_at > g.builds.FRONT + 5.0)
		_check("truck staat stil buiten de garage", v != null and (v.global_position - gar.at).z > g.builds.FRONT + 5.0 and v.goals.is_empty())
		print("klaar, fouten: ", fails)
		quit(1 if fails > 0 else 0)
	return false
