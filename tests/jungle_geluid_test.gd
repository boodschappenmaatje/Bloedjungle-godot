extends SceneTree
## Test: jungle-geluiden laden (lussen en roepen), mix volgt het tijdstip, schoten maken de jungle stil en daarna komt ze terug.
## Draaien: godot --headless --path . -s tests/jungle_geluid_test.gd --fixed-fps 60

var main: Node
var jg: Node
var JG: GDScript   # niet via class_name: dit testscript wordt gecompileerd voordat de autoloads er zijn
var game: Node
var sfx: Node
var frames := 0
var fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		push_error("JUNGLEGELUID TEST FAIL: " + msg)


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	JG = load("res://scripts/jungle_geluid.gd")
	game = root.get_node("Game")
	sfx = root.get_node("Sfx")


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		main.begin()
	if frames == 100:
		for n in ["dag", "nacht", "water"]:
			_check(JG._loops.has(n), "lus " + n + " ontbreekt")
			var st: AudioStream = JG._loops.get(n)
			if st is AudioStreamWAV:
				_check(st.loop_mode == AudioStreamWAV.LOOP_FORWARD and st.loop_end > 20000, "lus " + n + " loopt niet")
		for k in ["fluit", "triller", "krijs", "koer", "brulaap", "uil", "nachtzwaluw"]:
			_check(JG._calls.has(k) and JG._calls[k].size() >= 3, "roepen " + k + " (minstens 3 varianten)")
		for kinds in JG.CALLS.values():
			for k in kinds:
				_check(JG._calls.has(k), "tijdstip verwijst naar roep zonder bestand: " + k)
		for c in main.get_children():
			if c.get_script() == JG:
				jg = c
		_check(jg != null, "JungleGeluid hangt niet in main")
		if jg == null:
			return _end()
		_check(game.state == "prep" or game.state == "play", "spel loopt niet: " + game.state)
		_check(jg.zone(Vector3(0, 0, 0)) < 0.25 and jg.zone(Vector3(0, 0, 0)) > 0.1, "midden op de basis klinkt de jungle een klein beetje: %f" % jg.zone(Vector3.ZERO))
		_check(jg.zone(Vector3(45, 0, -60)) > 0.99, "in het bos klinkt de jungle vol: %f" % jg.zone(Vector3(45, 0, -60)))
		_check(jg.zone(Vector3(0, 0, -110)) < 0.01, "in de stad klinkt niets: %f" % jg.zone(Vector3(0, 0, -110)))
		_check(jg.zone(Vector3(-20, 0, -115)) < 0.01, "ook in de westkant van de stad niets")
		game.player.global_position = Vector3(45, 0, -60)
		GameSettings.set_value("time", "day")
		GameSettings.set_value("weather", "clear")
	if frames == 200 and jg:
		_check(jg._bg_day.playing and not jg._bg_night.playing, "overdag: dag-lus aan, nacht-lus uit")
		_check(jg._bg_day.volume_db > -40.0, "dag-lus is te zacht")
		GameSettings.set_value("time", "night")
	if frames == 320 and jg:
		_check(jg._bg_night.playing and not jg._bg_day.playing, "'s nachts: nacht-lus aan, dag-lus uit")
		sfx.play("boom")
		_check(JG.calm <= 0.01, "explosie moet de jungle stil maken, calm = %f" % JG.calm)
		jg.last_call = ""
		jg._next_call = 0.0
	if frames == 330 and jg:
		_check(jg.last_call == "", "tijdens de stilte klinkt er geen roep")
		var v0: float = jg._bg_night.volume_db
		_check(v0 < linear_to_db(JG.BG_VOL * JG.MASTER * 0.8), "lus is niet zachter na een explosie")
	if frames == 1700 and jg:   # ~28 s later: weer rustig
		_check(JG.calm > 0.99, "jungle komt niet terug: calm = %f" % JG.calm)
		_check(jg.last_call in ["uil", "nachtzwaluw"], "'s nachts alleen uil of nachtzwaluw, kreeg '%s'" % jg.last_call)
		GameSettings.set_value("time", "day")
		GameSettings.set_value("weather", "rain")
		jg.last_call = ""
		jg._next_call = 0.0
	if frames == 1760 and jg:
		_check(jg.last_call == "", "in de regen geen vogels")
		GameSettings.set_value("weather", "clear")
		sfx.play("pistol", 1.0)
		_check(JG.calm <= 0.56 and JG.calm > 0.4, "pistoolschot hoort de jungle half stil te maken: %f" % JG.calm)
		game.state = "menu"
	if frames == 1900 and jg:
		_check(not jg._bg_day.playing and not jg._bg_night.playing and not jg._water.playing, "in het menu staat alles stil")
		return _end()
	return false


func _end() -> bool:
	print("JUNGLEGELUID TEST ", "OK" if fails == 0 else "%d FOUT(EN)" % fails)
	quit(1 if fails > 0 else 0)
	return true
