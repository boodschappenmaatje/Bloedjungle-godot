class_name HqPerks
extends Node
## Voordelen van het hoofdkwartier per niveau (Generals-plan stap 3). Hangt als kind aan het hoofdkwartier (hoofdkwartier.gd).
##  Niveau 2: radar. Alle vijanden binnen RADAR_RANGE m van het hoofdkwartier staan als stip op de radar (hud_extra.gd) en
##            een nieuwe groep meldt zich met een waarschuwing; bouw- en opleidingstijden zijn 25% korter (Buildings.time_factor).
##  Niveau 3: automatisch dakgeweer (HqRoofGun, in 10 s zichtbaar gebouwd) en het artilleriecommando (Artillerie, 90 s afkoeling).

const RADAR_RANGE := 85.0       # m rond het hoofdkwartier (wereldnulpunt)
const ALERT_PAUSE := 14.0       # s tussen twee radarwaarschuwingen
const ALERT_SCAN := 0.3         # s tussen twee scans
const DIRS := ["NOORDEN", "NOORDOOSTEN", "OOSTEN", "ZUIDOOSTEN", "ZUIDEN", "ZUIDWESTEN", "WESTEN", "NOORDWESTEN"]

var gun: HqRoofGun
var alerts := 0                 # aantal waarschuwingen sinds het begin (voor de test)
var _known := {}                # instance-id -> true: al gemeld
var _scan_t := 0.0
var _alert_cd := 0.0
var _gun_seen := false          # het dakgeweer is al gebouwd of wordt gebouwd in dit spel
var _first := true


## Windrichting (NOORDEN ... NOORDWESTEN) van een punt gezien vanaf het hoofdkwartier. Noord = -Z (zoals op de radar).
static func compass(p: Vector3) -> String:
	var a := atan2(p.x, -p.z)              # 0 = noord, kloksgewijs
	var i := int(roundf(a / (PI / 4.0))) % 8
	if i < 0:
		i += 8
	return DIRS[i]


## Vijanden binnen radarbereik van het hoofdkwartier.
static func contacts() -> Array:
	var out := []
	for e in Game.enemies:
		if is_instance_valid(e) and e.get("dead") != true and Vector2(e.global_position.x, e.global_position.z).length() <= RADAR_RANGE:
			out.append(e)
	return out


func _process(delta: float) -> void:
	if Game.artillery_cd > 0.0 and (Game.state == "play" or Game.state == "prep"):
		Game.artillery_cd = maxf(0.0, Game.artillery_cd - delta)
	_roof_gun()
	_alert_cd -= delta
	_scan_t -= delta
	if _scan_t > 0.0:
		return
	_scan_t = ALERT_SCAN
	_radar_scan()


## Niveau 3 bereikt: dakgeweer neerzetten (met bouwanimatie als je het zojuist kocht). Nieuw spel (niveau 1): weg.
func _roof_gun() -> void:
	if Game.hq_level >= 3:
		if gun == null or not is_instance_valid(gun):
			gun = HqRoofGun.new()
			get_parent().add_child(gun)
			gun.start(_gun_seen or not _first)     # eerste keer na de upgrade: opbouwen
			_gun_seen = true
	elif gun != null and is_instance_valid(gun):
		gun.queue_free()
		gun = null
		_gun_seen = false
	_first = false


func _radar_scan() -> void:
	if Game.hq_level < 2:
		_known.clear()
		return
	var now := contacts()
	var fresh := []
	var alive := {}
	for e in now:
		var id: int = e.get_instance_id()
		alive[id] = true
		if not _known.has(id):
			fresh.append(e)
	for id in _known.keys():
		if not alive.has(id):
			_known.erase(id)
	if fresh.is_empty():
		return
	for e in fresh:
		_known[e.get_instance_id()] = true
	if Game.state != "play" or _alert_cd > 0.0:
		return
	_alert_cd = ALERT_PAUSE
	alerts += 1
	var mid := Vector3.ZERO
	for e in fresh:
		mid += Vector3(e.global_position.x, 0.0, e.global_position.z)
	mid /= float(fresh.size())
	var dist := roundi(Vector2(mid.x, mid.z).length())
	Game.banner.emit("RADAR: VIJAND NADERT", "%d contacten uit het %s · %d m" % [fresh.size(), compass(mid).to_lower(), dist], 2.4)
	Sfx.play("ping", 1.0)
	get_tree().create_timer(0.22).timeout.connect(func(): Sfx.play("ping", 1.25))
