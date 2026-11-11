extends SceneTree
## Test: de KRACHTEN-knop (ster) werkt op aanraking zoals de UITRUSTING/GRANAAT-knop:
##   tik opent het wiel -> een kracht kiezen sluit het wiel zonder iets af te vuren en zet de rechterstick klaar ->
##   een NIEUWE aanraking op de rechterstick richt (artillerie en napalm tonen hun richthulp) -> loslaten vuurt exact eenmaal af ->
##   terug naar het midden of tikken zonder slepen annuleert -> daarna schiet de rechterstick weer gewoon.
## Draaien: godot --headless --path . --script tests/kracht_stick_test.gd --fixed-fps 60

var failures := 0
var game
var main: Node
var cb
var btn: Control
var sticks


func _initialize() -> void:
	OS.set_environment("BJ_TOUCH", "1")
	root.size = Vector2i(932, 430)
	call_deferred("_run")


func _check(ok: bool, msg: String) -> void:
	print(("OK    " if ok else "FOUT  ") + msg)
	if not ok:
		failures += 1


func _frames(n: int) -> void:
	for _i in n:
		await physics_frame


func _touch_pointer(pointer: int, pressed: bool, at: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = pointer
	e.position = root.get_final_transform() * at   # schermpunt: de HUD is geschaald (content_scale_factor)
	e.pressed = pressed
	root.push_input(e)


func _drag_pointer(pointer: int, at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = pointer
	e.position = root.get_final_transform() * at
	root.push_input(e)


func _tap(at: Vector2) -> void:
	_touch_pointer(0, true, at)
	await _frames(1)
	_touch_pointer(0, false, at)
	await _frames(2)


func _stick_center() -> Vector2:
	return main.get_node("Hud/Sticks")._anchor(true)


func _wheel_value(key: String) -> float:
	var script: Script = load("res://scripts/wheel_art.gd")
	return float(script.get_script_constant_map().get(key))


func _stick_r() -> float:
	var script: Script = main.get_node("Hud/Sticks").get_script()
	return float(script.get_script_constant_map().get("STICK_R"))


## Tik op de knop, daarna op een kant van het wiel: 0 = boven (artillerie), 1 = rechts (napalm), 2 = onder (satelliet), 3 = links (reparatie).
func _kies(sector: int) -> void:
	await _tap(btn.get_global_rect().get_center())
	var mid := (_wheel_value("INNER") + _wheel_value("OUTER")) * 0.5
	var dirs := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	await _tap(cb._wheel_center() + dirs[sector] * mid)


## Rechterstick: nieuwe aanraking, naar `offset` slepen (in stickpixels), nog niet loslaten.
func _stick_naar(offset: Vector2, steps := 4) -> void:
	var c: Vector2 = _stick_center()
	_touch_pointer(0, true, c)
	await _frames(1)
	for i in steps:
		_drag_pointer(0, c + offset * float(i + 1) / steps)
		await _frames(1)


func _stick_los(offset: Vector2) -> void:
	_touch_pointer(0, false, _stick_center() + offset)
	await _frames(2)


func _gebruikt(id: String) -> int:
	return int(game.krachten_gebruikt.get(id, 0))


func _run() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	game = root.get_node("Game")
	await _frames(3)
	await main.call("begin")
	for m in get_nodes_in_group("menus"):
		m._show("")
	game.prep_t = 9999.0
	await _frames(3)
	game.state = "play"
	game.player.driving = false   # het spel begint in de bouwwagen; Dennis speelt te voet
	for n in get_nodes_in_group("hud_button"):
		if n.get_script() != null and n.get_script().resource_path == "res://scripts/action_btn.gd" and n.get("kind") == "krachten":
			btn = n
	cb = btn.get_parent()
	sticks = main.get_node("Hud/Sticks")
	var p = game.player
	game.krachten = {"artillerie": 1, "napalm": 1, "satelliet": 1, "reparatie": 1}
	game.kracht_sel = "artillerie"
	game.kracht_cd.clear()
	game.krachten_gebruikt = {}
	game.satelliet_t = 0.0
	game.changed.emit()
	await _frames(3)
	var rim := Vector2(_stick_r() * 0.7, 0.0)

	# 1. een tik op de knop opent het wiel en vuurt niets af
	_check(btn.visible and btn.get_global_rect().size.x > 0.0, "KRACHTEN-knop staat er")
	await _tap(btn.get_global_rect().get_center())
	_check(cb.wheel_is_open() and cb._wheel_kind == "support" and cb._wheel_sticky, "een tik op de krachtenknop opent het wiel")
	_check(not cb.kracht_stick_armed and game.kracht_cd.is_empty(), "het wiel openen vuurt niets af")

	# 2. NAPALM kiezen: wiel dicht, geen strook, rechterstick klaar, nog niets gebruikt
	var mid := (_wheel_value("INNER") + _wheel_value("OUTER")) * 0.5
	await _tap(cb._wheel_center() + Vector2(mid, 0))
	_check(not cb.wheel_is_open() and game.kracht_sel == "napalm", "NAPALM kiezen sluit het wiel")
	_check(cb.kracht_stick_armed and not cb.grenade_stick_armed, "kiezen zet de rechterstick klaar")
	_check(game.kracht_cd.is_empty() and _gebruikt("napalm") == 0 and cb._place == null, "kiezen vuurt niets af en zet geen strook neer")
	_check(stick_label_ok("NAPALM"), "de stick toont de naam van de kracht")
	var a_max: Dictionary = cb.air_aim(Vector2(cb.AIM_FULL, 0.0), true)
	var a_min: Dictionary = cb.air_aim(Vector2(cb.AIM_DEAD + 0.5, 0.0), true)
	var d_max := Vector2(a_max.target.x - p.global_position.x, a_max.target.z - p.global_position.z).length()
	var d_min := Vector2(a_min.target.x - p.global_position.x, a_min.target.z - p.global_position.z).length()
	_check(absf(d_max - 20.0) < 0.1 and absf(d_min - 6.0) < 0.2, "napalm met de stick: 6 tot 20 m (%.1f - %.1f)" % [d_min, d_max])

	# 3. een NIEUWE aanraking richt: de richthulp verschijnt, de stick schiet geen kogels
	await _stick_naar(rim)
	_check(cb._air_vis != null and cb._air_vis.visible, "rechterstick toont de napalmstrook")
	_check(not game.fire, "rechterstick in krachtstand schiet geen kogels")
	_check(cb.kstick_finger == 0 and cb.kstick_drag.length() > cb.AIM_DEAD, "de stickvinger richt (%.0f px)" % cb.kstick_drag.length())
	# 4. loslaten vuurt exact eenmaal af en geeft de schietbesturing terug
	await _stick_los(rim)
	_check(_gebruikt("napalm") == 1 and game.kracht_cd.has("napalm"), "loslaten vuurt NAPALM af: afkoeling loopt")
	_check(not cb.kracht_stick_armed and cb._air_vis == null, "na het vuren is de krachtstand weg en de richthulp opgeruimd")

	# 5. ARTILLERIE: richthulp (doelcirkel), loslaten vuurt
	game.kracht_cd.clear()
	await _kies(0)
	_check(cb.kracht_stick_armed and game.kracht_sel == "artillerie", "ARTILLERIE kiezen zet de rechterstick klaar")
	var ar_max: Vector3 = cb.arty_target(Vector2(0, cb.AIM_FULL), true)
	var ar_min: Vector3 = cb.arty_target(Vector2(0, cb.AIM_DEAD + 0.5), true)
	var ad_max := Vector2(ar_max.x - p.global_position.x, ar_max.z - p.global_position.z).length()
	var ad_min := Vector2(ar_min.x - p.global_position.x, ar_min.z - p.global_position.z).length()
	_check(absf(ad_max - 26.0) < 0.1 and absf(ad_min - 14.0) < 0.3, "artillerie met de stick: 14 tot 26 m, dus nog in beeld (%.1f - %.1f)" % [ad_min, ad_max])
	await _stick_naar(Vector2(0, _stick_r() * 0.8))
	_check(cb._arty_vis != null and cb._arty_vis.visible, "rechterstick toont de doelcirkel van de artillerie")
	await _stick_los(Vector2(0, _stick_r() * 0.8))
	_check(_gebruikt("artillerie") == 1 and game.kracht_cd.has("artillerie"), "loslaten vuurt ARTILLERIE af")
	_check(cb._arty_vis == null, "de doelcirkel is weer weg")

	# 6. terug naar het midden en loslaten annuleert zonder iets te gebruiken
	game.kracht_cd.clear()
	await _kies(2)   # satelliet
	_check(cb.kracht_stick_armed and game.kracht_sel == "satelliet", "SATELLIET kiezen zet de rechterstick klaar")
	await _stick_naar(rim)
	_check(not game.fire, "ook bij satelliet schiet de rechterstick geen kogels")
	_drag_pointer(0, _stick_center() + Vector2(3, 2))
	await _frames(1)
	await _stick_los(Vector2(3, 2))
	_check(_gebruikt("satelliet") == 0 and game.satelliet_t <= 0.0 and not game.kracht_cd.has("satelliet"), "terug naar het midden annuleert zonder gebruik")
	_check(not cb.kracht_stick_armed, "annuleren herstelt de normale besturing")

	# 7. een tik op de stick zonder richting vuurt ook niets af
	await _kies(2)
	await _stick_naar(Vector2.ZERO, 0)
	await _stick_los(Vector2.ZERO)
	_check(_gebruikt("satelliet") == 0 and not cb.kracht_stick_armed, "tikken zonder te slepen vuurt niets af")

	# 8. SATELLIET en REPARATIE vuren bij slepen en loslaten (geen richthulp)
	await _kies(2)
	await _stick_naar(rim)
	await _stick_los(rim)
	_check(_gebruikt("satelliet") == 1 and game.satelliet_t > 0.0, "slepen en loslaten gebruikt de SATELLIET")
	await _kies(3)
	_check(cb.kracht_stick_armed and game.kracht_sel == "reparatie", "REPARATIE kiezen zet de rechterstick klaar")
	await _stick_naar(rim)
	await _stick_los(rim)
	_check(_gebruikt("reparatie") == 1 and game.kracht_cd.has("reparatie"), "slepen en loslaten gebruikt de REPARATIE")

	# 9. een kracht in afkoeling: kiezen mag, maar de stick blijft gewoon schieten
	game.kracht_cd["napalm"] = 50.0
	await _kies(1)
	_check(game.kracht_sel == "napalm" and not cb.kracht_stick_armed, "tijdens de afkoeling kiezen zonder krachtstand")
	await _stick_naar(Vector2(_stick_r(), 0.0))
	await _frames(2)
	_check(game.fire, "tijdens de afkoeling schiet de rechterstick gewoon")
	await _stick_los(Vector2(_stick_r(), 0.0))
	game.kracht_cd.erase("napalm")

	# 10. een andere vinger kan de klaarstaande kracht niet vrijgeven of overnemen
	game.kracht_cd.clear()
	var before_ar := _gebruikt("artillerie")
	await _kies(0)
	await _stick_naar(rim)
	var wrong := InputEventScreenTouch.new()
	wrong.index = 3
	wrong.position = root.get_final_transform() * (sticks._anchor(false))
	wrong.pressed = false
	root.push_input(wrong)
	await _frames(1)
	_check(cb.kracht_stick_armed and _gebruikt("artillerie") == before_ar, "loslaten van een andere vinger vuurt niets af")
	var second := _stick_center() + Vector2(-8, 8)
	_touch_pointer(2, true, second)
	await _frames(1)
	_check(sticks.owns_touch(0) and not sticks.owns_touch(2) and cb.kstick_finger == 0, "een tweede rechtervinger verdringt de eerste niet")
	_touch_pointer(2, false, second)
	await _frames(1)
	_check(cb.kracht_stick_armed and _gebruikt("artillerie") == before_ar, "de tweede vinger kan niets vrijgeven")
	await _stick_los(rim)
	_check(_gebruikt("artillerie") == before_ar + 1 and not cb.kracht_stick_armed, "de juiste vinger vuurt exact eenmaal")

	# 11. het wiel opnieuw openen breekt een klaarstaande kracht af; granaat en kracht sluiten elkaar uit
	game.kracht_cd.clear()
	await _kies(3)
	_check(cb.kracht_stick_armed, "kracht klaar")
	await _tap(btn.get_global_rect().get_center())
	_check(cb.wheel_is_open() and not cb.kracht_stick_armed, "het wiel opnieuw openen breekt de klaarstaande kracht af")
	cb._close_wheel()
	game.grenades = 5
	game.equipment_sel = "grenade"
	cb.arm_grenade_stick()
	_check(cb.grenade_stick_armed and not cb.kracht_stick_armed, "granaat klaarzetten")
	cb._select_wheel("support", 0)
	_check(cb.kracht_stick_armed and not cb.grenade_stick_armed, "een kracht kiezen haalt de granaatstand weg")
	cb.cancel_stick()
	_check(not cb.kracht_stick_armed and not cb.grenade_stick_armed, "cancel_stick haalt beide standen weg")

	# 12. uit het vastgehouden wiel naar buiten slepen kiest ook, maar het richten vraagt een NIEUWE rechteraanraking
	game.kracht_cd.clear()
	cb._wheel_kind = "support"
	cb._wheel_sticky = false
	cb._held_pointer = 0
	cb._held_action = "support"
	cb._hold_origin = Vector2(700, 300)
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = Vector2(700, 300) + Vector2(80, 0)
	cb._input(e)
	_check(cb._wheel_kind == "support" and cb._wheel_sector == 1, "binnen het wiel: sector napalm")
	e = InputEventScreenDrag.new()
	e.index = 0
	e.position = Vector2(700, 300) + Vector2(180, 0)
	cb._input(e)
	_check(cb._wheel_kind == "" and game.kracht_sel == "napalm" and cb.kracht_stick_armed, "ver buiten het wiel slepen kiest en zet de rechterstick klaar")
	_check(cb.air_finger == -2 and cb.kstick_finger == -2, "dezelfde vinger richt niet, er is een nieuwe aanraking nodig")
	cb.cancel_stick()

	# 13. de normale rechterstick schiet weer
	await _stick_naar(Vector2(_stick_r(), 0.0))
	await _frames(2)
	_check(game.fire, "zonder krachtstand schiet de rechterstick weer gewoon")
	await _stick_los(Vector2(_stick_r(), 0.0))

	print("KRACHT_STICK_TEST fouten=", failures)
	print("TEST OK" if failures == 0 else "TEST MISLUKT")
	quit(1 if failures > 0 else 0)


func stick_label_ok(expected: String) -> bool:
	return String(cb.stick_label()) == expected
