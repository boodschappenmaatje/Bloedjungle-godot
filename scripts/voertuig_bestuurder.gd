class_name VoertuigBestuurder
extends Node3D
## De ingebouwde bestuurder van je eigen jeep en tank (Generals-plan, stap "voertuigbevel"). Dennis' keuzes van 11 november 2026: 1A een ingebouwde bestuurder (gratis, geen soldaat nodig),
## 2A voertuigen doen mee in de bevelstand en op de kaart (dezelfde lijst als soldaten), 3A dezelfde zes bevelen, 4A ook de vijandbasis aanvallen, 5A de jeep schiet rijdend en de tank alleen
## stilstaand, 6A vrij rijden in jouw gebied en over de brug, in de stad de vaste voertuigroute (`VoertuigRoute`), 7A instappen wist het bevel en uitstappen is HOUD, 8A een konvooi met afstand,
## 9A vast = terugzetten, nog een keer proberen, dan melding en stoppen.
##
## Dit onderdeel hangt als kind aan `jeep.gd` of `tank.gd` (`VoertuigBestuurder.attach`), net als `VoertuigSchade`. Het is zelf de "eenheid" die je kiest: het heeft dezelfde velden en
## dezelfde `set_command` als een soldaat (`Ally`), zodat `TroepSelectie`, de bevelstand, de bevelbalk en de grote kaart soldaten en voertuigen in één lijst houden. Het rijden en schieten doet
## het voertuig zelf: elk beeld vraagt het voertuig `think(delta)` en leest daarna `stuur()` (een denkbeeldige linkerstick, zoals jij die gebruikt).

const KINDS := {
	"jeep": {"naam": "JEEP", "ring": 2.2, "cruise": 11.0, "len": 4.2, "follow": 8.0, "gap": 6.0, "stop": 2.5, "standoff": 11.0, "range": 30.0, "wp": 3.0,
		"whisker": 7.0, "side": 1.0, "ahead": 1.9, "half": 1.9},
	"tank": {"naam": "TANK", "ring": 3.4, "cruise": 4.5, "len": 5.8, "follow": 12.0, "gap": 10.0, "stop": 3.0, "standoff": 28.0, "range": 34.0, "wp": 4.0,
		"whisker": 9.0, "side": 1.9, "ahead": 2.6, "half": 2.6},
}
const CHASE := 14.0          # m: zo ver van zijn plek gaat een verdedigende of bewakende jeep een vijand achterna (zoals soldaten)
const SIEGE_HK := 30.0       # m: zo dichtbij het hoofdkwartier (plat, tot zijn rand) begint een tank het te beschieten
const RECOVER := 1.6         # s achteruit na vastlopen
const MAX_TRIES := 4         # zoveel keer terugzetten, dan geeft hij het op ("VAST")
const GATE_REACH := 16.0     # m: zo ver van een poort van jouw kamp opent hij voor een rijdend voertuig (Gates)

static var all: Array = []   # alle bestuurders van levende voertuigen

var kind := "jeep"
var vehicle: CharacterBody3D
var schade: VoertuigSchade

# dezelfde velden als een soldaat (Ally), zodat de bevelstand, de balk en de kaart ze zonder uitzonderingen lezen
var command := "hold"
var command_target := Vector3.ZERO
var command_enemy: Node3D
var command_node: Node3D
var command_slot := -1
var command_hold_position := Vector3.ZERO

var drive_dir := Vector3.ZERO     # de richting (wereld) waar hij heen wil; nul = remmen
var drive_speed := 0.0            # m/s vooruit
var arrived := true               # staat op zijn plek (of heeft niets te doen)
var vast := false                 # gaf het op: kon zijn weg niet vinden
var waiting_bridge := false       # wacht voor de brug die omhoog staat
var siege := false                # een tank die stilstaat om te beschieten

var _plan: Array = []
var _plan_i := 0
var _plan_goal := Vector3(1.0e9, 0.0, 1.0e9)
var _plan_cross := -1
var _plan_short := false
var _replan_t := 0.0
var _scan_t := 0.0
var _scan_hit: Node3D
var _back_t := 0.0
var _back_dir := 1.0
var _stuck := 0
var _tries := 0
var _sample_t := 0.0
var _sample_pos := Vector3.ZERO
var _sample_yaw := 0.0
var _alpha := 0.0
var _bridge_said := false
var _road_said := false


# ---------------------------------------------------------------- aanmaken

static func attach(v: CharacterBody3D, kind_: String, schade_: VoertuigSchade) -> VoertuigBestuurder:
	var b := VoertuigBestuurder.new()
	b.name = "Bestuurder"
	b.kind = kind_
	b.vehicle = v
	b.schade = schade_
	v.add_child(b)
	return b


## De bestuurder van dit voertuig (jeep of tank), of null.
static func of(v: Node) -> VoertuigBestuurder:
	if v == null:
		return null
	return v.get_node_or_null("Bestuurder") as VoertuigBestuurder


func _ready() -> void:
	for i in range(all.size() - 1, -1, -1):
		if not is_instance_valid(all[i]):
			all.remove_at(i)
	all.append(self)


func _exit_tree() -> void:
	all.erase(self)


# ---------------------------------------------------------------- wat de bevelstand ziet (zoals bij een soldaat)

var hp: float:
	get:
		return schade.hp if schade != null else 0.0

var hp_max: float:
	get:
		return schade.max_hp if schade != null else 1.0

var dead: bool:
	get:
		return schade == null or schade.dead

var ring_r: float:
	get:
		return float(KINDS[kind].ring)


## Neemt hij bevelen aan? Hij leeft, jij zit er niet in en hij rijdt niet nog uit de garage.
func bevelbaar() -> bool:
	return is_instance_valid(vehicle) and not dead and not vehicle.driven and vehicle.goals.is_empty()


## Stuurt de bestuurder het voertuig nu (spel loopt, bevelbaar)?
func aktief() -> bool:
	return bevelbaar() and (Game.state == "play" or Game.state == "prep")


## Voor de poort van jouw kamp: opent die voor dit voertuig?
func wil_poort() -> bool:
	return aktief() and not arrived


func naam() -> String:
	return String(KINDS[kind].naam)


## Een bevel, met dezelfde aanroep als bij een soldaat (Ally.set_command).
func set_command(order: String, target: Vector3, enemy: Node3D = null, node: Node3D = null, slot := -1) -> void:
	if dead or not is_instance_valid(vehicle) or vehicle.driven:
		return
	command = order
	command_target = target
	command_enemy = enemy if is_instance_valid(enemy) else null
	command_node = node if is_instance_valid(node) and node != vehicle else null
	command_slot = slot
	command_hold_position = vehicle.global_position
	if order == "bewaak" and command_node == null:
		command = "hold"
	_reset_drive()


## Jij stapt in: het bevel vervalt en jij rijdt (7A).
func on_board() -> void:
	command = "hold"
	command_enemy = null
	command_node = null
	_reset_drive()


## Jij stapt uit: hij blijft staan en schiet terug, tot je een nieuw bevel geeft (7A).
func on_leave() -> void:
	command = "hold"
	command_enemy = null
	command_node = null
	command_hold_position = vehicle.global_position
	_reset_drive()


func _reset_drive() -> void:
	vast = false
	arrived = false
	waiting_bridge = false
	siege = false
	_plan.clear()
	_plan_goal = Vector3(1.0e9, 0.0, 1.0e9)
	_stuck = 0
	_tries = 0
	_back_t = 0.0
	drive_dir = Vector3.ZERO
	drive_speed = 0.0
	_bridge_said = false
	_road_said = false
	_sample_t = 0.0
	if is_instance_valid(vehicle):
		_sample_pos = vehicle.global_position
		_sample_yaw = vehicle.rotation.y


## De denkbeeldige linkerstick (wereldrichting x en z, lengte 0 tot 1) voor `vmax` = de topsnelheid die het voertuig bij een volle stick rijdt.
func stuur(vmax: float) -> Vector2:
	if drive_dir == Vector3.ZERO:
		return Vector2.ZERO
	var m := 0.8 if _back_t > 0.0 else clampf(drive_speed / (vmax * 1.3), 0.0, 1.0)
	if drive_speed > 0.1 and m < 0.16:
		m = 0.16   # onder 0,15 negeert het voertuig de stick
	return Vector2(drive_dir.x, drive_dir.z).normalized() * m


func _flat(p: Vector3) -> float:
	return Vector2(p.x - vehicle.global_position.x, p.z - vehicle.global_position.z).length()


# ---------------------------------------------------------------- wat hij wil

func _offset() -> Vector3:
	var i := maxi(command_slot, 0)
	if i == 0:
		return Vector3.ZERO
	var a := float(i) * 2.4 + 0.6
	var r := 5.0 + 2.5 * float(i % 3)
	return Vector3(cos(a), 0.0, sin(a)) * r


## De dichtstbijzijnde levende vijand binnen `r` m van `center` (vier keer per seconde opnieuw gekeken).
func threat_near(center: Vector3, r: float) -> Node3D:
	var best: Node3D = null
	var bd := r * r
	for e in Game.enemies:
		if not is_instance_valid(e) or not e is Node3D or e.get("dead") == true:
			continue
		var d := (e as Node3D).global_position - center
		var d2 := d.x * d.x + d.z * d.z
		if d2 < bd:
			bd = d2
			best = e
	return best


## De vijand waar het geschut van dit voertuig nu op richt: de dichtstbijzijnde binnen zijn bereik (vier keer per seconde opnieuw gekozen).
func gun_target(delta: float) -> Node3D:
	_scan_t -= delta
	if _scan_t <= 0.0 or (_scan_hit != null and (not is_instance_valid(_scan_hit) or _scan_hit.get("dead") == true)):
		_scan_t = 0.25
		_scan_hit = threat_near(vehicle.global_position, float(KINDS[kind].range))
	return _scan_hit


## Het hoofdkwartier van de vijand als beschietingsdoel voor een tank die naar de basis rijdt: het punt waar de granaat moet landen, of null.
func siege_point() -> Variant:
	if kind != "tank" or command != "basis":
		return null
	var hk := VijandHk.inst
	if hk == null or not is_instance_valid(hk) or hk.down:
		return null
	if VijandBasis.hk_distance(vehicle.global_position) > SIEGE_HK:
		return null
	return hk.global_position + VijandHk.KERN_MIDDEN


func _goal() -> Dictionary:
	var s: Dictionary = KINDS[kind]
	match command:
		"move":
			return {"pos": command_target + _offset(), "stop": s.stop}
		"attack":
			if is_instance_valid(command_enemy) and command_enemy.get("dead") != true:
				return {"pos": command_enemy.global_position, "stop": s.standoff}
			command_enemy = null   # die is dood: verder naar zijn plek, en onderweg schiet het geschut op wat er is
			return {"pos": command_target + _offset(), "stop": s.stop}
		"basis":
			var inside: bool = kind == "tank"
			return {"pos": VoertuigRoute.basis_points(inside), "stop": 3.0}
		"defend":
			var th := threat_near(command_target, CHASE) if kind == "jeep" else null
			if th != null:
				return {"pos": th.global_position, "stop": s.standoff}
			return {"pos": command_target + _offset(), "stop": float(s.stop) + 1.0}
		"bewaak":
			if not is_instance_valid(command_node) or command_node.get("dead") == true:
				command = "hold"
				command_hold_position = vehicle.global_position
				return {}
			var c := command_node.global_position
			var th2 := threat_near(c, CHASE) if kind == "jeep" else null
			if th2 != null:
				return {"pos": th2.global_position, "stop": s.standoff}
			return {"pos": c + _offset(), "stop": 4.0 if kind == "jeep" else 6.0}
		"follow":
			if Game.player == null:
				return {}
			return {"pos": Game.player.global_position, "stop": s.follow}
	return {}


## Een tank blijft staan om te schieten zodra er een vijand binnen zijn bereik is (alleen bij AANVAL, VERDEDIG, BEWAAK en op weg naar de basis; bij VERPLAATS rijdt hij door).
func _siege_now() -> bool:
	if kind != "tank" or not (command in ["attack", "basis", "defend", "bewaak"]):
		return false
	if siege_point() != null:
		return true
	return threat_near(vehicle.global_position, float(KINDS.tank.range)) != null


# ---------------------------------------------------------------- rijden

## Elk beeld door het voertuig aangeroepen zolang `aktief()`. Zet `drive_dir` en `drive_speed`.
func think(delta: float) -> void:
	var s: Dictionary = KINDS[kind]
	drive_speed = 0.0
	siege = false
	waiting_bridge = false
	if _back_t > 0.0:
		_back_t -= delta
		var fwd0 := -vehicle.global_transform.basis.z
		drive_dir = (-fwd0).rotated(Vector3.UP, _back_dir * 0.5)
		drive_speed = 3.0
		return
	var goal := _goal()
	if goal.is_empty():
		_idle()
		return
	var gpos: Vector3 = goal.pos
	var stop: float = goal.stop
	if _siege_now():
		siege = true
		_idle(false)
		return
	if _flat(gpos) <= stop and command != "basis":
		_idle()
		return
	_replan_t -= delta
	if _plan.is_empty() or Vector2(gpos.x - _plan_goal.x, gpos.z - _plan_goal.z).length() > 5.0 or _replan_t <= 0.0:
		_make_plan(gpos)
	var wp: Variant = _next_wp(stop)
	if wp == null:
		_idle()
		if _plan_short and not _road_said and command in ["move", "attack"]:
			_road_said = true
			Game.banner.emit("TOT DE WEG", "%s rijdt niet verder dan de weg. Tik op de weg om verder te sturen." % naam(), 2.6)
		return
	arrived = false
	if _plan_cross >= 0 and _plan_i == _plan_cross and VoertuigRoute.bridge_up():
		waiting_bridge = true
		_idle(false)
		if not _bridge_said:
			_bridge_said = true
			Game.banner.emit("BRUG OMHOOG", "%s wacht voor de brug." % naam(), 2.4)
		return
	var target: Vector3 = wp
	if VoertuigRoute.side(vehicle.global_position) >= 0:
		var det: Variant = Kampmuur.vehicle_next(vehicle.global_position, target, float(s.half))   # rond de muren van jouw kamp, dwars door het midden van de poort
		if det != null:
			target = det
	var to := target - vehicle.global_position
	to.y = 0.0
	var fwd := -vehicle.global_transform.basis.z
	var alpha := atan2(fwd.cross(to).y, fwd.dot(to))
	if absf(alpha) > 2.3 and to.length() > 9.0:
		alpha = signf(alpha) * 1.9   # ligt het doel ver achter hem: een bocht maken, niet achteruit rijden
	alpha = clampf(alpha + _avoid(), -2.2, 2.2)
	_alpha = alpha
	var v := float(s.cruise) * clampf(1.0 - absf(alpha) / 1.6, 0.35, 1.0)
	if _plan_i >= _plan.size() - 1:
		v = minf(v, maxf(_flat(_plan.back()) * 0.7, 1.5))   # aan het einde rustig aankomen
	drive_dir = fwd.rotated(Vector3.UP, alpha)
	drive_speed = _spacing(v)
	_check_stuck(delta)


func _idle(done := true) -> void:
	if done:
		arrived = true
	drive_dir = Vector3.ZERO
	drive_speed = 0.0


func _make_plan(gpos: Vector3) -> void:
	var pl := VoertuigRoute.plan(vehicle.global_position, gpos, kind == "tank")
	var pts: Array = pl.pts
	if command == "basis":
		var tgt := VoertuigRoute.basis_points(kind == "tank")
		if pts.is_empty() or Vector2((pts.back() as Vector3).x - tgt.x, (pts.back() as Vector3).z - tgt.z).length() > 1.0:
			pts.append(tgt)   # door de poort van de vijandbasis (een tank tot vlak binnen de poort)
	_plan = pts
	_plan_i = 0
	_plan_goal = gpos
	_plan_cross = int(pl.cross)
	_plan_short = bool(pl.short) and command != "basis"
	_replan_t = 2.5


## Het volgende punt van het plan, of null als hij er is. Het laatste punt telt als bereikt binnen `stop` m.
func _next_wp(stop: float) -> Variant:
	var wp_r := float(KINDS[kind].wp)
	while _plan_i < _plan.size():
		var p: Vector3 = _plan[_plan_i]
		var last := _plan_i == _plan.size() - 1
		if _flat(p) < (minf(stop, wp_r) if last else wp_r):
			_plan_i += 1
			continue
		return p
	return null


## Drie voelsprieten vooruit evenwijdig aan zijn rijrichting (links, midden, rechts): muren, bunkers, hoge basismuren, poorten, rotsen en andere voertuigen. Voor een jeep tellen ook bomen en
## palmen mee (een zware boom houdt hem tegen); een tank rijdt bomen plat, dus voor hem tellen alleen de rotsen. Geeft een extra hoek (rad, + = naar links) die bij de hoek naar het doel
## wordt opgeteld.
func _avoid() -> float:
	var s: Dictionary = KINDS[kind]
	var space := vehicle.get_world_3d().direct_space_state
	var fwd := -vehicle.global_transform.basis.z
	var right := vehicle.global_transform.basis.x
	var wl := float(s.whisker)
	var base := vehicle.global_position + Vector3(0.0, 0.35, 0.0) + fwd * float(s.ahead)   # laag: ook een gevallen stam (0,6 m hoog) houdt een voertuig tegen
	var mask := Kit.LAYER_WALL | Kit.LAYER_BUNKER | Kit.LAYER_FORTIFICATION | 32 | Kit.LAYER_NATURE
	var d: Array[float] = [wl, wl, wl]   # links, midden, rechts
	var i := 0
	for off in [-float(s.side), 0.0, float(s.side)]:
		var from: Vector3 = base + right * off
		var q := PhysicsRayQueryParameters3D.create(from, from + fwd * wl, mask)
		q.hit_from_inside = true   # ook iets waar de neus al tegenaan zit (een rots naast de poort) telt: afstand 0
		var skip: Array[RID] = [vehicle.get_rid()]
		q.exclude = skip
		var h := space.intersect_ray(q)
		var guard := 0
		while kind == "tank" and not h.is_empty() and guard < 4 and (h.collider as Object).get_meta("vegetation_kind", "") == "palm":
			skip.append(h.rid)   # een tank rijdt door bomen en palmen (ze vallen om): alleen een rots houdt hem tegen
			q.exclude = skip
			h = space.intersect_ray(q)
			guard += 1
		if not h.is_empty():
			d[i] = (h.position - from).length()
		i += 1
	if d[0] >= wl and d[1] >= wl and d[2] >= wl:
		return 0.0
	var steer := -((1.0 - d[0] / wl) - (1.0 - d[2] / wl))   # hindernis links: naar rechts sturen (negatief)
	var pc: float = 1.0 - d[1] / wl
	if pc > 0.0 and absf(steer) < 0.25:
		steer += pc * (1.0 if d[0] > d[2] else -1.0)   # iets recht voor hem en aan beide kanten even ver: naar de vrijere kant
	return clampf(steer * 1.3, -1.3, 1.3)


## Konvooi (8A): een voertuig met hetzelfde bevel vlak voor hem houdt hem op afstand (6 m bij een jeep, 10 m bij een tank tussen de rompen).
func _spacing(v: float) -> float:
	var s: Dictionary = KINDS[kind]
	var fwd := -vehicle.global_transform.basis.z
	for o in all:
		if o == self or not is_instance_valid(o) or o.dead or not o.aktief() or o.arrived:
			continue
		if o.command != command or o.command_target.distance_to(command_target) > 12.0:
			continue
		var d: Vector3 = o.vehicle.global_position - vehicle.global_position
		d.y = 0.0
		var dist := d.length()
		if dist < 0.1 or fwd.dot(d) / dist < 0.6:
			continue
		var clear := dist - (float(s.len) + float(KINDS[o.kind].len)) * 0.5
		var gap := float(s.gap)
		if clear < gap * 0.5:
			return 0.0
		if clear < gap:
			v = minf(v, maxf(o.drive_speed, 1.0) * (clear / gap))
	return v


## Zit hij vast (hij wil rijden maar komt niet vooruit en draait ook niet), dan zet hij even achteruit; na een paar pogingen geeft hij het op en meldt het.
func _check_stuck(delta: float) -> void:
	_sample_t += delta
	if _sample_t < 0.8:
		return
	var moved := vehicle.global_position.distance_to(_sample_pos)
	var turned := absf(wrapf(vehicle.rotation.y - _sample_yaw, -PI, PI))
	_sample_pos = vehicle.global_position
	_sample_yaw = vehicle.rotation.y
	_sample_t = 0.0
	if drive_speed > 1.0 and moved < 0.35 and turned < 0.25:
		_stuck += 1
		if _stuck >= 2:
			_stuck = 0
			_tries += 1
			if _tries > MAX_TRIES:
				_give_up()
				return
			_back_t = RECOVER
			_back_dir = -signf(_alpha) if absf(_alpha) > 0.05 else (1.0 if randf() < 0.5 else -1.0)
	else:
		_stuck = 0
		if moved > 3.0:
			_tries = 0


func _give_up() -> void:
	vast = true
	arrived = true
	command = "hold"
	command_enemy = null
	command_hold_position = vehicle.global_position
	_plan.clear()
	drive_dir = Vector3.ZERO
	drive_speed = 0.0
	Game.banner.emit("%s VAST" % naam(), "Hij kan zijn weg niet vinden. Geef een nieuw bevel.", 2.6)
