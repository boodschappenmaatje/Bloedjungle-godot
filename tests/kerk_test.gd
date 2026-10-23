extends SceneTree
## Test: de oude kerk. Door de torendeur naar binnen, trap A naar het uurwerk (3,9), trap B naar de klokkenkamer (7,5),
## de ladder door het luik naar het torendak (11,1), langs de kantelen. Dan slopen: het schip (dak valt, schip stort in,
## speler wordt eruit geduwd), de bovenkant van de toren (breekt af) en de torenvoet (de toren valt).
## Draaien: godot --headless --path . -s tests/kerk_test.gd --fixed-fps 60

var main: Node
var frames := 0
var game: Node
var move := Vector2.ZERO
var k


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	physics_frame.connect(func(): if frames > 3: game.move = move)


func _l() -> Vector3:
	return (game.player.global_position - Data.KERK_POS).snapped(Vector3(0.01, 0.01, 0.01))


func _at(v: Vector3) -> void:
	game.player.global_position = Data.KERK_POS + v
	game.player.position.y = v.y


func _gone(pre: String) -> int:
	return k.segs.filter(func(x): return String(x.name).begins_with(pre) and x.staat >= 2).size()


func _boom(p: Vector3, n: int) -> void:
	for i in n:
		k.blast(Data.KERK_POS + p, 2.2, 120.0)


func _process(_d: float) -> bool:
	frames += 1
	game = root.get_node("Game")
	var t := frames - 3
	if t == 0:
		main.begin()
		for n in root.find_children("*", "", true, false):
			if n.get_script() and String(n.get_script().resource_path).ends_with("touch_sticks.gd"):
				n.set_process(false)
		k = get_nodes_in_group("kerk")[0]
		print("kerk op ", k.global_position, " muurstukken ", k.segs.size(), " deuren ", k.doors.size(), " lagen ", k._groups.size())
		_at(Vector3(0.0, 0, 12.0))
		move = Vector2(0, -1)
	if t == 130:
		print("door de torendeur: ", _l(), " binnen=", k._inside, " schipdak=", k._dak.visible, " toren1 zichtbaar=", k._groups[1].visible, " weg voor camera=", k._hidden.size())
		move = Vector2.ZERO
		_at(Vector3(-1.48, 0.3, 9.0))
		move = Vector2(0, -1)
	if false:
		print("  ", t, " ", _l(), " y=", game.player.position.y, " fa=", k.floor_at(game.player.global_position, game.player.position.y), " tower=", game.player.tower)
	if t > 130 and t < 160 and t % 5 == 0 and false:
		print("  ", t, " ", _l(), " floor_at=", k.floor_at(game.player.global_position, game.player.position.y), " y=", game.player.position.y, " parent_y=", game.player.get_parent().global_position.y)
	if t == 160:
		print("trap A halverwege: ", _l())
	if t == 260:
		print("boven trap A (3.9): ", _l(), " binnen=", k._inside, " toren1=", k._groups[1].visible, " toren2=", k._groups[2].visible, " schipdak=", k._dak.visible)
		_at(Vector3(1.5, 3.9, 5.5))
		move = Vector2(0, 1)
	if t == 420:
		print("boven trap B (7.5): ", _l(), " binnen=", k._inside, " toren2=", k._groups[2].visible, " toren3=", k._groups[3].visible)
		_at(Vector3(-1.48, 7.5, 8.5))
		move = Vector2(0, -1)
	if t == 640:
		print("door het luik op het torendak (11.1): ", _l(), " binnen=", k._inside, " toren3=", k._groups[3].visible)
		move = Vector2(1, 0)
	if t == 760:
		print("over het torendak naar oost (kantelen houden je tegen): ", _l())
		move = Vector2(0, 1)
	if t == 860:
		print("naar voor (kantelen): ", _l())
		move = Vector2.ZERO
		_at(Vector3(0.5, 0.3, -1.0))   # in het schip staan als het instort
	if t == 920:
		print("in het schip: binnen=", k._inside, " schipdak=", k._dak.visible, " toren1=", k._groups[1].visible, " hp=", game.player.get("hp"))
		for z in [2.41, -0.86, -4.14]:
			_boom(Vector3(-5.3, 3.0, z), 3)
		print("schip west weg: ", _gone("S0"), " dak weg=", k._dak.get_meta("weg", false), " schip ingestort=", k._ruined.has("Schip"))
		for z in [2.41, -0.86]:
			_boom(Vector3(5.3, 3.0, z), 3)
		print("schip muren weg: ", _gone("S0"), " schip ingestort=", k._ruined.has("Schip"), " speler ", _l(), " hp=", game.player.get("hp"),
			" ruine zichtbaar=", k.model.find_child("RuineSchip", true, false).visible, " torenruine zichtbaar=", k.model.find_child("RuineToren", true, false).visible)
		print("floor_at in het schip = ", k._floor_local(Vector3(0, 0, -2), 0.3), " in de toren = ", k._floor_local(Vector3(0, 0, 7), 0.3))
		_at(Vector3(-0.2, 3.9, 6.5))   # in de toren op laag 1
	if t == 960:
		print("toren laag 1: ", _l(), " binnen=", k._inside)
		_boom(Vector3(0, 9.3, 10.1), 5)
		_boom(Vector3(-3.1, 9.3, 7.0), 5)
		print("klokkenkamer muren weg: ", _gone("M2"), " _fall=", k._fall, " floor_at laag 2 = ", k._floor_local(Vector3(0, 0, 6.5), 7.5))
	if t == 1000:
		_boom(Vector3(0, 1.9, 10.1), 5)
		_boom(Vector3(3.1, 1.9, 7.0), 5)
		print("torenvoet muren weg: ", _gone("M0"), " toren ingestort=", k._ruined.has("Toren"), " alles plat=", k._ruin,
			" speler ", _l(), " hp=", game.player.get("hp"), " relingen over=", k._guard_bodies.size())
	if t == 1040:
		print("na instorten: floor_at toren = ", k._floor_local(Vector3(0, 0, 7), 4.0), " schip = ", k._floor_local(Vector3(0, 0, -2), 0.3))
		print("KLAAR")
		return true
	return false
