extends SceneTree
## Combatvisuals: alle spelerswapens, projectileffecten, bovenlichaamblend, shotgunpomp en begrensde FX.
## Draaien: godot --headless --path . -s tests/combat_visuals_test.gd --fixed-fps 60

var failures: Array[String] = []
var main: Node
var game: Node
var player: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("COMBAT VISUALS TEST: " + message)


func _frames(n: int) -> void:
	for _i in n:
		await physics_frame


func _bullets() -> Array:
	var found: Array = []
	for child in main.get_children():
		if child is Node3D and child.get_script() != null and child.get_script().resource_path == "res://scripts/bullet.gd":
			found.append(child)
	return found


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")
	for _i in 3:
		await process_frame
	main.get_node("Hud/Sticks").set_process(false)
	await main.call("begin")
	for _i in 3:
		await process_frame
	player = game.player
	player.global_position = Vector3(0.0, 0.0, 40.0)
	await _frames(3)

	# Deze waarden zijn de bestaande gameplaywaarden; de upgrade hoort die niet te veranderen.
	var expected_damage := {"m1911": 26.0, "thompson": 18.0, "garand": 80.0, "trench": 16.0, "mg42": 27.0, "bazooka": 240.0}
	for id in Data.WEAPON_ORDER:
		_check(Data.WEAPON_VISUALS.has(id), "%s mist een visueel wapenprofiel" % id)
		_check(is_equal_approx(float(Data.WEAPONS[id].dmg), expected_damage[id]), "%s schadewaarde is veranderd" % id)
		_check(float(Data.WEAPON_VISUALS[id].recoil) > 0.0, "%s mist wapenspecifieke terugslag" % id)
		if not game.owned.has(id):
			game.owned[id] = {"up": {"dmg": 0, "rate": 0, "mag": 0, "rel": 0}, "ammo": Data.WEAPONS[id].mag}
		if not game.loadout.has(id):
			game.loadout.append(id)
		player.call("equip", id)
		player.set("ammo", Data.WEAPONS[id].mag)
		player.set("fire_t", 0.0)
		var before := _bullets().size()
		player.call("_shoot", game.wstat(id))
		var spawned := _bullets().slice(before)
		var expected_count: int = Data.WEAPONS[id].pellets
		_check(spawned.size() == expected_count, "%s vuurt %d projectielen af i.p.v. %d" % [id, spawned.size(), expected_count])
		_check(int(player.get("ammo")) == int(Data.WEAPONS[id].mag) - 1, "%s verbruikt onjuiste munitie" % id)
		if not spawned.is_empty():
			var projectile: Node3D = spawned[0]
			_check(absf(float(projectile.get("dmg")) - float(game.wstat(id).dmg) * Progress.bonus().dmg) < 0.01, "%s projectielschade is veranderd" % id)
			_check(projectile.get("mesh") != null or projectile.has_node("RocketVisual"), "%s heeft geen zichtbare projectielmesh" % id)
			if id == "bazooka":
				_check(projectile.has_node("RocketVisual"), "bazooka gebruikt geen raketprojectiel")
				_check(is_equal_approx(float(projectile.get("explosive")), float(Data.WEAPONS.bazooka.explosive)), "bazooka-explosiestraal veranderde")
			elif int(Data.WEAPON_VISUALS[id].trail_every) == 0:
				_check(projectile.scale.x < 1.0, "%s zonder tracer gebruikt nog een groot lichtspoor" % id)
			else:
				_check(projectile.get("mesh") is ArrayMesh, "%s tracer ontbreekt" % id)
		if id == "trench":
			var pumps: Array = player.get("model").get("_pump_parts")
			_check(not pumps.is_empty(), "Winchester-model heeft geen afzonderlijk pompdeel")
			if not pumps.is_empty():
				var pump: Node3D = pumps[0]
				var initial := pump.position
				await _frames(2)
				_check(pump.position.distance_to(initial) > 0.001, "Winchester-pomp beweegt niet na schot")

	# De bovenlichaamclip mag de loopanimatie van het skelet niet vervangen.
	var model: Node = player.get("model")
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var spine_bone: int = skeleton.find_bone("DEF-spine003")
	var arm_bone: int = skeleton.find_bone("DEF-upper_armR")
	var spine_before: Quaternion = skeleton.get_bone_pose_rotation(spine_bone)
	var arm_before: Quaternion = skeleton.get_bone_pose_rotation(arm_bone)
	game.set("move", Vector2(1.0, 0.0))
	game.set("fire", true)
	player.set("fire_t", 0.0)
	player.set("reload_t", 0.0)
	player.set("ammo", 5)
	await _frames(15)
	var overlay: AnimationPlayer = model.get("_fire_anim")
	_check(str(model.get("current")) in ["lopen", "rennen"], "schieten onderbreekt de basis-loopanimatie")
	_check(overlay.current_animation == "fire", "schietpose op armen/romp speelt niet")
	_check(overlay.get_animation("fire").get_track_count() <= 12, "schiet-overlay bevat onnodige beenanimatietracks")
	var upper_body_motion := maxf(spine_before.angle_to(skeleton.get_bone_pose_rotation(spine_bone)), arm_before.angle_to(skeleton.get_bone_pose_rotation(arm_bone)))
	_check(upper_body_motion > 0.02, "bovenlichaam-schietanimatie verandert de botpose niet")
	model.call("hit_reaction", Vector3.RIGHT, 1.0)
	await _frames(3)
	_check(overlay.current_animation == "hit", "vijandelijke hitpose start niet")
	_check(str(model.get("current")) in ["lopen", "rennen"], "hitpose stopt de bestaande basisanimatie")
	game.set("fire", false)
	game.set("move", Vector2.ZERO)

	# Herhaalde effecten blijven binnen de mobiele limieten en hulzen worden hergebruikt.
	var fx: Script = load("res://scripts/fx.gd")
	for i in 20:
		fx.muzzle(main, player.global_position + Vector3.UP, "mg42", PI)
	var fx_counts: Dictionary = fx.combat_counts()
	_check(int(fx_counts.flash_lights) <= 2, "mondingsvuur maakt te veel dynamische lichten")
	_check(int(fx_counts.muzzle_smoke) <= 12, "mondingsrook overschrijdt de limiet")
	_check(int(fx_counts.casings) <= 36, "hulsmaximum wordt overschreden")

	main.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("COMBAT VISUALS TEST PASS: 6 wapens, bestaande schade/munitie, loopblend, hitreactie, shotgunpomp en FX-limieten")
		quit(0)
	else:
		quit(1)
