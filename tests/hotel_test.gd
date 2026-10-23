extends SceneTree
## Test: het hotel. Naar binnen, trap A naar verdieping 1 (3,8), B naar 2 (6,8), C naar 3 (9,8), het balkon,
## dan slopen: eerst de muren van verdieping 2 (3 stort in), dan verdieping 1, dan de lobby (alles stort in).
## Draaien: godot --headless --path . -s tests/hotel_test.gd --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var move := Vector2.ZERO
var w


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3: game.move = move)


func _l() -> Vector3:
	return (game.player.global_position - Data.HOTEL_POS).snapped(Vector3(0.01, 0.01, 0.01))


func _at(v: Vector3) -> void:
	game.player.global_position = Data.HOTEL_POS + v
	game.player.position.y = v.y


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	var t := frames - 3
	if t == 0:
		main.begin()
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		w = get_nodes_in_group("hotel")[0]
		print("hotel op ", w.global_position, " muurstukken ", w.segs.size(), " deuren ", w.doors.size(), " groepen ", w._groups.size())
		_at(Vector3(0.0, 0, 7.0))
		move = Vector2(0, -1)
	if t == 120:
		print("door de voordeur: ", _l(), " binnen=", w._inside, " dak=", w._dak.visible, " verdiepingen zichtbaar=", w._groups[1].visible, w._groups[2].visible, w._groups[3].visible)
		_at(Vector3(-4.25, 0.3, 1.7))
		move = Vector2(0, -1)
	if t == 150:
		print("trap A halverwege: ", _l())
	if t == 300:
		print("boven trap A (3.8): ", _l(), " binnen=", w._inside)
		move = Vector2(1, 0)
	if t == 309:
		move = Vector2.ZERO
	if t == 320:
		print("op het bordes naar trap B: ", _l())
		move = Vector2(0, 1)
	if t == 360:
		print("trap B halverwege: ", _l())
	if t == 480:
		print("boven trap B (6.8): ", _l(), " binnen=", w._inside)
		move = Vector2(0, -1)   # van de voorste overloop eerst naar achteren tot voor trap C, dan naar het westen
	if t == 497:
		move = Vector2(-1, 0)
	if t == 507:
		move = Vector2(0, -1)
	if t == 540:
		print("trap C halverwege: ", _l())
	if t == 660:
		print("boven trap C (9.8): ", _l(), " binnen=", w._inside, " dak=", w._dak.visible)
		move = Vector2(1, 0)
	if t == 780:
		print("verdieping 3 naar oost (y blijft 9.8): ", _l())
		_at(Vector3(0.0, 3.8, 2.5))
		move = Vector2(0, 1)
	if t == 880:
		print("verdieping 1 naar het balkon: ", _l(), " binnen=", w._inside)
		move = Vector2.ZERO
		_at(Vector3(0, 0, 20))
	if t == 900:
		print("buiten: binnen=", w._inside, " dak=", w._dak.visible)
		# verdieping 2 slopen: 5 muren weg, dan zakt verdieping 3 met het dak in
		for p in [Vector3(-3.4, 8.3, 5.1), Vector3(0, 8.3, 5.1), Vector3(3.4, 8.3, 5.1), Vector3(-3.4, 8.3, -5.1), Vector3(0, 8.3, -5.1), Vector3(3.4, 8.3, -5.1)]:
			for k in 5:
				w.blast(Data.HOTEL_POS + p, 2.4, 160.0)
		var gone: int = w.segs.filter(func(x): return String(x.name).begins_with("M2") and x.staat >= 2).size()
		print("verdieping 2 muren weg: ", gone, " _fall=", w._fall, " dak weg=", w._dak.get_meta("weg", false), " ruine=", w._ruin)
	if t == 960:
		for p in [Vector3(-3.4, 5.3, 5.1), Vector3(0, 5.3, 5.1), Vector3(3.4, 5.3, 5.1), Vector3(-3.4, 5.3, -5.1), Vector3(0, 5.3, -5.1), Vector3(3.4, 5.3, -5.1)]:
			for k in 5:
				w.blast(Data.HOTEL_POS + p, 2.4, 160.0)
		var gone: int = w.segs.filter(func(x): return String(x.name).begins_with("M1") and x.staat >= 2).size()
		print("verdieping 1 muren weg: ", gone, " _fall=", w._fall, " ruine=", w._ruin)
		_at(Vector3(1.0, 0.3, 0.0))   # in de lobby staan als alles instort
	if t == 1000:
		print("speler in de lobby: binnen=", w._inside, " hp=", game.player.get("hp"))
		for p in [Vector3(-3.4, 1.6, 5.1), Vector3(0, 1.6, 5.1), Vector3(3.4, 1.6, 5.1), Vector3(5.1, 1.6, -2.5), Vector3(5.1, 1.6, 0), Vector3(-3.4, 1.6, -5.1), Vector3(0, 1.6, -5.1)]:
			for k in 5:
				w.blast(Data.HOTEL_POS + p, 2.4, 160.0)
		var gone: int = w.segs.filter(func(x): return String(x.name).begins_with("M0") and x.staat >= 2).size()
		print("lobby muren weg: ", gone, " ruine=", w._ruin, " ruine zichtbaar=", w.model.find_child("Ruine", true, false).visible, " speler ", _l(), " hp=", game.player.get("hp"))
	if t == 1040:
		print("na instorten: floor_at midden = ", w._floor_local(Vector3.ZERO, 0.0), " (-1 = geen vloer, ruine heeft botsvorm)")
		print("KLAAR")
		return true
	return false
