class_name TroepSelectie
extends Node
## Troepenbevel zoals in Command & Conquer, voor de vinger (Dennis' keuzes 4A t/m 11A, 11 nov 2026).
## Hier staat welke eigen soldaten je gekozen hebt, de drie groepsvakjes, het uitgeven van een bevel aan die keuze,
## de bevelmarkers op de grond en het vertragen van het spel tot 30 % zolang de bevelstand of de grote kaart open is.
## De bevelstand (BevelStand) en de grote kaart (GroteKaart) gebruiken allebei deze ene lijst.
## Zonder keuze werkt het oude commandowiel (TeamCommands) zoals altijd voor je hele leger.
## Sinds de stap "voertuigbevel" (Dennis' keuze 2A, 11 nov 2026) staan je jeeps en tanks in dezelfde lijst: hun ingebouwde bestuurder (`VoertuigBestuurder`)
## heeft dezelfde velden en dezelfde `set_command` als een soldaat, dus alles hieronder werkt voor soldaten en voertuigen door elkaar.

const Controller = preload("res://scripts/team_command_controller.gd")

const SLOW := 0.3            # speltempo tijdens het bevelen (11A)
const MARK_TIME := 1.6       # s echte tijd: zo lang staat een grondmarker en de bevellijnen in het spel (9A)
const ORDERS := ["move", "attack", "defend", "hold", "bewaak", "follow"]   # de bevelbalk, van links naar rechts (8A)
const LABELS := {"move": "VERPLAATS", "attack": "AANVAL", "defend": "VERDEDIG", "hold": "HOUD", "bewaak": "BEWAAK", "follow": "VOLG MIJ"}
## Bevelen die meteen gelden; de rest wacht op een tik op de grond, een vijand of iets om te bewaken.
const DIRECT := ["hold", "follow"]
const GREEN := Color(0.55, 0.92, 0.42)
const GREEN_HI := Color(0.72, 1.0, 0.56)
const RED := Color(1.0, 0.36, 0.26)
const GOLD := Color(0.96, 0.78, 0.36)

var sel: Array = []                 # de gekozen soldaten (Ally)
var groepen: Array = [[], [], []]   # groepsvakjes 1, 2 en 3 (6A)
var armed := "move"                 # wat een tik op de grond doet (slim tikken, 7A); AANVAL op de grond = aanvallend oprukken
var marks: Array = []               # {pos, order, t}: korte markers op de grond
var order_t := -100.0               # echte tijd (s) van het laatste bevel: zo lang daarna zie je de lijnen ook buiten de bevelstand
var _slowed := false
var gebouw: Garnizoen              # een gebouw met jouw soldaten dat je aantikte: de bevelstand toont dan ERUIT (F2, 4A)


static func inst(tree: SceneTree) -> TroepSelectie:
	return tree.get_first_node_in_group("troep_selectie") as TroepSelectie


static func now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Een eigen soldaat die bevelen aanneemt: leeft, hoort bij je leger en is geen wacht, versterking of passagier. Of een jeep of tank (de bestuurder) waar jij niet in zit.
static func commandable(a) -> bool:
	if not is_instance_valid(a):
		return false
	if a is VoertuigBestuurder:
		return a.bevelbaar()
	return a is Node3D and Game.allies.has(a) and a.get("binnen") == null and Controller.can_command(bool(a.get("helper")), bool(a.get("guard")), a.get("truck") != null)


## Soldaten en voertuigen die je nu kunt bevelen.
static func units() -> Array:
	var out: Array = []
	for a in Game.allies:
		if commandable(a):
			out.append(a)
	out.append_array(vehicles())
	return out


## Alleen de jeeps en tanks die je kunt bevelen.
static func vehicles() -> Array:
	var out: Array = []
	for b in VoertuigBestuurder.all:
		if commandable(b):
			out.append(b)
	return out


static func is_vehicle(a) -> bool:
	return a is VoertuigBestuurder


## "3 soldaten", "1 jeep", "2 voertuigen" of "4 eenheden" (door elkaar): voor de tekst bij de keuze.
static func wie(list: Array) -> String:
	var soldiers := 0
	var jeeps := 0
	var tanks := 0
	for a in list:
		if not is_instance_valid(a):
			continue
		if a is VoertuigBestuurder:
			if a.kind == "tank":
				tanks += 1
			else:
				jeeps += 1
		else:
			soldiers += 1
	var veh := jeeps + tanks
	if veh == 0:
		return "%d %s" % [soldiers, "soldaat" if soldiers == 1 else "soldaten"]
	if soldiers == 0:
		if veh == 1:
			return "1 tank" if tanks == 1 else "1 jeep"
		return "%d voertuigen" % veh
	return "%d eenheden" % (soldiers + veh)



func _ready() -> void:
	name = "TroepSelectie"
	add_to_group("troep_selectie")
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	if _slowed:
		Engine.time_scale = 1.0
		_slowed = false


func is_selected(a) -> bool:
	return sel.has(a)


func clear() -> void:
	sel.clear()
	armed = "move"


func select(list: Array, add := false) -> void:
	if not add:
		sel.clear()
	for a in list:
		if commandable(a) and not sel.has(a):
			sel.append(a)
	if sel.is_empty():
		armed = "move"


func toggle(a) -> void:
	if sel.has(a):
		sel.erase(a)
	elif commandable(a):
		sel.append(a)


func select_all() -> void:
	select(units())


## De knop VOERTUIGEN: al je jeeps en tanks.
func select_vehicles() -> void:
	select(vehicles())


## Dubbeltik: alle soldaten van dezelfde soort uit `pool` (bijvoorbeeld wat in beeld is).
func select_kind(kind: String, pool: Array) -> void:
	var list: Array = []
	for a in pool:
		if commandable(a) and String(a.get("kind")) == kind:
			list.append(a)
	select(list)


func prune() -> void:
	for i in range(sel.size() - 1, -1, -1):
		if not commandable(sel[i]):
			sel.remove_at(i)
	for g in groepen:
		for i in range(g.size() - 1, -1, -1):
			if not commandable(g[i]):
				g.remove_at(i)


## Groepsvakje vasthouden: de huidige keuze komt onder dit vakje.
func save_group(i: int) -> void:
	prune()
	groepen[i] = sel.duplicate()
	Sfx.play("ping", 0.3)


## Groepsvakje aantikken: die groep is je keuze. False als het vakje leeg is.
func pick_group(i: int) -> bool:
	prune()
	if (groepen[i] as Array).is_empty():
		return false
	select(groepen[i])
	return true


func group_count(i: int) -> int:
	var n := 0
	for a in groepen[i]:
		if commandable(a):
			n += 1
	return n


## Midden van de keuze (voor de lijnen en de camera).
func center() -> Vector3:
	var c := Vector3.ZERO
	var n := 0
	for a in sel:
		if is_instance_valid(a):
			c += (a as Node3D).global_position
			n += 1
	return c / float(n) if n > 0 else Vector3.ZERO


## Geeft de gekozen soldaten een bevel. `target` is een punt op de grond, `enemy` een vijand, `node` iets om te bewaken.
## Aanvallen op (of vlak bij) de vijandbasis wordt de mars naar zijn poort, zoals bij het wiel. Geeft het aantal soldaten terug.
func issue(order: String, target := Vector3.ZERO, enemy: Node3D = null, node: Node3D = null) -> int:
	prune()
	if sel.is_empty():
		return 0
	var mark_at := target
	if order == "attack" and not is_instance_valid(enemy) and VijandBasis.contains(target, 6.0):
		order = "basis"
		mark_at = VijandBasis.gate_outside()
		target = mark_at
	elif is_instance_valid(enemy):
		mark_at = enemy.global_position
		target = mark_at
	elif is_instance_valid(node):
		mark_at = node.global_position
		target = mark_at
	elif order == "hold" or order == "follow":
		mark_at = center()
	for i in sel.size():
		var o := order
		if o == "bezet" and is_vehicle(sel[i]):
			o = "move"   # een jeep of tank past niet in een huis: hij rijdt naar de deur
		sel[i].set_command(o, target, enemy, node, i)
	var boek := get_tree().root.get_node_or_null("Game/Logboek") if is_inside_tree() else null   # foutenlogboek
	if boek != null:
		boek.noteer_actie("bevel %s aan %d eenheden naar (%.0f, %.0f)" % [order, sel.size(), target.x, target.z])
	marks.append({"pos": Vector3(mark_at.x, 0.0, mark_at.z), "order": order, "t": now()})
	if marks.size() > 6:
		marks.pop_front()
	order_t = now()
	armed = "move"
	Sfx.play("ping", 0.22)
	Game.changed.emit()
	return sel.size()


## Een knop van de bevelbalk. HOUD en VOLG MIJ gelden meteen; de rest wacht op een tik (VERPLAATS, AANVAL, VERDEDIG, BEWAAK).
## Geeft "leeg" (niemand gekozen), "issued" of "armed".
func bar_press(order: String) -> String:
	prune()
	if sel.is_empty():
		Game.banner.emit("NIEMAND GEKOZEN", "Tik een soldaat aan, sleep een kader of tik ALLES.", 2.2)
		return "leeg"
	if order in DIRECT:
		issue(order)
		return "issued"
	armed = order
	Sfx.play("ping", 0.15)
	return "armed"


## Een tik in de wereld of op de kaart terwijl er soldaten gekozen zijn (slim tikken, 7A):
## op een vijand = aanvallen, op de grond = het gekozen bevel (standaard verplaatsen), BEWAAK = wat je aantikt.
## `own` is een eigen gebouw, voertuig, soldaat of jijzelf onder de vinger (of null). Geeft "issued", "wacht" of "geweigerd".
func apply_tap(world: Vector3, enemy: Node3D, own: Node3D) -> String:
	if armed == "bewaak":
		if is_instance_valid(own):
			issue("bewaak", own.global_position, null, own)
			return "issued"
		Game.banner.emit("BEWAKEN", "Tik op een gebouw, een voertuig, een soldaat of op jezelf.", 2.4)
		return "wacht"
	if is_instance_valid(enemy):
		issue("attack", enemy.global_position, enemy)
		return "issued"
	if VijandBasis.contains(world, 2.0):
		if armed in ["move", "attack"]:
			issue("attack", world)   # tik op de vijandbasis = aanvallen, zoals in C&C (de mars naar zijn poort)
			return "issued"
		Game.banner.emit("VIJANDBASIS", "Daar kun je niet verdedigen. Tik op de basis met VERPLAATS of AANVAL om hem aan te vallen.", 2.5)
		return "geweigerd"
	if armed in ["move", "defend"]:
		var gz := Garnizoen.at(world)
		if gz != null:
			if gz.partij == "vijand":
				Game.banner.emit("BEZET DOOR DE VIJAND", "Haal ze eruit met granaten, raketten of napalm, of loop zelf naar binnen.", 2.6)
				return "geweigerd"
			issue("bezet", gz.deur(), null, gz)   # 4A: tik op een stadsgebouw = erin
			return "issued"
	issue(armed, world)
	return "issued"


## Wat bewaakt kan worden in de buurt van een punt in de wereld: jij, een soldaat, een voertuig of een gebouw (dichtstbij binnen `r` m).
static func guardable_near(tree: SceneTree, world: Vector3, r: float) -> Node3D:
	var best: Node3D = null
	var bd := r * r
	var cands: Array = [Game.player]
	cands.append_array(Game.allies)
	cands.append_array(tree.get_nodes_in_group("voertuigen"))
	cands.append_array(tree.get_nodes_in_group("voorraadtruck"))
	for b in Game.buildings:
		if b is Dictionary and b.get("node") != null and is_instance_valid(b.get("node")) and not bool(b.get("down", false)):
			cands.append(b.get("node"))
	for c in cands:
		if not is_instance_valid(c) or not c is Node3D or c.get("dead") == true:
			continue
		var p: Vector3 = (c as Node3D).global_position
		var d2 := Vector2(p.x - world.x, p.z - world.z).length_squared()
		if d2 < bd:
			bd = d2
			best = c
	return best


## De markers die nog zichtbaar zijn (0..1 = hoe ver ze al vervaagd zijn).
func live_marks() -> Array:
	var t := now()
	for i in range(marks.size() - 1, -1, -1):
		if t - float(marks[i].t) > MARK_TIME:
			marks.remove_at(i)
	return marks


## Bevellijnen in het spel: kort na een bevel (of altijd tijdens de bevelstand, zie BevelStand).
func lines_fresh() -> bool:
	return now() - order_t < MARK_TIME


static func order_color(order: String) -> Color:
	match order:
		"attack", "basis":
			return RED
		"defend", "hold", "bewaak":
			return GOLD
	return GREEN


## Bevelstand of grote kaart open: het spel loopt op 30 %. Alles wat de stand afsluit (pauze, menu, bouwen) zet het terug op 100 %.
func _process(_delta: float) -> void:
	prune()
	var commanding := get_tree().get_first_node_in_group("bevelstand_actief") != null or _map_open()
	var want := commanding and Game.state in ["prep", "play"] and not get_tree().paused and not Game.build_mode and not Game.editing
	if want != _slowed:
		_slowed = want
		Engine.time_scale = SLOW if want else 1.0


func _map_open() -> bool:
	var hud := get_tree().get_first_node_in_group("hud_extra")
	return hud != null and hud.map_is_open()


func slowed() -> bool:
	return _slowed
