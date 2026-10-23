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
var _wp := 0
var _top := 0.0
var _stuck := 0
var _last := Vector3.ZERO
# route langs de torendeur, trap A, trap B en ladder C naar het torendak en weer naar beneden (x, z, naam)
var _route := [[0.0, 8.2, "deur"], [-1.3, 8.4, "voet A"], [-1.3, 6.2, "boven A (3,9)"], [-1.3, 5.6, "overloop 1"], [0.0, 5.7, "gang 1"], [1.35, 5.55, "voet B"],
	[1.35, 8.4, "boven B (7,5)"], [0.0, 8.5, "gang 2"], [-1.3, 8.5, "voet C"], [-1.3, 5.7, "torendak (11,1)"], [0.0, 7.0, "midden dak"],
	[-1.3, 6.5, "gat C"], [-1.3, 8.5, "beneden C"], [0.0, 8.5, "gang 2b"], [1.35, 7.0, "gat B"], [1.35, 5.6, "beneden B"], [-1.3, 5.7, "naar A"], [-1.3, 8.4, "beneden A"]]


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
		_at(Vector3(0.0, 0, 13.0))
	if t > 0 and t < 1500 and _wp < _route.size():
		var w: Array = _route[_wp]
		var d := Vector2(w[0] - _l().x, w[1] - _l().z)
		if d.length() < 0.3:
			print("  bij ", w[2], ": ", _l(), " binnen=", k._inside)
			_wp += 1
			if _wp == _route.size():
				move = Vector2.ZERO
				print("route klaar, hoogste y ", _top)
				frames = 860 + 2
		else:
			move = d.normalized()
		_top = maxf(_top, game.player.position.y)
		if (_l() - _last).length() < 0.01:
			_stuck += 1
		else:
			_stuck = 0
		_last = _l()
		if _stuck > 60:
			print("VAST bij ", w[2], " ", _l())
			_wp = 999
			frames = 860 + 2
	if t > 0 and t < 860 and _wp >= _route.size():
		return false
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
