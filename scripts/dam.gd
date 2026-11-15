class_name Dam
extends Node3D
## Betonnen gewichtsdam in de kloof boven de vijandbasis (dambreuk stap 2). Model: assets/dam.glb (bron/dam/maak_dam.py),
## 60 m breed, 14 m hoog, drie stalen sluisdeuren. De foto-PBR-maps (4K) hangen we hier aan de materialen, zoals de viewer.
## Stap 2 laat de dam alleen staan; de clips Kraken en Breken (AnimationPlayer) zijn klaar voor stap 3 (breuk en vloed).
## Standaard tekent het spel één samengevoegd net (6 tekenopdrachten, geen schaduw); de losse stukken (blokken, poorten,
## pijlers, brug, scheuren, lekstralen) zijn dan verborgen en komen pas in beeld zodra kraken() of breken() start.

const MODEL := "res://assets/dam.glb"
const TEX := "res://assets/textures/dam/"

const GATE_HP := 900.0         # levenspunten per sluisdeur (dambreuk stap 3a, keuze 4A: twee van de drie kapot)
const GATE_MULT := 3.0         # zwaar spul doet zo veel keer zijn schade tegen een deur (zoals tegen een gebouw)
const C4_DMG := 2400.0         # een springlading op een deur
const C4_RADIUS := 7.0
const C4_FUSE := 5.0           # s afteltijd na ontsteken
const KRAAK_TIJD := 5.0        # s kraken voor de dam breekt (clip Kraken)

static var current: Dam

var model: Node3D
var player: AnimationPlayer
var intact: MeshInstance3D
var _mats := {}
var gate_hp: Array[float] = [GATE_HP, GATE_HP, GATE_HP]
var gate_c4: Array[bool] = [false, false, false]    # er zit een lading op de deur
var gate_dead: Array[bool] = [false, false, false]
var breaching := false
var broken := false
var _fuse := -1.0


static func build(parent: Node3D) -> Dam:
	var d := Dam.new()
	d.name = "Dam"
	d.position = Vector3(Bergland.gorge_x(Bergland.DAM_Z), Bergland.DAM_FLOOR, Bergland.DAM_Z)
	parent.add_child(d)
	current = d
	return d


func _exit_tree() -> void:
	if current == self:
		current = null


# Game en Sfx zijn autoloads; zo blijft dit script ook zonder die autoloads te laden (tests en Bergland).
static func _auto(n: String) -> Node:
	var ml := Engine.get_main_loop() as SceneTree
	return ml.root.get_node_or_null(n) if ml != null else null


static func _sfx(name: String, vol := 1.0, pos = null) -> void:
	var s := _auto("Sfx")
	if s != null:
		if pos == null:
			s.call("play", name, vol)
		else:
			s.call("play", name, vol, pos)


static func _banner(big: String, small: String, t: float) -> void:
	var g := _auto("Game")
	if g != null:
		g.emit_signal("banner", big, small, t)


## Zwaar spul (tankgranaat, raket, artillerie, luchtaanval): elke ontploffing in de buurt van de dam gaat hierheen.
static func blast_alle(at: Vector3, radius: float, dmg: float) -> void:
	if current != null and is_instance_valid(current):
		current.blast(at, radius, dmg)


## Schade aan de sluisdeuren: horizontaal gemeten tot het gebied van de deur (x +-4 m, van de loopbrug tot de voet van de achterkant), kogels doen niets.
func blast(at: Vector3, radius: float, dmg: float, mult := GATE_MULT) -> void:
	if breaching or broken:
		return
	for i in 3:
		if gate_dead[i]:
			continue
		var g := DamPad.gate_pos(i)
		var dx := maxf(absf(at.x - g.x) - 4.0, 0.0)
		var dz := 0.0
		if at.z > g.z + 11.5:
			dz = at.z - (g.z + 11.5)
		elif at.z < g.z - 2.0:
			dz = (g.z - 2.0) - at.z
		var d := sqrt(dx * dx + dz * dz)
		if d >= radius:
			continue
		gate_hp[i] -= dmg * mult * (1.0 - d / radius)
		if gate_hp[i] <= 0.0:
			_gate_down(i)


func gates_dead() -> int:
	var n := 0
	for b in gate_dead:
		if b:
			n += 1
	return n


func _gate_down(i: int) -> void:
	gate_dead[i] = true
	gate_hp[i] = 0.0
	var p := DamPad.gate_pos(i)
	(load("res://scripts/fx.gd") as GDScript).call("explosion", get_parent(), p, 1.8)
	_sfx("rocket", 1.0, p)
	var n := gates_dead()
	if n >= 2:
		_breach()
	else:
		_banner("SLUISDEUR KAPOT", "Nog %d deur(en) en de dam breekt" % (2 - n), 3.0)


func _breach() -> void:
	if breaching or broken:
		return
	breaching = true
	_banner("DE DAM KRAAKT!", "Wegwezen: over 5 seconden breekt hij", 4.0)
	_sfx("alarm", 1.0)
	kraken()
	await get_tree().create_timer(KRAAK_TIJD).timeout
	if not is_inside_tree():
		return
	broken = true
	breken()


## C4: plakken op de deur bij jou in de buurt (binnen 5 m horizontaal). Geeft de index van de deur of -1.
func nearest_gate(pos: Vector3) -> int:
	var best := -1
	var bd := 6.0
	for i in 3:
		if gate_dead[i]:
			continue
		var g := DamPad.gate_pos(i)
		var d := Vector2(pos.x - g.x, pos.z - g.z).length()
		if d < bd and pos.y > Bergland.DAM_FLOOR + 10.0:   # je moet op de kroon of de loopbrug staan
			bd = d
			best = i
	return best


func plant_c4(i: int) -> bool:
	if i < 0 or gate_c4[i] or gate_dead[i]:
		return false
	gate_c4[i] = true
	var p := DamPad.gate_pos(i) + Vector3(0.0, -3.0, -0.2)
	var lamp := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.35, 0.5)
	lamp.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.42, 0.3)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.1, 0.05)
	m.emission_energy_multiplier = 2.0
	lamp.material_override = m
	lamp.name = "C4_%d" % i
	get_parent().add_child(lamp)
	lamp.global_position = p
	lamp.add_to_group("dam_c4")
	var g := _auto("Game")
	if g != null:
		g.call("alert", p, 45.0, 6.0)   # de wachters horen het plakken (keuze 6A: alarm)
	return true


func c4_geplakt() -> int:
	var n := 0
	for i in 3:
		if gate_c4[i] and not gate_dead[i]:
			n += 1
	return n


## Ontsteekt alle ladingen na 5 s. Returns false als er niets zit.
func ontsteek_c4() -> bool:
	if c4_geplakt() == 0 or _fuse >= 0.0:
		return false
	_fuse = C4_FUSE
	_banner("C4 ONTSTOKEN", "Over %d seconden gaat hij af" % roundi(C4_FUSE), 2.5)
	return true


func _process(delta: float) -> void:
	if _fuse < 0.0:
		return
	var before := ceili(_fuse)
	_fuse -= delta
	if ceili(_fuse) != before and _fuse > 0.0:
		_sfx("ping", 1.2)
	if _fuse <= 0.0:
		_fuse = -1.0
		for i in 3:
			if gate_c4[i] and not gate_dead[i]:
				gate_c4[i] = false
				blast(DamPad.gate_pos(i), C4_RADIUS, C4_DMG, 1.0)
		for l in get_tree().get_nodes_in_group("dam_c4"):
			l.queue_free()


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
	_build_barriers()
	call_deferred("_spawn_wachters")


## Onzichtbare botsing: een borstwering tussen de kroon en de trap/loopbrug, zodat je alleen via de uiteinden van de trap omhoog loopt.
func _build_barriers() -> void:
	var body := StaticBody3D.new()
	body.name = "Barriere"
	body.collision_layer = Kit.LAYER_WALL
	body.collision_mask = 0
	var sh := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(DamPad.STAIR_X1 * 2.0, 8.0, 0.4)
	sh.shape = bx
	sh.position = Vector3(0.0, DamPad.CROWN_Y + 4.0, -1.3)   # lokaal: dam staat op (gorge_x, DAM_FLOOR, DAM_Z)
	body.add_child(sh)
	add_child(body)


## De wachters (keuze 6A): zes soldaten op de kloofbodem voor de dam. Ze blijven op hun post en schieten binnen 16 m (zoals de verdedigers van de vijandbasis).
## Twee MG-torens staan nog niet: de toren van de vijandbasis hangt aan de muren van die basis (komt later).
const WACHT_PLEKKEN := [Vector2(-7.0, 18.0), Vector2(6.0, 17.0), Vector2(-3.0, 24.0), Vector2(9.0, 25.0), Vector2(-9.0, 30.0), Vector2(2.0, 31.0)]
var wachters: Array = []


func _spawn_wachters() -> void:
	if not is_inside_tree() or get_tree().root.get_node_or_null("Game") == null:
		return
	var ps: PackedScene = load("res://scenes/vijand_verdediger.tscn")
	if ps == null:
		return
	for pl in WACHT_PLEKKEN:
		var wp := Vector3(global_position.x + pl.x, 0.0, Bergland.DAM_Z + pl.y)
		wp.y = Bergland.height(wp.x, wp.z)
		var sol = ps.instantiate()
		sol.setup("assault", 1)
		sol.post = "poort"
		sol.max_hp = 90.0
		sol.hp = 90.0
		sol.home = wp
		sol.name = "DamWachter"
		sol.add_to_group("dam_wachter")
		get_parent().add_child(sol)
		sol.global_position = wp
		wachters.append(sol)


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
