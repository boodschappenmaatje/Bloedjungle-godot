class_name Bosbrand
extends Node3D
## Bosbrand als kettingreactie (v212). Een ontploffing (granaat, tankgranaat, vat, voertuig, napalm; alles wat
## Game.note_blast aanroept) steekt de planten op die plek aan. Het vuur loopt rustig van vak naar vak (3 m) zolang
## er planten staan, en dooft vanzelf: na GEN stappen, op kale grond, bij de rivier, op de paden en in de stad.
## Planten verschroeien (donkere instance-kleur; bomen blijven staan), de grond wordt blijvend zwart (burn_map in
## ground.gdshader) en wie in een brandend vak staat krijgt schade (vijanden en de speler).
## Prestaties: hooguit MAX_FLAMES vlammen (gedeeld materiaal uit Fx.napalm_flame_sim), MAX_LIGHTS lichten en
## MAX_SMOKES rookpluimen tegelijk, en nooit meer dan MAX_BURNING brandende vakken.

const CELL := 3.0
const GEN := 7                # zoveel stappen loopt het vuur hooguit door vanaf de ontploffing (7 x 3 m = ruim 20 m)
const SPREAD_T := Vector2(2.6, 4.6)   # seconden voor het vuur naar een buurvak overslaat
const BURN_T := Vector2(7.0, 10.0)    # zo lang brandt één vak
const MAX_BURNING := 70
const MAX_FLAMES := 30
const MAX_LIGHTS := 3
const MAX_SMOKES := 7
const FLAME_RANGE := 70.0     # verder van de camera: geen vlam tekenen (het verschroeien loopt wel door)
const FUEL := {"grass": 1.0, "fern": 1.5, "bush": 2.2, "palm": 3.0}
const DAMAGE_TICK := 0.4
const ENEMY_DPS := 28.0
const PLAYER_DPS := 14.0
# verschroeide kleuren: foliage.gdshader rekent de kleur als sRGB om, grass_3d.gdshader gebruikt hem direct
const CHAR := {"grass": Color(0.1, 0.085, 0.07), "fern": Color(0.3, 0.26, 0.22), "bush": Color(0.3, 0.26, 0.22), "palm": Color(0.5, 0.42, 0.34)}
# brandkaart op de grond: 1,5 m per beeldpunt over de hele grondplaat
const MAP_TEXEL := 1.5
const MAP_X0 := -222.0
const MAP_Z0 := -291.0
const MAP_W := 296
const MAP_H := 344

static var _inst: Bosbrand

var _index := {}       # vak (3 m) -> Array van vegetatie-items (Foliage._vegetation_cells)
var _cells := {}       # vak -> {state: 1 brandt / 2 verbrand, t, burn, spread_t, gen, flame, charred}
var _burning: Array[Vector2i] = []
var _flames: Array[MeshInstance3D] = []   # vrije vlammen
var _flame_count := 0
var _lights: Array[OmniLight3D] = []
var _smokes := 0
var _img: Image
var _tex: ImageTexture
var _dirty := false
var _map_t := 0.0
var _dmg_t := 0.0
var _light_t := 0.0
var burned_total := 0   # voor tests


## Aanroepen nadat Foliage.plant klaar is (level.gd). Maakt de index en de brandkaart; kost alleen laadtijd.
static func setup(level: Node3D) -> void:
	if is_instance_valid(_inst):
		_inst.free()
	_inst = Bosbrand.new()
	_inst.name = "Bosbrand"
	level.add_child(_inst)
	_inst._build(level)


## Een ontploffing (Game.note_blast): planten binnen de kern van de knal vatten vlam.
static func catch_blast(at: Vector3, radius: float) -> int:
	if not is_instance_valid(_inst):
		return 0
	return _inst.ignite(at, maxf(radius * 0.5, 1.6))


static func is_burning_at(pos: Vector3) -> bool:
	if not is_instance_valid(_inst):
		return false
	var c: Dictionary = _inst._cells.get(_key(pos), {})
	return not c.is_empty() and c.state == 1


static func is_burned_at(pos: Vector3) -> bool:
	if not is_instance_valid(_inst):
		return false
	return _inst._cells.has(_key(pos))


static func burning_count() -> int:
	return _inst._burning.size() if is_instance_valid(_inst) else 0


static func _key(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))


func _build(level: Node3D) -> void:
	var veg: Dictionary = Foliage._vegetation_cells
	for big in veg:
		for e: Dictionary in veg[big]:
			if not FUEL.has(e.get("kind", "")):
				continue
			var k := _key(e["world_position"])
			if not _index.has(k):
				_index[k] = []
			_index[k].append(e)
	_img = Image.create(MAP_W, MAP_H, false, Image.FORMAT_R8)
	_tex = ImageTexture.create_from_image(_img)
	for g in level.get_children():
		if g.is_in_group("ground") and g.has_meta("mat"):
			var mat: ShaderMaterial = g.get_meta("mat")
			mat.set_shader_parameter("burn_map", _tex)
			mat.set_shader_parameter("burn_rect", Vector4(MAP_X0, MAP_Z0, 1.0 / (MAP_W * MAP_TEXEL), 1.0 / (MAP_H * MAP_TEXEL)))


## Brandstof in een vak: wat er nog staat en nog niet verbrand is.
func _fuel(k: Vector2i) -> float:
	var f := 0.0
	for e: Dictionary in _index.get(k, []):
		if not e.get("cleared", false) and not e.get("scorched", false):
			f += FUEL[e["kind"]]
	return f


## Water, de oever, de paden en de stad houden het vuur tegen (zelfde regel als waar geen planten mogen staan).
func _blocked(k: Vector2i) -> bool:
	var p := Vector3((k.x + 0.5) * CELL, 0.0, (k.y + 0.5) * CELL)
	return absf(p.z - Data.river_z(p.x)) < Data.RIVER_HALF + 1.5 or Foliage._in_river(p)


## Steekt alle vakken met planten binnen radius aan. Geeft het aantal aangestoken vakken.
func ignite(at: Vector3, radius: float) -> int:
	var n := 0
	var r := ceili(radius / CELL)
	var c := _key(at)
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var k := c + Vector2i(dx, dz)
			var mid := Vector3((k.x + 0.5) * CELL, 0.0, (k.y + 0.5) * CELL)
			if Vector2(mid.x - at.x, mid.z - at.z).length() > radius + CELL * 0.5:
				continue
			if _light(k, GEN):
				n += 1
	if n > 0:
		Sfx.play("wuuf", 0.7, at)
	return n


func _light(k: Vector2i, gen: int) -> bool:
	if _cells.has(k) or _burning.size() >= MAX_BURNING or _blocked(k):
		return false
	var fuel := _fuel(k)
	if fuel <= 0.0:
		return false
	var tall := false
	for e: Dictionary in _index[k]:
		if e["kind"] == "palm" or e["kind"] == "bush":
			tall = true
			break
	var cell := {"state": 1, "t": 0.0, "burn": randf_range(BURN_T.x, BURN_T.y) + minf(fuel, 8.0) * 0.25,
		"spread_t": randf_range(SPREAD_T.x, SPREAD_T.y), "gen": gen, "flame": null, "charred": false, "tall": tall, "smoke": null}
	_cells[k] = cell
	_burning.append(k)
	burned_total += 1
	_give_flame(k, cell)
	return true


func _mid(k: Vector2i) -> Vector3:
	return Vector3((k.x + 0.5) * CELL, 0.0, (k.y + 0.5) * CELL)


func _give_flame(k: Vector2i, cell: Dictionary) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var pos := _mid(k) + Vector3(randf_range(-0.7, 0.7), 0.0, randf_range(-0.7, 0.7))
	if cam != null and cam.global_position.distance_to(pos) > FLAME_RANGE:
		return
	var h: float = randf_range(2.2, 3.0) if cell.tall else randf_range(1.1, 1.6)
	var mi: MeshInstance3D
	# de hoge en de lage vlam hebben elk hun eigen vorm: hergebruik alleen een vlam van dezelfde soort
	for i in _flames.size():
		if bool(_flames[i].get_meta("tall")) == bool(cell.tall):
			mi = _flames[i]
			_flames.remove_at(i)
			break
	if mi == null:
		if _flame_count >= MAX_FLAMES:
			return
		_flame_count += 1
		mi = Fx.napalm_flame_sim(self, Vector3.ZERO, h, not cell.tall)
		mi.set_meta("tall", cell.tall)
	mi.visible = true
	mi.global_position = pos
	mi.set_instance_shader_parameter("seed", randf() * 10.0)
	mi.set_instance_shader_parameter("grow", 0.0)
	var tw := mi.create_tween()
	tw.tween_method(func(g: float): mi.set_instance_shader_parameter("grow", g), 0.0, 1.0, 1.1)
	cell.flame = mi
	if _smokes < MAX_SMOKES and randf() < 0.45:
		_smokes += 1
		var sm := Fx._puff(6, 3.6, 2.6, false, Fx._ramp([Color(0.1, 0.09, 0.08, 0.0), Color(0.15, 0.14, 0.13, 0.42), Color(0.24, 0.23, 0.22, 0.0)], [0.0, 0.25, 1.0]), Vector2(1.0, 2.2), 2.2)
		add_child(sm)
		sm.global_position = pos + Vector3(0.0, h * 0.8, 0.0)
		sm.emitting = true
		cell.smoke = sm


func _process(delta: float) -> void:
	if _burning.is_empty():
		if _dirty:
			_flush_map()
		for l in _lights:
			l.visible = false
		return
	var rain := GameSettings.get_value("weather") == "rain"
	for i in range(_burning.size() - 1, -1, -1):
		var k := _burning[i]
		var cell: Dictionary = _cells[k]
		cell.t += delta
		if not cell.charred and cell.t > cell.burn * 0.45:
			cell.charred = true
			_char(k)
		if cell.spread_t > 0.0 and cell.t >= cell.spread_t:
			cell.spread_t = -1.0
			_spread(k, cell.gen, rain)
		if cell.t >= cell.burn:
			_end(k, cell)
			_burning.remove_at(i)
	_dmg_t += delta
	if _dmg_t >= DAMAGE_TICK:
		_damage(_dmg_t)
		_dmg_t = 0.0
	_light_t -= delta
	if _light_t <= 0.0:
		_light_t = 0.5
		_place_lights()
	_map_t += delta
	if _dirty and _map_t > 0.2:
		_flush_map()


func _spread(k: Vector2i, gen: int, rain: bool) -> void:
	if gen <= 0:
		return
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if dx == 0 and dz == 0:
				continue
			var n := k + Vector2i(dx, dz)
			if _cells.has(n):
				continue
			var fuel := _fuel(n)
			if fuel <= 0.0:
				continue
			var chance := clampf(0.2 + 0.075 * fuel, 0.0, 0.78)
			if dx != 0 and dz != 0:
				chance *= 0.6
			if rain:
				chance *= 0.45   # regen: het vuur slaat veel minder vaak over
			if randf() < chance:
				_light(n, gen - 1)


## Planten in het vak verschroeien: donkere kleur op de echte MultiMesh-instances. Bomen blijven staan.
func _char(k: Vector2i) -> void:
	for e: Dictionary in _index.get(k, []):
		if e.get("cleared", false) or e.get("scorched", false):
			continue
		e["scorched"] = true
		var col: Color = CHAR[e["kind"]]
		for slot: Dictionary in e.get("slots", []):
			var mm: MultiMesh = slot.get("multimesh")
			if mm != null and mm.use_colors and int(slot.index) < mm.instance_count:
				var v := randf_range(0.8, 1.15)
				mm.set_instance_color(int(slot.index), Color(col.r * v, col.g * v, col.b * v, 1.0))
	# de grond: het vak plus een rafelrand, zodat de vlek niet vierkant wordt
	var mid := _mid(k)
	var tx := int((mid.x - MAP_X0) / MAP_TEXEL)
	var tz := int((mid.z - MAP_Z0) / MAP_TEXEL)
	for ox in range(-2, 2):
		for oz in range(-2, 2):
			var x := tx + ox
			var z := tz + oz
			if x < 0 or z < 0 or x >= MAP_W or z >= MAP_H:
				continue
			var core := ox >= -1 and ox <= 0 and oz >= -1 and oz <= 0
			var v := 1.0 if core else randf_range(0.25, 0.7)
			_img.set_pixel(x, z, Color(maxf(_img.get_pixel(x, z).r, v), 0, 0))
	_dirty = true


func _flush_map() -> void:
	_tex.update(_img)
	_dirty = false
	_map_t = 0.0


func _end(_k: Vector2i, cell: Dictionary) -> void:
	cell.state = 2
	var mi: MeshInstance3D = cell.flame
	cell.flame = null
	if mi != null and is_instance_valid(mi):
		var tw := mi.create_tween()
		tw.tween_method(func(g: float): mi.set_instance_shader_parameter("grow", g), 1.0, 0.0, 1.4)
		tw.tween_callback(func():
			mi.visible = false
			_flames.append(mi))
	var sm: CPUParticles3D = cell.smoke
	cell.smoke = null
	if sm != null and is_instance_valid(sm):
		sm.emitting = false
		get_tree().create_timer(4.0).timeout.connect(func():
			_smokes -= 1
			if is_instance_valid(sm):
				sm.queue_free())


func _damage(dt: float) -> void:
	var old_class: String = Game.hit_class
	var old_src: String = Game.hit_src
	Game.hit_class = ""
	Game.hit_src = "lucht"   # vuur telt niet als kill van de speler
	for e in Game.enemies.duplicate():
		if is_instance_valid(e) and not e.dead and e is Node3D and is_burning_at(e.global_position):
			e.hit(ENEMY_DPS * dt, Vector3.UP, true)
	Game.hit_class = old_class
	Game.hit_src = old_src
	var p = Game.player
	if p != null and is_instance_valid(p) and not p.dead and not p.in_tank and is_burning_at(p.global_position):
		p.hit(PLAYER_DPS * dt, Vector3.UP, false)


## Een paar flikkerende lichten bij de brandende vakken het dichtst bij de camera.
func _place_lights() -> void:
	var cam := get_viewport().get_camera_3d()
	var from := cam.global_position if cam != null else Vector3.ZERO
	var near: Array = []
	for k in _burning:
		near.append([_mid(k).distance_squared_to(from), k])
	near.sort_custom(func(a, b): return a[0] < b[0])
	for i in MAX_LIGHTS:
		if i >= _lights.size():
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.5, 0.18)
			l.omni_range = 10.0
			l.shadow_enabled = false
			add_child(l)
			_lights.append(l)
		var light := _lights[i]
		# verspreid over de brand: niet drie lichten op hetzelfde vak
		var pick := i * maxi(1, near.size() / MAX_LIGHTS)
		if pick < near.size():
			light.visible = true
			light.global_position = _mid(near[pick][1]) + Vector3(0.0, 2.0, 0.0)
			light.light_energy = randf_range(2.6, 4.4)
		else:
			light.visible = false


func _exit_tree() -> void:
	if _inst == self:
		_inst = null
