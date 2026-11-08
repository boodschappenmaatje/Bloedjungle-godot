class_name McvModel
extends Node3D
## De bouwwagen (MCV) uit Dennis' Meshy-modellen (assets/mcv.glb, bron/mcv_meshy/): 8x8-wagen met dozerschild, de module op de laadbak
## (container, dakpanelen, mast, schotel) en vier steunpoten. Godot draait de wielen (8) en stuurt de voorwielen (4) en laat de wagen op de
## weg wiebelen; de clip "Uitklappen" (6 s) zet de poten neer, schuift de dakpanelen uit, laat de mast rijzen en klapt de schotel omhoog.
## Voorkant is -Z. Eindpose van de clip = uitgeklapt.

const MODEL := "res://assets/mcv.glb"
const WHEEL_R := 0.55
const MAX_STEER := 0.5          # rad
const SCHILD_OMHOOG := 0.56     # rad (32 graden): het schild zoals na het uitklappen

var _wheels: Array[Node3D] = []
var _steer: Array[Node3D] = []
var _schild: Node3D
var _romp: Node3D
var _anim: AnimationPlayer
var _roll := 0.0
var _bob := 0.0
var _steer_now := 0.0
var _daken: Array = []          # [{node, pivot, sign}]: de dakpanelen klappen om een scharnier open (Godot stuurt ze, de clip doet de rest)
var _poten: Array[Node3D] = []
var _gespeeld := false
var _t_vorig := 0.0
var _jolt := 0.0
var _baken: MeshInstance3D
var _baken_licht: OmniLight3D
var _baken_mat: StandardMaterial3D
var _baken_modus := 0           # 0 uit, 1 knipperend oranje (bezig), 2 groen (klaar)
var _baken_t := 0.0
var _module: Node3D             # de container: komt los van de wagen (top_level) en blijft op de bouwplek staan
var _anker := Transform3D.IDENTITY
var _los := false
var _lift := 0.0                # m: hoogte van de container boven de laadbak (negatief = op de grond)
const BAK_HOOGTE := 1.41        # m: de container staat op de laadbak; zo ver zakt hij naar de grond

const T_POTEN := 1.97           # s in de clip: de poten staan op de grond
const T_DAK0 := 1.83
const T_DAK1 := 4.17            # de dakpanelen zijn open
const T_MAST := 3.63
const T_SCHOTEL := 4.93


func _ready() -> void:
	name = "Model"
	var m: Node = (load(MODEL) as PackedScene).instantiate()
	add_child(m)
	_anim = m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_romp = m.find_child("Romp", true, false) as Node3D
	_schild = m.find_child("Schild", true, false) as Node3D
	for n in m.find_children("Wiel_*", "Node3D", true, false):
		_wheels.append(n as Node3D)
	for n in m.find_children("Stuur_*", "Node3D", true, false):
		_steer.append(n as Node3D)
	for n in m.find_children("Poot_*", "Node3D", false, false):
		_poten.append(n as Node3D)
	_module = m.find_child("Module", true, false) as Node3D
	_maak_daken(m)
	_maak_baken(m)
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		var n := String(g.name)
		# schaduw alleen van de grote delen (de iPhone moet dit blijven halen)
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (n == "Romp" or n == "Kern" or n == "Schild") else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Wielen en sturen volgens de snelheid (m/s, + = vooruit) en een stuurwens in rad (+ = naar links).
func drive(speed: float, steer: float, delta: float) -> void:
	_roll += speed * delta / WHEEL_R
	for w in _wheels:
		w.rotation.x = -_roll
	_steer_now = move_toward(_steer_now, clampf(steer, -MAX_STEER, MAX_STEER), 1.6 * delta)
	for s in _steer:
		var factor := 1.0 if String(s.name).begins_with("Stuur_A1") else 0.65
		s.rotation.y = _steer_now * factor
	# de wagen wiebelt op de ongelijke grond: op snelheid een tikje op en neer en heen en weer
	var k := clampf(absf(speed) / 7.0, 0.0, 1.0)
	_bob += (absf(speed) * 1.7 + 1.0) * delta
	if _romp != null:
		position.y = sin(_bob * 2.3) * 0.018 * k
		rotation.z = sin(_bob * 1.7 + 1.3) * 0.012 * k
		rotation.x = sin(_bob * 1.1) * 0.008 * k


## De container komt los van de wagen: hij blijft op zijn plek in de wereld, de wagen kan eronderuit rijden.
func los_container() -> void:
	if _module == null or _los:
		return
	_anker = _module.global_transform
	_module.top_level = true
	_los = true
	_module.global_transform = _anker


## Hoogte van de container boven de laadbak (m); BAK_HOOGTE-negatief = op de grond.
func zet_lift(y: float) -> void:
	_lift = y
	if _los and _module != null:
		_module.global_transform = Transform3D(_anker.basis, _anker.origin + Vector3(0.0, y, 0.0))


func container_pos() -> Vector3:
	return _module.global_position if _module != null else global_position


func container_los() -> bool:
	return _los


func container_weg() -> void:
	if _module != null and is_instance_valid(_module):
		_module.visible = false


func set_schild_omhoog(up: bool) -> void:
	if _schild != null:
		_schild.rotation.x = SCHILD_OMHOOG if up else 0.0


func play_uitklappen() -> void:
	if _anim != null and _anim.has_animation("Uitklappen"):
		_gespeeld = true
		_t_vorig = 0.0
		set_baken(1)
		_anim.play("Uitklappen")


func uitklappen_klaar() -> bool:
	return _anim == null or not _anim.is_playing()


## Zet de clip op een tijdstip (test en viewer); ingeklapt = 0, uitgeklapt = 6.
func seek_uitklappen(t: float) -> void:
	if _anim != null and _anim.has_animation("Uitklappen"):
		_gespeeld = true
		_anim.play("Uitklappen")
		_anim.seek(t, true)
		_anim.pause()


## De clip schuift de dakpanelen zijwaarts uit; hier worden die sporen vervangen door een draai om de buitenrand (een kwartslag-scharnier van
## 180 graden): het paneel klapt over de rand van de container en hangt als luifel langs de zijkant.
func _maak_daken(m: Node) -> void:
	if _anim == null or not _anim.has_animation("Uitklappen"):
		return
	var lib := _anim.get_animation_library(_anim.find_animation_library(_anim.get_animation("Uitklappen")))
	var a: Animation = _anim.get_animation("Uitklappen").duplicate()
	for i in range(a.get_track_count() - 1, -1, -1):
		var path := str(a.track_get_path(i))
		if path.ends_with("Dak_L") or path.ends_with("Dak_R"):
			a.remove_track(i)
	lib.remove_animation("Uitklappen")
	lib.add_animation("Uitklappen", a)
	for nm in ["Dak_L", "Dak_R"]:
		var d := m.find_child(nm, true, false) as Node3D
		if d == null:
			continue
		var bb := AABB()
		var eerste := true
		for mi in d.find_children("*", "MeshInstance3D", true, false):
			var g := mi as MeshInstance3D
			var box: AABB = g.transform * g.get_aabb() if g.get_parent() == d else g.get_aabb()
			bb = box if eerste else bb.merge(box)
			eerste = false
		if d is MeshInstance3D:
			bb = (d as MeshInstance3D).get_aabb()
		var uit := 1.0 if nm == "Dak_L" else -1.0   # richting waarin het paneel uitschoof
		var pivot := Vector3(bb.end.x if uit > 0.0 else bb.position.x, bb.position.y, 0.0)
		_daken.append({"node": d, "pivot": pivot, "sign": uit})


func _maak_baken(m: Node) -> void:
	var module := m.find_child("Module", true, false) as Node3D
	if module == null:
		return
	_baken = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.14
	sm.height = 0.28
	_baken_mat = StandardMaterial3D.new()
	_baken_mat.albedo_color = Color(1.0, 0.55, 0.1)
	_baken_mat.emission_enabled = true
	_baken_mat.emission = Color(1.0, 0.55, 0.1)
	_baken_mat.emission_energy_multiplier = 0.0
	sm.material = _baken_mat
	_baken.mesh = sm
	_baken.position = Vector3(0.0, 2.42, 1.45)
	_baken.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	module.add_child(_baken)
	# een dun paaltje onder het baken: het staat op het dak van de container en blijft staan als de panelen open klappen
	var paal := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.025
	cm.bottom_radius = 0.025
	cm.height = 0.9
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.12, 0.13, 0.12)
	cm.material = pm
	paal.mesh = cm
	paal.position = Vector3(0.0, 1.95, 1.45)
	paal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	module.add_child(paal)
	_baken_licht = OmniLight3D.new()
	_baken_licht.omni_range = 7.0
	_baken_licht.light_energy = 0.0
	_baken_licht.light_color = Color(1.0, 0.6, 0.2)
	_baken_licht.shadow_enabled = false
	_baken.add_child(_baken_licht)


## 0 = uit, 1 = knipperend oranje (de wagen en de bouw zijn bezig), 2 = groen (hoofdkwartier klaar).
func set_baken(modus: int) -> void:
	_baken_modus = modus
	if modus == 2 and _baken_mat != null:
		_baken_mat.albedo_color = Color(0.2, 1.0, 0.35)
		_baken_mat.emission = Color(0.2, 1.0, 0.35)
		_baken_licht.light_color = Color(0.3, 1.0, 0.4)
	elif modus == 1 and _baken_mat != null:
		_baken_mat.albedo_color = Color(1.0, 0.55, 0.1)
		_baken_mat.emission = Color(1.0, 0.55, 0.1)
		_baken_licht.light_color = Color(1.0, 0.6, 0.2)


func _clip_tijd() -> float:
	if _anim == null or not _gespeeld:
		return 0.0
	if _anim.assigned_animation == "Uitklappen":
		return clampf(_anim.current_animation_position, 0.0, 6.0)
	return 6.0


func _process(delta: float) -> void:
	_baken_t += delta
	if _baken_mat != null:
		var aan := 0.0
		if _baken_modus == 1:
			aan = 1.0 if fmod(_baken_t, 0.9) < 0.45 else 0.0
		elif _baken_modus == 2:
			aan = 1.0
		_baken_mat.emission_energy_multiplier = 3.0 * aan
		_baken_licht.light_energy = 1.6 * aan
	if not _gespeeld:
		return
	var t := _clip_tijd()
	# dakpanelen: kwartslag-scharnier (met een tikje terugveren aan het eind)
	var v := clampf((t - T_DAK0) / (T_DAK1 - T_DAK0), 0.0, 1.0)
	var u := v * v * (3.0 - 2.0 * v)
	for d in _daken:
		var hoek: float = -float(d.sign) * PI * u
		var b := Basis(Vector3.BACK, hoek)
		(d.node as Node3D).transform = Transform3D(b, (d.pivot as Vector3) - b * (d.pivot as Vector3))
	# de wagen zakt een tikje als de poten de grond raken en veert terug
	_jolt = move_toward(_jolt, 0.0, delta * 2.5)
	if _anim.is_playing() or t >= 6.0:
		position.y = -0.045 * sin(_jolt * PI)
	_gebeurtenissen(_t_vorig, t)
	_t_vorig = t


func _kruist(a: float, b: float, t: float) -> bool:
	return a < t and b >= t


func _gebeurtenissen(a: float, b: float) -> void:
	if b <= a:
		return
	var host: Node = get_parent()
	if _kruist(a, b, 0.25):
		Sfx.play("spuit", 0.9)   # hydrauliek: het schild gaat omhoog
	if _kruist(a, b, 0.45):
		Sfx.play("gate", 0.8)    # de poten zakken
	if _kruist(a, b, T_POTEN):
		Sfx.play("thud", 1.0)
		Sfx.play("boom", 0.25)
		_jolt = 1.0
		for p in _poten:
			var at := p.global_position
			McvFx.puff(host, Vector3(at.x, global_position.y + 0.15, at.z), 1.1, Color(0.6, 0.53, 0.42), 9, 1.0)
	if _kruist(a, b, T_DAK0):
		Sfx.play("gate", 0.9)    # de dakpanelen klappen open
	if _kruist(a, b, T_DAK1):
		Sfx.play("thud", 0.8)
		Sfx.play("click", 1.0)
		McvFx.puff(host, container_pos() + Vector3(0.0, 1.6, 0.0), 0.8, Color(0.7, 0.66, 0.58), 6, 0.6)
	if _kruist(a, b, T_MAST):
		Sfx.play("wuuf", 0.5)    # de mast rijst
	if _kruist(a, b, T_SCHOTEL):
		Sfx.play("ping", 1.0)    # de schotel heeft zijn richting
