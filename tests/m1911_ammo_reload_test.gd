extends SceneTree
## M1911 chamber/magazine + interrupted reload state matrix.
## Run: godot --headless --path . -s tests/m1911_ammo_reload_test.gd

var failures := 0
var game: Variant


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("M1911 AMMO TEST: " + message)


func _set_loaded(p: Variant, mag: int, chamber: bool) -> void:
	p.m1911_mag_rounds = mag
	p.m1911_chambered = chamber
	p._sync_m1911_ammo()


func _check_loaded(p: Variant, mag: int, chamber: bool, tag: String) -> void:
	var total := mag + int(chamber)
	_check(p.m1911_mag_rounds == mag, tag + ": magazine count")
	_check(p.m1911_chambered == chamber, tag + ": chamber")
	_check(p.ammo == total, tag + ": legacy player ammo")
	_check(int(game.owned.m1911.ammo) == total, tag + ": owned ammo mirror")
	_check(int(game.owned.m1911.mag_rounds) == mag, tag + ": owned magazine")
	_check(bool(game.owned.m1911.chambered) == chamber, tag + ": owned chamber")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = root.get_node("Game")
	game.reset()
	game.state = "menu"  # Prevent physics/auto-reload racing this deterministic test.
	var world := Node3D.new()
	root.add_child(world)
	var p: Variant = load("res://scenes/player.tscn").instantiate()
	world.add_child(p)
	await process_frame

	# A legacy save with seven loaded rounds maps to one chambered and six in mag.
	_check_loaded(p, 6, true, "legacy 7-round initialization")

	# Every shot must write back the physical and legacy state immediately.
	_set_loaded(p, 7, true)
	_check(p._m1911_fire_chambered_round(), "8th loaded round can fire")
	_check_loaded(p, 6, true, "7+1 -> 6+1")
	for _i in 6:
		_check(p._m1911_fire_chambered_round(), "feeding next chambered round")
	_check_loaded(p, 0, true, "last cartridge still chambered")
	_check(p._m1911_fire_chambered_round(), "last cartridge can fire")
	_check_loaded(p, 0, false, "slide lock after last shot")
	_check(not p._m1911_fire_chambered_round(), "empty pistol cannot fire")
	_check_loaded(p, 0, false, "empty trigger changes nothing")

	# Trigger never racks a slide: magazine present with an empty chamber is not fire-ready.
	_set_loaded(p, 4, false)
	_check(not p._m1911_fire_chambered_round(), "trigger does not auto-chamber")
	_check_loaded(p, 4, false, "magazine-only state")

	# Interrupted before insertion: reload creates no rounds.
	_set_loaded(p, 1, true)
	p._reload(game.wstat("m1911"))
	_check(p.reload_t > 0.0, "reload starts on partial magazine")
	p._reload_elapsed = p._reload_dur * 0.40
	p._update_m1911_reload_events()
	_check(p._reload_phase == 1, "magazine-out event fired")
	_check_loaded(p, 1, true, "before mag-in rounds unchanged")
	game.owned["thompson"] = {"up": {"dmg": 0, "rate": 0, "mag": 0, "rel": 0}, "ammo": 6}
	game.loadout.append("thompson")
	p.equip("thompson")
	_check(p.reload_t <= 0.0 and p._reload_phase == 0, "weapon switch interrupts reload")
	p.equip("m1911")
	_check_loaded(p, 1, true, "interrupt saved on weapon switch")

	# Tactical reload retains chambered cartridge and inserts a seven-round magazine.
	p._reload(game.wstat("m1911"))
	p._reload_elapsed = p._reload_dur * 0.69
	p._update_m1911_reload_events()
	_check_loaded(p, 7, true, "tactical mag-in 7+1")
	p._finish_m1911_reload()
	_check_loaded(p, 7, true, "tactical finish 7+1")
	_check(not p.can_reload(), "cannot reload a full seven-round magazine")

	# Empty reload: insertion gives seven in mag, slide release feeds one (6+1).
	_set_loaded(p, 0, false)
	p.reload_t = 0.0
	p._reload(game.wstat("m1911"))
	p._reload_elapsed = p._reload_dur * 0.70
	p._update_m1911_reload_events()
	_check_loaded(p, 7, false, "empty mag-in leaves chamber empty")
	p._finish_m1911_reload()
	_check_loaded(p, 6, true, "empty slide release yields 6+1")
	_check(p._reload_phase == 0, "reload state cleared")

	# Previously migrated physical state survives a new Player instance in this run.
	_set_loaded(p, 2, false)
	p.queue_free()
	await process_frame
	var restored: Variant = load("res://scenes/player.tscn").instantiate()
	world.add_child(restored)
	await process_frame
	_check_loaded(restored, 2, false, "stored owned state on player re-creation")
	_check(not restored._m1911_fire_chambered_round(), "restored empty chamber remains empty")

	# Legacy integer-only records are still safely migrated.
	restored.queue_free()
	await process_frame
	game.owned["m1911"] = {"up": {"dmg": 0, "rate": 0, "mag": 0, "rel": 0}, "ammo": 3}
	var migrated: Variant = load("res://scenes/player.tscn").instantiate()
	world.add_child(migrated)
	await process_frame
	_check_loaded(migrated, 2, true, "legacy ammo=3 migrated to chamber+mag")
	world.queue_free()
	print("M1911 AMMO/RELOAD TEST " + ("PASS" if failures == 0 else "FAIL: %d" % failures))
	quit(1 if failures > 0 else 0)
