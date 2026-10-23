extends SceneTree
## Test: het benzinestation. Onder de luifel door (luifel gaat weg), door de winkeldeur naar binnen (dak weg, vloer 0,2),
## langs de rekken naar de opslag achterin. Dan een pomp beschieten: hij gaat branden en ontploft, de andere pompen en de
## olievaten gaan mee (kettingreactie), de kolommen knakken (luifel klapt in) en de muren van het winkeltje gaan eruit.
## Draaien: godot --headless --path . -s tests/benzine_test.gd --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var move := Vector2.ZERO
var b
var _wp := 0
var _stuck := 0
var _last := Vector3.ZERO
var _done := -1
# route van de straat onder de luifel door, de winkel in en naar de opslag (x, z, naam)
var _route := [[0.0, 2.5, "onder de luifel"], [0.0, -0.8, "binnen bij de deur"], [1.2, -0.9, "voor de toonbank"], [-2.2, -0.8, "langs het rek"],
	[-2.2, -3.2, "bij de binnendeur"], [-2.2, -4.4, "opslag"], [-2.2, -0.8, "terug"], [0.0, -0.8, "deur"], [0.0, 7.0, "buiten"]]


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3: game.move = move)


func _l() -> Vector3:
	return (game.player.global_position - Data.BENZINE_POS).snapped(Vector3(0.01, 0.01, 0.01))


func _at(v: Vector3) -> void:
	game.player.global_position = Data.BENZINE_POS + v
	game.player.position.y = v.y


func _gone(pre: String) -> int:
	return b.segs.filter(func(x): return String(x.name).begins_with(pre) and x.staat >= 2).size()


func _lit() -> int:
	return b.pumps.filter(func(p): return p.lit).size()


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	var t := frames - 3
	if t == 0:
		main.begin()
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		var list := get_nodes_in_group("benzine")
		if list.is_empty():
			print("FOUT: geen benzinestation in de stad")
			return true
		b = list[0]
		print("benzinestation op ", b.global_position, " muurstukken ", b.segs.size(), " pompen+vaten ", b.pumps.size(), " deuren ", b.doors.size())
		_at(Vector3(0.0, 0, 9.0))
	if t <= 0:
		return false
	if _wp < _route.size():
		var w: Array = _route[_wp]
		var d := Vector2(w[0] - _l().x, w[1] - _l().z)
		if d.length() < 0.3:
			var luifel: Node3D = b.model.find_child("LuifelDak", true, false)
			print("  bij ", w[2], ": ", _l(), " binnen=", b._inside, " dak=", b._dak.visible, " luifel=", luifel.visible)
			_wp += 1
			if _wp == _route.size():
				move = Vector2.ZERO
		else:
			move = d.normalized()
		if (_l() - _last).length() < 0.005:
			_stuck += 1
		else:
			_stuck = 0
		_last = _l()
		if _stuck > 60:
			print("VAST bij ", w[2], " ", _l())
			_wp = 999
			move = Vector2.ZERO
		if t > 1400:
			print("TE LANG onderweg")
			_wp = 999
		return false
	if _done < 0:
		_done = t
		_at(Vector3(0.0, 0, 16.0))
		var p = b.pumps.filter(func(x): return String(x.get_parent().name).begins_with("XPomp"))[0]
		print("pomp beschieten: ", p.get_parent().name, " speler hp=", game.player.get("hp"))
		p.hit(30.0, Vector3(1, 0, 0), true)
		p.hit(30.0, Vector3(1, 0, 0), true)   # 60 van de 90: hij lekt en brandt, en ontploft vanzelf na 2,4..3,4 s
		print("  brandt=", p.burning, " ontploft=", p.lit, " hp=", p.hp)
	if t > _done and (t - _done) % 20 == 0 and t < _done + 300:
		print("    t=", t - _done, " hp=", game.player.get("hp"), " pos=", _l(), " state=", game.state, " vijanden=", game.enemies.size())
	if t == _done + 60:
		print("na 1 s: aangestoken ", _lit(), "/", b.pumps.size())
	if t == _done + 300:
		print("na 5 s: aangestoken ", _lit(), "/", b.pumps.size(), " kolommen weg ", _gone("K"), " luifel ingestort=", b._ruined.has("Luifel"),
			" muren weg ", _gone("M0"), " winkel ingestort=", b._ruined.has("Winkel"), " dak weg=", b._dak.get_meta("weg", false),
			" speler hp=", game.player.get("hp"))
		print("  ruines zichtbaar: luifel=", b.model.find_child("RuineLuifel", true, false).visible, " winkel=", b.model.find_child("RuineWinkel", true, false).visible)
		print("  wrakken: ", b.pumps.filter(func(p): return p._kapot.visible).size(), " floor_at in de winkel = ", b._floor_local(Vector3(0, 0, -2), 0.2))
	if t == _done + 320:
		print("KLAAR")
		return true
	return false
