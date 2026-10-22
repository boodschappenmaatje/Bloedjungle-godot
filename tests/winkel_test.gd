extends SceneTree
## Test: de winkel met flat erboven. Naar binnen, trap A naar flat 1 (3,8), trap B naar flat 2 (6,8), het balkon,
## dan slopen: eerst de muren van flat 1 (flat 2 en het dak zakken in), dan de winkel (alles stort in).
## Draaien: godot --headless --path . -s tests/winkel_test.gd --fixed-fps 60

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
	return (game.player.global_position - Data.WINKEL_POS).snapped(Vector3(0.01, 0.01, 0.01))


func _at(v: Vector3) -> void:
	game.player.global_position = Data.WINKEL_POS + v
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
		w = get_nodes_in_group("winkel")[0]
		print("winkel op ", w.global_position, " muurstukken ", w.segs.size(), " deuren ", w.doors.size())
		_at(Vector3(0.0, 0, 7.0))
		move = Vector2(0, -1)
	if t == 120:
		print("door de winkeldeur: ", _l(), " binnen=", w._inside, " dak=", w._dak.visible, " flats zichtbaar=", w._groups[1].visible, w._groups[2].visible, " weg voor camera=", w._hidden.size())
		_at(Vector3(-3.75, 0.3, 1.7))
		move = Vector2(0, -1)
	if t == 150:
		print("trap A halverwege: ", _l())
	if t == 300:
		print("boven trap A (3.8): ", _l(), " binnen=", w._inside, " flat1=", w._groups[1].visible, " flat2=", w._groups[2].visible)
		move = Vector2(1, 0)
	if t == 309:
		move = Vector2.ZERO
	if t == 320:
		print("op het bordes naar trap B: ", _l())
		move = Vector2(0, 1)
	if t == 360:
		print("trap B halverwege: ", _l())
	if t == 480:
		print("boven trap B (6.8): ", _l(), " binnen=", w._inside, " flat2=", w._groups[2].visible, " dak=", w._dak.visible)
		move = Vector2(1, 0)
	if t == 600:
		print("flat 2 naar oost (y blijft 6.8): ", _l())
		_at(Vector3(0.0, 3.8, 2.5))
		move = Vector2(0, 1)
	if t == 700:
		print("flat 1 naar het balkon: ", _l(), " binnen=", w._inside)
		move = Vector2.ZERO
		_at(Vector3(0, 0, 16))
	if t == 720:
		print("buiten: binnen=", w._inside, " dak=", w._dak.visible)
		# raketten op flat 1 (alle gevels)
		for p in [Vector3(-3, 5.3, 4.6), Vector3(0, 5.3, 4.6), Vector3(3, 5.3, 4.6), Vector3(-3, 5.3, -4.6), Vector3(0, 5.3, -4.6), Vector3(3, 5.3, -4.6)]:
			for k in 3:
				w.blast(Data.WINKEL_POS + p, 2.2, 120.0)
		var gone: int = w.segs.filter(func(x): return String(x.name).begins_with("M1") and x.staat >= 2).size()
		print("flat 1 muren weg: ", gone, " _fall=", w._fall, " dak weg=", w._dak.get_meta("weg", false), " ruine=", w._ruin)
	if t == 780:
		_at(Vector3(1.0, 0.3, 0.0))   # in de winkel staan als alles instort
	if t == 800:
		print("speler in de winkel: binnen=", w._inside, " hp=", game.player.get("hp"))
		for p in [Vector3(-3, 1.6, 4.6), Vector3(0, 1.6, 4.6), Vector3(3, 1.6, 4.6), Vector3(4.9, 1.6, -2.5), Vector3(4.9, 1.6, 0)]:
			for k in 3:
				w.blast(Data.WINKEL_POS + p, 2.2, 120.0)
		var gone: int = w.segs.filter(func(x): return String(x.name).begins_with("M0") and x.staat >= 2).size()
		print("winkel muren weg: ", gone, " ruine=", w._ruin, " ruine zichtbaar=", w.model.find_child("Ruine", true, false).visible, " speler ", _l(), " hp=", game.player.get("hp"))
	if t == 840:
		print("na instorten: floor_at midden = ", w._floor_local(Vector3.ZERO, 0.0), " (−1 = geen vloer, ruïne heeft botsvorm)")
		print("KLAAR")
		return true
	return false
