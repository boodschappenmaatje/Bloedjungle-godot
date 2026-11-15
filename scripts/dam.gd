class_name Dam
extends Node3D
## Betonnen gewichtsdam in de kloof boven de vijandbasis (dambreuk stap 2). Model: assets/dam.glb (bron/dam/maak_dam.py),
## 60 m breed, 14 m hoog, drie stalen sluisdeuren. De foto-PBR-maps (4K) hangen we hier aan de materialen, zoals de viewer.
## Stap 2 laat de dam alleen staan; de clips Kraken en Breken (AnimationPlayer) zijn klaar voor stap 3 (breuk en vloed).
## Standaard tekent het spel één samengevoegd net (6 tekenopdrachten, geen schaduw); de losse stukken (blokken, poorten,
## pijlers, brug, scheuren, lekstralen) zijn dan verborgen en komen pas in beeld zodra kraken() of breken() start.

const MODEL := "res://assets/dam.glb"
const TEX := "res://assets/textures/dam/"

var model: Node3D
var player: AnimationPlayer
var intact: MeshInstance3D
var _mats := {}


static func build(parent: Node3D) -> Dam:
	var d := Dam.new()
	d.name = "Dam"
	d.position = Vector3(Bergland.gorge_x(Bergland.DAM_Z), Bergland.DAM_FLOOR, Bergland.DAM_Z)
	parent.add_child(d)
	return d


func _ready() -> void:
	var ps := load(MODEL) as PackedScene
	if ps == null:
		push_warning("Dam: model ontbreekt")
		return
	model = ps.instantiate()
	add_child(model)
	_apply_materials(model)
	player = _find_player(model)
	_merge_intact()
	_set_pieces_visible(false)


## Kleinste dam-eis voor tests: namen van de stukken die de breuk gebruikt.
func piece_names() -> PackedStringArray:
	var out := PackedStringArray()
	for n in _meshes(model):
		out.append(n.name)
	return out


func kraken() -> void:
	_start("Kraken")


func breken() -> void:
	_start("Breken")


func _start(clip: String) -> void:
	_set_pieces_visible(true)
	if player and player.has_animation(clip):
		player.play(clip)


func reset() -> void:
	if player:
		player.stop()
	_set_pieces_visible(false)


func _set_pieces_visible(v: bool) -> void:
	if model:
		model.visible = v
	if intact:
		intact.visible = not v


func _find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_player(c)
		if r:
			return r
	return null


func _meshes(n: Node) -> Array:
	var out := []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out


# ---------------------------------------------------------------- materialen

func _tex(name: String) -> Texture2D:
	return load(TEX + name) as Texture2D


func _make(name: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = name
	m.vertex_color_use_as_albedo = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	match name:
		"DAM_Beton", "DAM_Staal":
			var k := "beton" if name == "DAM_Beton" else "staal"
			m.albedo_texture = _tex(k + "_albedo.jpg")
			m.normal_enabled = true
			m.normal_texture = _tex(k + "_normal.jpg")
			var orm := _tex(k + "_orm.jpg")
			m.ao_enabled = true
			m.ao_texture = orm
			m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			m.roughness_texture = orm
			m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
			m.metallic_texture = orm
			m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
			m.metallic = 1.0 if name == "DAM_Staal" else 0.0
			m.roughness = 1.0
		"DAM_Steen":   # stortsteen: het betonbeeld, donkerder (geen extra 4K-set in het geheugen)
			m.albedo_texture = _tex("beton_albedo.jpg")
			m.albedo_color = Color(0.62, 0.6, 0.55)
			m.roughness = 0.95
		"DAM_Water":
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.vertex_color_use_as_albedo = false
			m.albedo_color = Color(0.82, 0.9, 0.94, 0.55)
			m.roughness = 0.1
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"DAM_Lamp":
			m.vertex_color_use_as_albedo = false
			m.albedo_color = Color(1.0, 0.85, 0.5)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.82, 0.45)
			m.emission_energy_multiplier = 1.6
		"DAM_Glas":
			m.vertex_color_use_as_albedo = false
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = Color(0.18, 0.26, 0.30, 0.6)
			m.roughness = 0.1
		_:   # DAM_Kraak: donker
			m.vertex_color_use_as_albedo = false
			m.albedo_color = Color(0.05, 0.05, 0.05)
			m.roughness = 1.0
	return m


func _mat(name: String) -> StandardMaterial3D:
	if not _mats.has(name):
		_mats[name] = _make(name)
	return _mats[name]


func _apply_materials(root: Node) -> void:
	for mi in _meshes(root):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var old := mesh.surface_get_material(s)
			var nm: String = old.resource_name if old else ""
			if nm.begins_with("DAM_"):
				mesh.surface_set_material(s, _mat(nm))


## Alle stukken samen in één net per materiaal (in rustpose): ongeveer zes tekenopdrachten voor de hele dam.
func _merge_intact() -> void:
	var sts := {}
	for mi in _meshes(model):
		if String(mi.name).begins_with("Kraak_") or String(mi.name).begins_with("Lek_"):
			continue
		var xf := _rel_xform(mi)
		var mesh: Mesh = mi.mesh
		for s in mesh.get_surface_count():
			var mat := mesh.surface_get_material(s)
			var key: String = mat.resource_name if mat else "x"
			if not sts.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				sts[key] = st
			(sts[key] as SurfaceTool).append_from(mesh, s, xf)
	var am := ArrayMesh.new()
	for key in sts:
		var st: SurfaceTool = sts[key]
		st.commit(am)
		am.surface_set_material(am.get_surface_count() - 1, _mat(key))
	intact = MeshInstance3D.new()
	intact.name = "Intact"
	intact.mesh = am
	intact.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	intact.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(intact)


func _rel_xform(n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != self:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf
