extends Node
## Controleert het geïsoleerde M1911-lab zonder een golf te starten.
## Draaien: godot4 --headless --path . scenes/tests/arcade_vfx_lab_test_runner.tscn

const LAB_SCENE := preload("res://scenes/tests/arcade_vfx_lab.tscn")
const PROFILE: ArcadeVfxProfile = preload("res://resources/arcade_vfx_profile.tres")

var failures: Array[String] = []
var lab: Node3D


func _ready() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("ARCADE VFX LAB TEST: " + message)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _bullets(parent: Node) -> Array[Bullet]:
	var found: Array[Bullet] = []
	for child in parent.get_children():
		if child is Bullet:
			found.append(child as Bullet)
	return found


func _aim(target_id: String) -> void:
	var sticks: Control = lab.get("_sticks") as Control
	sticks.set_process(false)
	lab.call("_set_aim", target_id)
	await _frames(15)
	var aimed_player: CharacterBody3D = lab.get("player") as CharacterBody3D
	sticks.set_process(false)
	aimed_player.face = Game.aim
	aimed_player.rotation.y = Game.aim


func _run() -> void:
	lab = LAB_SCENE.instantiate()
	get_tree().root.add_child(lab)
	for _i in 600:
		if lab.get("is_lab_ready"):
			break
		await get_tree().process_frame
	_check(bool(lab.get("is_lab_ready")), "testscène heeft de echte speelwereld niet opgebouwd")
	if not bool(lab.get("is_lab_ready")):
		get_tree().quit(1)
		return
	await _frames(15)  # wacht de initiële doelselectie af; daarna blijft de joystick weer actief.

	var main: Node = lab.get("game_scene")
	var player: CharacterBody3D = lab.get("player")
	var enemy: CharacterBody3D = lab.get("test_enemy")
	_check(not main.is_processing(), "golfspawner draait nog in het lab")
	_check(Game.state == "play", "lab heeft de speelklaarstatus niet gezet")
	_check((main.get("queue") as Array).is_empty(), "lab heeft een golfwachtrij gestart")
	_check(str(player.get("weapon")) == "m1911", "lab gebruikt niet het M1911-pistool")
	_check(player.get("arcade_vfx_profile") == PROFILE, "M1911-profiel ontbreekt op de echte speler")
	_check(enemy != null and is_instance_valid(enemy), "vijandelijke testdummy ontbreekt")
	_check(lab.get("targets").size() == 4, "niet alle vier de testdoelen bestaan")
	var hud: CanvasLayer = main.get_node("Hud") as CanvasLayer
	var sticks: Control = hud.get_node("Sticks") as Control
	_check(sticks.is_visible_in_tree() and sticks.is_processing(), "bestaande touchjoystick is niet actief in de labscène")
	for child in hud.get_children():
		if child != sticks:
			_check(not child.is_visible_in_tree(), "bestaand HUD-element %s blijft zichtbaar in het geïsoleerde lab" % child.name)

	# De zichtbare spelerroute moet dezelfde snelheid, schade en levensduur gebruiken als de game.
	var game := get_tree().root.get_node("Game")
	var deterministic_stats: Dictionary = game.wstat("m1911")
	deterministic_stats.spread = 0.0  # herhaalbare treffers via dezelfde speler- en Bullet-code.
	var ammo_before: int = int(player.get("ammo"))
	var hp_before: float = float(enemy.get("hp"))
	var bullets_before := _bullets(main).size()
	await _aim("enemy")
	player.set("face", Game.aim)
	player.rotation.y = Game.aim
	var muzzle_pos: Vector3 = player.get("model").call("muzzle_position")
	var enemy_face: float = float(player.get("face"))
	var enemy_dir := Vector3(sin(enemy_face), 0.0, cos(enemy_face))
	var debug_query := PhysicsRayQueryParameters3D.create(muzzle_pos, muzzle_pos + enemy_dir * 8.0, Bullet.MASK_ENEMY | Bullet.MASK_BUNKER | Bullet.MASK_WALL)
	_check(main.get_world_3d().direct_space_state.intersect_ray(debug_query).get("collider") == enemy, "testdummy staat niet in het bestaande kogelpad")
	player.set("fire_t", 0.0)
	player.set("reload_t", 0.0)
	player.set("idle_t", 0.0)
	player.call("_shoot", deterministic_stats, PROFILE)
	var spawned := _bullets(main).slice(bullets_before)
	_check(spawned.size() == 1, "één M1911-trekkeroverhaal maakte niet één projectiel")
	_check(int(player.get("ammo")) == ammo_before - 1, "M1911-munitie is veranderd")
	if not spawned.is_empty():
		var bullet: Bullet = spawned[0] as Bullet
		_check(bullet.get("arcade_vfx_profile") == PROFILE, "projectiel gebruikt het gedeelde arcadeprofiel niet")
		_check(bullet.get("mesh") is ArrayMesh, "projectiel heeft geen arcade-tracermesh")
		_check(is_equal_approx(float(bullet.get("dmg")), float(game.wstat("m1911").dmg) * Progress.bonus().dmg), "M1911-schade is aangepast")
		var projectile_speed: float = float(bullet.get("speed"))
		_check(projectile_speed >= Data.WEAPONS.m1911.speed * 0.92 and projectile_speed <= Data.WEAPONS.m1911.speed * 1.05, "M1911-projectielsnelheid is aangepast")
	_check(float(player.get("model").get("_recoil")) > 0.0, "M1911-terugslag is niet gestart")
	_check(int(Fx.combat_counts().muzzle_flashes) > 0, "M1911-mondingsvuur is niet gestart")
	await _frames(12)
	_check(float(enemy.get("hp")) < hp_before, "M1911-projectiel raakt de testdummy niet")

	# Doelmetadata en daadwerkelijke botsingen volgen het bestaande Bullet-impactpad.
	var targets: Dictionary = lab.get("targets")
	for target_id in ["earth", "concrete", "metal"]:
		lab.call("reset_lab")
		await _frames(2)
		var target: Node3D = targets[target_id]
		var impact_probe := Bullet.new()
		_check(impact_probe._impact_material(target) == ("dirt" if target_id == "earth" else target_id), "%s gebruikt de verkeerde impactsoort" % target_id)
		impact_probe.free()
		await _aim(target_id)
		player.set("face", Game.aim)
		player.rotation.y = Game.aim
		var surface_muzzle: Vector3 = player.get("model").call("muzzle_position")
		var surface_face: float = float(player.get("face"))
		var surface_dir := Vector3(sin(surface_face), 0.0, cos(surface_face))
		var surface_ray := PhysicsRayQueryParameters3D.create(surface_muzzle, surface_muzzle + surface_dir * 20.0, Bullet.MASK_ENEMY | Bullet.MASK_BUNKER | Bullet.MASK_WALL)
		_check(main.get_world_3d().direct_space_state.intersect_ray(surface_ray).get("collider") == target, "%s is geblokkeerd in het bestaande kogelpad" % target_id)
		var target_hits_before: int = int(target.get("impact_count"))
		player.set("fire_t", 0.0)
		player.set("reload_t", 0.0)
		player.set("idle_t", 0.0)
		player.call("_shoot", deterministic_stats, PROFILE)
		await _frames(24)  # het metalen fixture staat verder weg dan de aarde- en betontargets.
		_check(int(target.get("impact_count")) > target_hits_before, "%s wordt niet geraakt via het bestaande projectielpad" % target_id)
		var impact_before: int = int(Fx.combat_counts().burst_live)
		Fx.impact(main, target.global_position + Vector3.UP, Vector3.BACK, "dirt" if target_id == "earth" else target_id, PROFILE)
		_check(int(Fx.combat_counts().burst_live) > impact_before, "%s heeft geen impacteffect gestart" % target_id)

	# Een normaal schot buiten het lab blijft de bestaande gedeelde wapenvisuals gebruiken.
	var default_projectile_parent := Node3D.new()
	main.add_child(default_projectile_parent)
	Bullet.fire(default_projectile_parent, Vector3(0, 1, 40), 0.0, Data.WEAPONS.m1911.speed, Data.WEAPONS.m1911.dmg, 0.2, true, false, 0, 0.0, 0.0, 0.0, "m1911")
	var default_bullets := _bullets(default_projectile_parent)
	_check(default_bullets.size() == 1 and default_bullets[0].get("arcade_vfx_profile") == null, "arcadeprofiel lekt naar een standaardprojectiel")
	_check(Data.WEAPONS.m1911.dmg == 26.0 and is_equal_approx(Data.WEAPONS.m1911.rate, 0.19) and is_equal_approx(Data.WEAPONS.m1911.spread, 0.035), "basiswapenwaarden zijn veranderd")

	lab.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("ARCADE VFX LAB TEST PASS: testscène, M1911-projectiel/terugslag, vijand-hit, materiaalinslagen, profielisolatie en basiswapenwaarden")
		get_tree().quit(0)
	else:
		get_tree().quit(1)
