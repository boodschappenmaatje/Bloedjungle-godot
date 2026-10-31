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

	# Right stick: aim-only center, hysteresis on the fire ring, and one
	# separate shot every 0.5 s while the assisted fire zone remains held.
	_check(GameSettings.get_value("m1911_fire_mode") == "assist", "assist is the default mode")
	_check(game.wstat("m1911").rate >= 0.5, "Colt fire cadence must be at least 0.5 s")
	_check(not TouchSticks.m1911_zone_active(0.80, false), "80% stick must remain aim-only")
	_check(TouchSticks.m1911_zone_active(0.84, false), "84% stick enters fire zone")
	_check(TouchSticks.m1911_zone_active(0.75, true), "75% held fire stays latched")
	_check(not TouchSticks.m1911_zone_active(0.70, true), "70% leaves fire zone")
	_check(p.m1911_trigger_request(true, false, true, false), "first outer-ring entry fires immediately")
	_check(not p.m1911_trigger_request(true, true, true, false), "holding within cooldown must not fire")
	_check(p.m1911_trigger_request(true, true, true, true), "held outer ring fires next separate shot when ready")
	_check(not p.m1911_trigger_request(false, true, true, true), "releasing stick stops firing")
	_check(p.m1911_trigger_request(true, false, false, true), "manual mode first trigger-edge shoots")
	_check(not p.m1911_trigger_request(true, true, false, true), "manual mode holding never repeats")
	_check(p.m1911_trigger_request(true, false, false, true), "manual mode release and press shoots again")
	_check(not p.m1911_trigger_request(true, true, false, true), "mouse/keyboard hold remains single-shot")

	# New game starts with a fully prepared 7+1, not a partially filled magazine.
	_check_loaded(p, 7, true, "new-game 7+1 initialization")
	_check(not p.can_reload(), "full magazine has no manual reload")
	_check(not p._should_auto_reload(), "full magazine must not auto-reload")
	# An idle period after a fired shot never starts an M1911 tactical reload.
	_check(p._m1911_fire_chambered_round(), "first shot from 7+1")
	_check_loaded(p, 6, true, "first shot leaves 6+1")
	_check(p.can_reload(), "partial magazine still allows manual tactical reload")
	_check(not p._should_auto_reload(), "partial magazine does not idle-auto-reload")
	p._reload(game.wstat("m1911"))
	_check(is_equal_approx(p.reload_t, game.wstat("m1911").reload * Progress.bonus().reload), "tactical reload duration")
	p.reload_t = 0.0
	p._reload_phase = 0
	p._reload_elapsed = 0.0
	p._reload_was_empty = false
	_set_loaded(p, 0, true)
	_check(not p._should_auto_reload(), "last chambered round must remain fire-ready")
	_set_loaded(p, 0, false)
	_check(p._should_auto_reload(), "fully empty pistol may auto-reload")
	p._reload(game.wstat("m1911"))
	_check(is_equal_approx(p.reload_t, game.wstat("m1911").reload * Progress.bonus().reload * 1.2), "empty-slide reload includes extra slide time")
	p.reload_t = 0.0
	p._reload_phase = 0
	p._reload_elapsed = 0.0
	p._reload_was_empty = false

	# Every shot must write back the physical and legacy state immediately.
	_set_loaded(p, 7, true)
	_check(p._m1911_fire_chambered_round(), "8th loaded round can fire")
	_check_loaded(p, 6, true, "7+1 -> 6+1")
	_check(not p._should_auto_reload(), "shot with seven rounds remaining cannot auto-reload")
	for _i in 6:
		_check(p._m1911_fire_chambered_round(), "feeding next chambered round")
	_check_loaded(p, 0, true, "last cartridge still chambered")
	_check(p._m1911_fire_chambered_round(), "last cartridge can fire")
	_check_loaded(p, 0, false, "slide lock after last shot")
	_check(p._should_auto_reload(), "only after final shot can idle auto-reload")
	_check(not p._m1911_fire_chambered_round(), "empty pistol cannot fire")
	_check_loaded(p, 0, false, "empty trigger changes nothing")

	# Regression: held assisted right-stick at zero must NOT repeat the dry-click
	# every 0.5 s or keep resetting idle (observed in 31 Oct iPhone recording).
	_set_loaded(p, 0, false)
	_check(p.m1911_is_empty(p.m1911_chambered, p.m1911_mag_rounds), "fully empty chamber+mag detected")
	_check(p.m1911_should_advance_idle(true, false, 0), "held trigger + empty gun continues counting toward auto reload")
	_check(p.m1911_should_advance_idle(false, false, 0), "released trigger + empty gun continues counting toward reload")
	_check(not p.m1911_should_advance_idle(true, true, 0), "last chambered shot still respects fire cadence")
	_check(not p.m1911_should_advance_idle(true, true, 6), "loaded assisted trigger resets idle as usual")
	_check(not p.m1911_is_empty(true, 0), "last chambered round is not empty")
	_check(not p.m1911_is_empty(false, 4), "magazine-only state is not fully empty")
	_check(p.M1911_EMPTY_RELOAD_IDLE < 1.4, "empty Colt reload no longer waits full 1.4 seconds")
	p._m1911_empty_click_latched = true  # established by the final successful shot in the held trigger
	_check(not p._m1911_empty_trigger_feedback(), "holding after final round must make no repeated click")
	p._m1911_empty_click_latched = false  # release, then a new deliberate pull
	_check(p._m1911_empty_trigger_feedback(), "new distinct empty trigger press may click once")
	_check(not p._m1911_empty_trigger_feedback(), "continuously held empty trigger never repeats click")
	p._m1911_empty_click_latched = false
	_check(p._should_auto_reload(), "fully empty gun is eligible for idle auto-reload despite held trigger")

	# Trigger never racks a slide: magazine present with an empty chamber is not fire-ready.
	_set_loaded(p, 4, false)
	_check(not p._m1911_fire_chambered_round(), "trigger does not auto-chamber")
	_check_loaded(p, 4, false, "magazine-only state")
	_check(not p._should_auto_reload(), "empty chamber + loaded mag requires manual racking, not auto-refill")

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
