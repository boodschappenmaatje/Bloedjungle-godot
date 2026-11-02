class_name VoorraadModellen
extends RefCounted
## Gedeelde hulp voor de modellen van stap 4b (voorraaddepot, voorraadtruck, voorraadstapel; bron/voorraad/): laadt een GLB, zet de
## zichtbaarheidsbereiken voor LOD en past de materialen aan die Godot niet zelf goed uit de glTF haalt: camonet en stencil met alfa-scissor,
## lampen die 's nachts gloeien.

const NIGHT_LAMP := {"VR_Lamp_amber": 3.0, "VR_Lamp_wit": 2.6, "VR_Lamp_rood": 3.2}
const DAY_LAMP := {"VR_Lamp_amber": 0.35, "VR_Lamp_wit": 0.3, "VR_Lamp_rood": 0.5}


## Laadt `path` onder `parent`. range_begin/range_end zijn de zichtbaarheidsafstanden (0 = geen grens), zoals bij het hoofdkwartier.
static func laad(path: String, parent: Node, range_begin := 0.0, range_end := 0.0) -> Node:
	var m: Node
	if ResourceLoader.exists(path):
		m = (load(path) as PackedScene).instantiate()
	else:
		push_warning("model ontbreekt: " + path)
		m = Node3D.new()
	parent.add_child(m)
	var night: bool = GameSettings.get_value("time") != "day"
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		g.visibility_range_begin = range_begin
		g.visibility_range_end = range_end
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if g.mesh == null:
			continue
		for s in g.mesh.get_surface_count():
			var mat := g.get_active_material(s)
			if not (mat is StandardMaterial3D):
				continue
			var sm := mat as StandardMaterial3D
			match sm.resource_name:
				"VR_Camonet":
					var net := sm.duplicate() as StandardMaterial3D
					net.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					net.alpha_scissor_threshold = 0.5
					net.cull_mode = BaseMaterial3D.CULL_DISABLED
					g.set_surface_override_material(s, net)
				"VR_Stencil":
					var st := sm.duplicate() as StandardMaterial3D
					st.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					st.alpha_scissor_threshold = 0.5
					g.set_surface_override_material(s, st)
					g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				"VR_Glas":
					g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				"VR_Lamp_amber", "VR_Lamp_wit", "VR_Lamp_rood":
					var lamp := sm.duplicate() as StandardMaterial3D
					lamp.emission_enabled = true
					lamp.emission_energy_multiplier = (NIGHT_LAMP if night else DAY_LAMP)[sm.resource_name]
					g.set_surface_override_material(s, lamp)
					g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


## Een eigen AnimationPlayer voor één clip van `ap` (één speler speelt maar één clip tegelijk). De speler staat op pauze.
static func eigen_speler(m: Node, ap: AnimationPlayer, clip: String, pname: String) -> AnimationPlayer:
	if ap == null or not ap.has_animation(clip):
		return null
	var p2 := AnimationPlayer.new()
	p2.name = pname
	m.add_child(p2)
	p2.root_node = ap.root_node
	var lib := AnimationLibrary.new()
	lib.add_animation(clip, ap.get_animation(clip))
	p2.add_animation_library("", lib)
	return p2
