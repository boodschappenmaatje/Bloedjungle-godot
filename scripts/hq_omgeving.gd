class_name HqOmgeving
extends Node3D
## Voorplein van het hoofdkwartier (Generals-plan stap 3): betonnen platen met belijning en HQ-stencil, twee lichtmasten, afzetblokken,
## vaten in een opvangbak, een pallet met munitiekisten en een kabelhaspel. Model: assets/hoofdkwartier_omgeving.glb
## (Blender-bron: bron/hoofdkwartier/maak_omgeving.py). Zelfde coordinaten als het script: Godot x = Blender x, Godot z = -Blender y.
## Godot doet: botsblokken (laag muur, dus kogels en mensen stoppen erop en er kan niet op gebouwd worden), de lampen van de
## masten (glans en echt licht bij Avond/Nacht).

const MODEL := "res://assets/hoofdkwartier_omgeving.glb"
const MAST_H := 5.9
const MASTS := [Vector2(-4.9, 6.0), Vector2(4.9, 6.0)]             # (x, z)
const FAR := 140.0
const SLAB_TINT := Color(0.80, 0.83, 0.86)

## [midden x, midden z, breedte x, hoogte, diepte z]
const BLOCKS := [
	[-4.6, 7.0, 1.5, 0.8, 0.55], [-3.0, 7.0, 1.5, 0.8, 0.55], [3.0, 7.0, 1.5, 0.8, 0.55], [4.6, 7.0, 1.5, 0.8, 0.55],   # afzetblokken
	[-1.95, 7.0, 0.22, 0.95, 0.22], [1.95, 7.0, 0.22, 0.95, 0.22],                                                     # paaltjes
	[-4.05, 3.6, 1.9, 0.95, 1.15],                                                                                      # vaten
	[4.1, 4.3, 1.25, 0.65, 0.95],                                                                                       # pallet met kisten
	[4.75, 0.9, 0.95, 0.9, 0.5],                                                                                        # kabelhaspel
	[-4.9, 6.0, 0.22, MAST_H, 0.22], [4.9, 6.0, 0.22, MAST_H, 0.22],                                                    # lichtmasten
]

var _amber: Array[StandardMaterial3D] = []
var _lights: Array[OmniLight3D] = []
var _night := false
var _check := 0.0


func _ready() -> void:
	name = "Voorplein"
	add_to_group("hq_omgeving")
	var model: Node = (load(MODEL) as PackedScene).instantiate()
	add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		g.visibility_range_end = FAR
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var mat := g.get_active_material(0)
		if mat is StandardMaterial3D and String(g.name) == "Voorplein":
			# de platen zijn in de atlas iets te beige uitgevallen (warme zon): koeler en een tikje donkerder, zodat het beton grijs leest
			var slab := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			slab.albedo_color = SLAB_TINT
			g.material_override = slab
		if mat is StandardMaterial3D and (mat as StandardMaterial3D).resource_name == "HK_Lamp_amber":
			var a := (mat as StandardMaterial3D).duplicate() as StandardMaterial3D
			a.emission_enabled = true
			g.material_override = a
			_amber.append(a)
	for b in BLOCKS:
		Kit.collider(self, Vector3(b[0], b[3] * 0.5, b[1]), Vector3(b[2], b[3], b[4]), Kit.LAYER_WALL)
	for i in MASTS.size():
		var m: Vector2 = MASTS[i]
		var toward := Vector3(-m.x, 0.0, -m.y).normalized()
		var lamp := OmniLight3D.new()
		lamp.name = "Mastlicht%d" % (i + 1)
		lamp.position = Vector3(m.x, MAST_H - 0.3, m.y) + toward * 0.6
		lamp.omni_range = 17.0
		lamp.light_energy = 2.2
		lamp.light_color = Color(1.0, 0.82, 0.56)
		lamp.shadow_enabled = false
		lamp.visible = false
		add_child(lamp)
		_lights.append(lamp)
	_refresh()


func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = 0.5
		_refresh()


func _refresh() -> void:
	_night = GameSettings.get_value("time") != "day"
	for a in _amber:
		a.emission_energy_multiplier = 3.2 if _night else 0.3
	for l in _lights:
		l.visible = _night
