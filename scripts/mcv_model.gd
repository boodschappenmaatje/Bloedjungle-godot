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


func set_schild_omhoog(up: bool) -> void:
	if _schild != null:
		_schild.rotation.x = SCHILD_OMHOOG if up else 0.0


func play_uitklappen() -> void:
	if _anim != null and _anim.has_animation("Uitklappen"):
		_anim.play("Uitklappen")


func uitklappen_klaar() -> bool:
	return _anim == null or not _anim.is_playing()


## Zet de clip op een tijdstip (test en viewer); ingeklapt = 0, uitgeklapt = 6.
func seek_uitklappen(t: float) -> void:
	if _anim != null and _anim.has_animation("Uitklappen"):
		_anim.play("Uitklappen")
		_anim.seek(t, true)
		_anim.pause()
