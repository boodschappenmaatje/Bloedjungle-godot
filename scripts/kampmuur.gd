class_name Kampmuur
## De muren van de MCV-start (Generals-plan "Stap MCV", stap 3): je trekt ze met je vinger over het bouwscherm, zoals een weg in de stadseditor.
## Muren staan op een rooster van STEP (3,5 m) en lopen alleen langs de roosterlijnen (noord-zuid en oost-west): elk stuk (een "rand" tussen twee
## roosterpunten) is een eigen bouwstuk (Buildings kind "kampmuur") met eigen sterkte, dat vijanden kapot schieten en dat je kunt verkopen en repareren.
## Kosten: 50 per stuk. De eerste complete omheining rond je hoofdkwartier is gratis (`Game.free_wall`): zolang die niet af is kosten de eerste FREE_CAP
## stukken niets; sluit je de muur rond het hoofdkwartier, dan blijft alles gratis en kost elk volgend stuk 50.
## Een omheining is "compleet" als je vanuit het hoofdkwartier over het rooster niet meer buiten het kamp kunt komen zonder een muur (of poort) te kruisen.

const STEP := 3.5            # m: lengte van een muurstuk = afstand tussen twee roosterpunten
const HEIGHT := 3.0
const THICK := 0.7
const COST := 50
const FREE_CAP := 150        # zoveel stukken zijn gratis zolang de eerste omheining nog niet af is (voorkomt eindeloos gratis muren)
const RADIUS := 40           # cellen vanaf het hoofdkwartier waarbuiten het kamp als "open" geldt (140 m)
const LOD_NAMES := ["Wall_LOD0", "Wall_LOD1", "Wall_LOD2"]
const LOD_BEGIN := [0.0, 28.0, 58.0]

static var _lods: Array = []   # de drie meshes (LOD0..2) van de muurmodule, eenmaal geladen


# ---------------------------------------------------------------- rooster

static func snap(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / STEP), roundi(p.z / STEP))


static func vertex(v: Vector2i) -> Vector3:
	return Vector3(v.x * STEP, 0.0, v.y * STEP)


## Sleutel van de rand tussen twee buurpunten (volgorde maakt niet uit).
static func edge_key(a: Vector2i, b: Vector2i) -> Vector4i:
	if a.x < b.x or (a.x == b.x and a.y <= b.y):
		return Vector4i(a.x, a.y, b.x, b.y)
	return Vector4i(b.x, b.y, a.x, a.y)


static func edge_center(k: Vector4i) -> Vector3:
	return (vertex(Vector2i(k.x, k.y)) + vertex(Vector2i(k.z, k.w))) * 0.5


## Draaiing van het muurstuk: 0 langs de x-as, kwartslag langs de z-as (de lengte van het stuk is zijn lokale x).
static func edge_yaw(k: Vector4i) -> float:
	return 0.0 if k.y == k.w else PI / 2.0


## De rand waar een muurstuk op staat (uit zijn middelpunt en draaiing).
static func edge_of(at: Vector3, yaw: float) -> Vector4i:
	if is_zero_approx(fposmod(yaw, PI)):
		var a := Vector2i(roundi((at.x - STEP * 0.5) / STEP), roundi(at.z / STEP))
		return edge_key(a, a + Vector2i(1, 0))
	var a2 := Vector2i(roundi(at.x / STEP), roundi((at.z - STEP * 0.5) / STEP))
	return edge_key(a2, a2 + Vector2i(0, 1))


## Vult een pad (rij roosterpunten) aan tot de nieuwe vingerpositie `to`: stap voor stap in de richting met het grootste verschil; teruggaan haalt het
## laatste stukje weer weg (zoals de lijn in de stadseditor).
static func extend(path: Array, to: Vector2i) -> void:
	if path.is_empty():
		path.append(to)
		return
	var guard := 0
	while path[path.size() - 1] != to and guard < 400:
		guard += 1
		var cur: Vector2i = path[path.size() - 1]
		var d := to - cur
		var nxt := cur + (Vector2i(signi(d.x), 0) if absi(d.x) >= absi(d.y) else Vector2i(0, signi(d.y)))
		if path.size() >= 2 and path[path.size() - 2] == nxt:
			path.pop_back()
		else:
			path.append(nxt)


## Een rechte lijn van a naar b (a en b liggen op dezelfde rij of kolom; anders alleen het stuk langs de x-as).
static func line_path(a: Vector2i, b: Vector2i) -> Array:
	var path: Array = [a]
	var end := Vector2i(b.x, a.y) if a.y != b.y and a.x != b.x else b
	extend(path, end)
	return path


## Een gesloten vierkant (rechthoek) met a en b als overstaande hoeken: vier zijden in één keer.
static func rect_path(a: Vector2i, b: Vector2i) -> Array:
	if a.x == b.x or a.y == b.y:
		return line_path(a, b)
	var path: Array = [a]
	for c in [Vector2i(b.x, a.y), b, Vector2i(a.x, b.y), a]:
		extend(path, c)
	return path


## Het roosterpunt waar een nieuwe muur begint: een eindpunt van een bestaande muur of poort binnen anderhalf stuk van de vinger (zo sluit een nieuwe lijn
## aan zonder dat je het punt precies moet raken), anders het dichtstbijzijnde roosterpunt.
static func snap_start(p: Vector3) -> Vector2i:
	var best := snap(p)
	var best_d := STEP * 1.5
	for k in existing():
		for v in [Vector2i(k.x, k.y), Vector2i(k.z, k.w)]:
			var d := vertex(v).distance_to(Vector3(p.x, 0.0, p.z))
			if d < best_d:
				best_d = d
				best = v
	return best


## De randen van een pad.
static func path_edges(path: Array) -> Array:
	var out: Array = []
	for i in range(0, path.size() - 1):
		out.append(edge_key(path[i], path[i + 1]))
	return out


# ---------------------------------------------------------------- bestaande muren

## Alle bestaande muurstukken (en poorten): rand -> bouwstuk.
static func existing() -> Dictionary:
	var out := {}
	for b in Game.buildings:
		if b.kind == "kampmuur" and b.get("edge") != null:
			out[b.edge] = b
	if Game.gates != null and is_instance_valid(Game.gates):
		for g in Game.gates.list:
			if g.get("edge") != null:
				out[g.edge] = g    # een poort telt als muur voor de omheining en neemt twee randen in
				out[g.edge2] = g
	return out


## Soldaten zoeken zelf hun weg om de muren van jouw kamp en door de poort (die gaat voor hen vanzelf open). Kruist de rechte lijn naar het doel een
## muur, dan loopt hij over het rooster (de cellen tussen vier roosterpunten, zoals bij de omheining) langs de open randen en poorten naar het doel.
## Geeft het middelpunt van de eerstvolgende cel, of null als je rechtdoor kunt lopen (geen muren, geen muur in de weg, al in de cel van het doel).
static var _walls_cache: Dictionary = {}
static var _walls_t := -100000
static var _all_cache: Dictionary = {}
static var _route_cache: Dictionary = {}


static func _walls() -> Dictionary:
	var now := Time.get_ticks_msec()
	if now - _walls_t > 1500:
		_walls_t = now
		_route_cache = {}
		var out := {}
		var all := existing()
		for k in all:
			var w: Dictionary = all[k]
			if str(w.get("kind", "")) == "kampmuur":   # een poort is geen muur: daar mag je door
				out[k] = true
		_walls_cache = out
		_all_cache = all
	return _walls_cache


static func _cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / STEP), floori(p.z / STEP))


## Staat er een muur tussen deze twee buurcellen?
static func _blocked(walls: Dictionary, c: Vector2i, step: Vector2i) -> bool:
	for m in cell_moves(c):
		if m[0] == step:
			return walls.has(m[1])
	return false


## Kruist de rechte lijn van `from` naar `goal` een muur?
static func _crosses(walls: Dictionary, from: Vector3, goal: Vector3, half := 0.7) -> bool:
	# ook strak langs een muurkop of de rand van een poortopening telt (een soldaat is geen punt): dus de lijn en twee lijnen 0,7 m ernaast (een voertuig: de halve breedte van zijn romp)
	var d := Vector2(goal.x - from.x, goal.z - from.z)
	var side := Vector3(-d.y, 0.0, d.x).normalized() * half if d.length() > 0.01 else Vector3.ZERO
	return _crosses_line(walls, from, goal) or _crosses_line(walls, from + side, goal + side) or _crosses_line(walls, from - side, goal - side)


static func _crosses_line(walls: Dictionary, from: Vector3, goal: Vector3) -> bool:
	var d := Vector2(goal.x - from.x, goal.z - from.z)
	var n := maxi(1, ceili(d.length() / 1.2))
	var prev := _cell_of(from)
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		var c := _cell_of(Vector3(from.x + d.x * t, 0.0, from.z + d.y * t))
		if c != prev:
			var dx := c.x - prev.x
			var dy := c.y - prev.y
			if dx != 0 and _blocked(walls, prev, Vector2i(dx, 0)):
				return true
			if dy != 0 and _blocked(walls, prev, Vector2i(0, dy)):
				return true
			if dx != 0 and dy != 0 and _blocked(walls, prev + Vector2i(0, dy), Vector2i(dx, 0)):
				return true
			prev = c
	return false


static func route_next(from: Vector3, goal: Vector3) -> Variant:
	var walls := _walls()
	if walls.is_empty():
		return null
	var a := _cell_of(from)
	var b := _cell_of(goal)
	if a == b or not _crosses(walls, from, goal):
		return null
	var key := Vector4i(a.x, a.y, b.x, b.y)
	var path: Array
	if _route_cache.has(key):
		path = _route_cache[key]
	else:
		path = _bfs(walls, a, b)
		_route_cache[key] = path
	if path.size() < 2:
		return null
	# door een poort: dwars door het midden van de opening (de middelpunten van de cellen liggen er tegen de rand van de poortopening aan)
	var step: Vector2i = path[1] - path[0]
	for m in cell_moves(path[0]):
		if m[0] == step and _all_cache.has(m[1]):
			var g: Dictionary = _all_cache[m[1]]
			return Vector3(g.at.x + step.x * 1.3, 0.0, g.at.z + step.y * 1.3)
	return cell_center(path[1])


## Voor een voertuig (jeep of tank, `half` m aan elke kant van zijn midden): dezelfde weg als `route_next`, maar dwars door het midden van de poort. Een voertuig is veel breder dan een soldaat
## en haakt anders achter de rand van de opening. Eerst rijdt hij naar een punt 10 m voor de poort op de middellijn, dan door de poort naar een punt 10 m erachter. Is hij al uitgelijnd
## (binnen een trechter rond de middellijn), dan rijdt hij meteen door. Geeft null als hij rechtdoor kan (geen muur in de weg, ook niet voor zijn romp).
static func vehicle_next(from: Vector3, goal: Vector3, half: float) -> Variant:
	var walls := _walls()
	if walls.is_empty():
		return null
	var a := _cell_of(from)
	var b := _cell_of(goal)
	if a == b or not _crosses(walls, from, goal, half):
		return null
	var key := Vector4i(a.x, a.y, b.x, b.y)
	var path: Array
	if _route_cache.has(key):
		path = _route_cache[key]
	else:
		path = _bfs(walls, a, b)
		_route_cache[key] = path
	if path.size() < 2:
		return null
	for i in path.size() - 1:
		var step: Vector2i = path[i + 1] - path[i]
		for m in cell_moves(path[i]):
			if m[0] == step and _all_cache.has(m[1]):
				var g: Dictionary = _all_cache[m[1]]
				var at := Vector3(g.at.x, 0.0, g.at.z)
				var dir := Vector3(step.x, 0.0, step.y)
				var rel := from - at
				var along := rel.x * dir.x + rel.z * dir.z   # < 0: nog voor de poort
				var lat := absf(rel.x * dir.z - rel.z * dir.x)
				if along > 0.5:
					return null   # al voorbij het midden van de poort: gewoon verder naar het doel
				if lat <= 0.9 + 0.12 * absf(along):
					return at + dir * 10.0   # uitgelijnd: dwars door de poort
				return at - dir * 10.0       # eerst naar de middellijn, 10 m voor de poort
	return route_next(from, goal)


## Kortste weg over het rooster van cel a naar cel b, rond de muren (poorten zijn open); leeg als er geen weg is.
static func _bfs(walls: Dictionary, a: Vector2i, b: Vector2i) -> Array:
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var hi := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	for k in walls:
		lo = Vector2i(mini(lo.x, (k as Vector4i).x), mini(lo.y, (k as Vector4i).y))
		hi = Vector2i(maxi(hi.x, (k as Vector4i).z), maxi(hi.y, (k as Vector4i).w))
	lo -= Vector2i(4, 4)
	hi += Vector2i(4, 4)
	var came := {a: a}
	var queue: Array = [a]
	var qi := 0
	while qi < queue.size():
		var c: Vector2i = queue[qi]
		qi += 1
		if c == b:
			break
		for m in cell_moves(c):
			var nx: Vector2i = c + (m[0] as Vector2i)
			if came.has(nx) or walls.has(m[1]) or nx.x < lo.x or nx.y < lo.y or nx.x > hi.x or nx.y > hi.y:
				continue
			came[nx] = c
			queue.append(nx)
	if not came.has(b):
		return []
	var out: Array = [b]
	var cur := b
	while cur != a:
		cur = came[cur]
		out.append(cur)
	out.reverse()
	return out


static func count() -> int:
	var n := 0
	for b in Game.buildings:
		if b.kind == "kampmuur":
			n += 1
	return n


static func count_free() -> int:
	var n := 0
	for b in Game.buildings:
		if b.kind == "kampmuur" and b.get("gratis", false):
			n += 1
	return n


## Hoeveel stukken zijn er nu nog gratis? 0 als de eerste omheining al compleet is.
static func free_left() -> int:
	return maxi(0, FREE_CAP - count_free()) if Game.free_wall else 0


## Wat het volgende muurstuk kost.
static func next_cost() -> int:
	return 0 if free_left() > 0 else COST


# ---------------------------------------------------------------- omheining

## Is het hoofdkwartier omsloten? Vanuit zijn cel over het rooster (de cellen tussen vier roosterpunten): elke stap kruist een rand; staat daar een muur of poort,
## dan kom je er niet door. Bereik je de rand van het zoekgebied, dan is het kamp open.
static func enclosed(walls: Dictionary = {}) -> bool:
	return not region(walls).is_empty()


## De cellen (Vector2i) binnen de omheining, of een leeg woordenboek als het hoofdkwartier niet omsloten is.
static func region(walls: Dictionary = {}) -> Dictionary:
	if walls.is_empty():
		walls = existing()
	if walls.is_empty():
		return {}
	var start := Vector2i(floori(Game.base_pos.x / STEP), floori(Game.base_pos.z / STEP))
	var seen := {start: true}
	var queue: Array = [start]
	var qi := 0
	while qi < queue.size():
		var c: Vector2i = queue[qi]
		qi += 1
		if absi(c.x - start.x) > RADIUS or absi(c.y - start.y) > RADIUS:
			return {}
		for m in cell_moves(c):
			var n: Vector2i = c + (m[0] as Vector2i)
			if seen.has(n) or walls.has(m[1]):
				continue
			seen[n] = true
			queue.append(n)
	return seen


## De vier buren van een cel met de rand ertussen: [[stap, randsleutel], ...]. De rand loopt tussen twee roosterpunten.
static func cell_moves(c: Vector2i) -> Array:
	return [
		[Vector2i(1, 0), edge_key(Vector2i(c.x + 1, c.y), Vector2i(c.x + 1, c.y + 1))],
		[Vector2i(-1, 0), edge_key(Vector2i(c.x, c.y), Vector2i(c.x, c.y + 1))],
		[Vector2i(0, 1), edge_key(Vector2i(c.x, c.y + 1), Vector2i(c.x + 1, c.y + 1))],
		[Vector2i(0, -1), edge_key(Vector2i(c.x, c.y), Vector2i(c.x + 1, c.y))],
	]


## Middelpunt van een cel in de wereld.
static func cell_center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * STEP, 0.0, (c.y + 0.5) * STEP)


## Na het bouwen of verkopen: is de eerste omheining nu compleet? Dan blijft alles wat tot nu toe gratis was gratis en kost elk volgend stuk 50.
## Alles binnen de omheining verdwijnt vanzelf (bomen, struiken, gras, stammen, rotsen), waar het ook staat: het vierkant is dan van jou.
static func clear_inside(walls: Dictionary = {}) -> int:
	var cells := region(walls)
	if cells.is_empty():
		return 0
	var rows := {}   # rij (z) -> de x-cellen in die rij
	for c: Vector2i in cells:
		if not rows.has(c.y):
			rows[c.y] = []
		(rows[c.y] as Array).append(c.x)
	var rects: Array = []
	for z in rows:
		var xs: Array = rows[z]
		xs.sort()
		var start: int = xs[0]
		var prev: int = xs[0]
		for i in range(1, xs.size() + 1):
			if i < xs.size() and int(xs[i]) == prev + 1:
				prev = xs[i]
				continue
			rects.append(Rect2(start * STEP, int(z) * STEP, (prev - start + 1) * STEP, STEP))
			if i < xs.size():
				start = xs[i]
				prev = xs[i]
	return Foliage.clear_world_rects(rects, 0.4)


static func check_enclosure() -> void:
	if Game.mcv_deployed and enclosed():
		clear_inside()
	if Game.free_wall and Game.mcv_deployed and enclosed():
		Game.free_wall = false
		Game.banner.emit("OMHEINING COMPLEET", "Die was gratis · elk volgend muurstuk kost %d" % COST, 3.5)
		Sfx.play("buy")
		Game.changed.emit()


# ---------------------------------------------------------------- uiterlijk

## Het model van één muurstuk (de Meshy-muurmodule met drie detailniveaus, dezelfde als de oude kampmuur) onder `body`.
static func add_visual(body: Node3D) -> void:
	if _lods.is_empty():
		var packed := load(BaseProps.BASE_WALL_ASSET) as PackedScene
		if packed == null:
			push_error("Kampmuur: muurasset ontbreekt: " + BaseProps.BASE_WALL_ASSET)
		else:
			var template := packed.instantiate()
			var found := {}
			for node in template.find_children("*", "MeshInstance3D", true, false):
				if LOD_NAMES.has(node.name):
					found[node.name] = (node as MeshInstance3D).mesh
			template.free()
			for nm in LOD_NAMES:
				if not found.has(nm):
					push_error("Kampmuur: LOD ontbreekt in de muurasset: " + nm)
					_lods = []
					break
				_lods.append(found[nm])
			for mesh: Mesh in _lods:
				for s in mesh.get_surface_count():
					var pbr := mesh.surface_get_material(s) as StandardMaterial3D
					if pbr != null:
						pbr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
						pbr.normal_scale = minf(pbr.normal_scale, 0.5)
	if _lods.is_empty():
		Kit.box(body, Vector3.ZERO, Vector3(STEP, HEIGHT, THICK), Kit.concrete())   # nooit zonder muur: een blok als het model niet te laden is
		return
	var visuals: Array[MeshInstance3D] = []
	for i in LOD_NAMES.size():
		var mi := MeshInstance3D.new()
		mi.name = LOD_NAMES[i]
		mi.mesh = _lods[i]
		mi.visibility_range_begin = LOD_BEGIN[i]
		mi.visibility_range_end = 0.0
		mi.visibility_range_begin_margin = 1.5 if LOD_BEGIN[i] > 0.0 else 0.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if i > 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		body.add_child(mi)
		visuals.append(mi)
	for i in visuals.size() - 1:
		visuals[i].visibility_parent = visuals[i].get_path_to(visuals[i + 1])


# ---------------------------------------------------------------- tekenen en bouwen

## Wat er gebeurt als je dit pad bouwt: per rand {key, at, yaw, state} met state "bestaat", "ok", "slecht" (kan daar niet) of "duur" (te weinig punten),
## plus het aantal nieuwe stukken (`built`) en wat ze samen kosten (`cost`). De eerste stukken zijn gratis zolang de eerste omheining niet af is.
static func plan(path: Array) -> Dictionary:
	var walls := existing()
	var out: Array = []
	var cost := 0
	var built := 0
	var free_left_now := free_left()
	var budget: int = Game.build_credit + Game.points
	var reason := ""
	for k in path_edges(path):
		var at := edge_center(k)
		var yaw := edge_yaw(k)
		var e := {"key": k, "at": at, "yaw": yaw, "state": "ok"}
		if walls.has(k):
			e.state = "bestaat"
		else:
			var st: Dictionary = Game.builds.placement_status("kampmuur", at, yaw)
			if not st.valid:
				e.state = "slecht"
				reason = String(st.reason)
			else:
				var c := 0 if built < free_left_now else COST
				if cost + c > budget:
					e.state = "duur"
				else:
					cost += c
					built += 1
		out.append(e)
	return {"edges": out, "cost": cost, "built": built, "reason": reason}


## Bouwt de nieuwe stukken van een pad (in volgorde, zolang je ze kunt betalen). Geeft {built, skipped, poor, reason}.
static func build(path: Array) -> Dictionary:
	var r := {"built": 0, "skipped": 0, "poor": 0, "reason": ""}
	var walls := existing()
	var b: Buildings = Game.builds
	b.batch = true
	for k in path_edges(path):
		if walls.has(k):
			continue
		var at := edge_center(k)
		var yaw := edge_yaw(k)
		var st: Dictionary = b.placement_status("kampmuur", at, yaw)
		if not st.valid:
			r.skipped += 1
			r.reason = String(st.reason)
			continue
		if not Game.can_afford_build(next_cost()):
			r.poor += 1
			continue
		if b.place("kampmuur", at, yaw) != null:
			r.built += 1
		else:
			r.skipped += 1
	b.batch = false
	if int(r.built) > 0:
		Wachten.invalidate()
		Sfx.play("thud")
		Game.changed.emit()
		check_enclosure()
	# het getrokken vierkant is van jou: ook als een stuk is overgeslagen (te duur, in de weg) verdwijnt de begroeiing binnen de lijnen
	if Game.mcv_deployed and path.size() >= 4:
		var plan := existing()
		for k in path_edges(path):
			if not plan.has(k):
				plan[k] = {"kind": "plan"}
		clear_inside(plan)
	return r


# ---------------------------------------------------------------- poort

const GATE_COST := 100       # voorstel (Dennis heeft er nog geen prijs voor genoemd)
const GATE_LANE_SIDE := 4.4   # m: half, langs de muur: de opening (3,4) plus ruimte voor een brede tank
const GATE_LANE_ALONG := 9.0  # m: half, door de poort heen: wat een voertuig nodig heeft om rechtuit door de opening te rijden


## De twee randen en het midden voor een poort bij het aangetikte muurstuk `k`: het stuk zelf plus zijn buur in dezelfde lijn aan de kant van `toward`
## (het aangetikte wereldpunt); anders aan de andere kant. Beide moeten gewone muurstukken zijn. Geeft [k, buur, middelpunt] of null.
static func gate_pair(k: Vector4i, toward: Vector3) -> Variant:
	var walls := existing()
	if not walls.has(k) or str(walls[k].get("kind", "")) != "kampmuur":
		return null
	var a := Vector2i(k.x, k.y)
	var b := Vector2i(k.z, k.w)
	var dir := b - a
	var cands: Array = [[edge_key(b, b + dir), b], [edge_key(a - dir, a), a]]
	if vertex(cands[1][1]).distance_to(toward) < vertex(cands[0][1]).distance_to(toward):
		cands.reverse()
	for c in cands:
		var nb: Variant = walls.get(c[0])
		if nb != null and str(nb.get("kind", "")) == "kampmuur":
			return [k, c[0], vertex(c[1])]
	return null


## Zet een poort op de plek van twee muurstukken naast elkaar. Geeft {ok, reason}.
static func place_gate(k: Vector4i, toward: Vector3) -> Dictionary:
	if not Game.mcv_deployed or Game.gates == null:
		return {"ok": false, "reason": "Klap eerst je wagen uit"}
	var pair: Variant = gate_pair(k, toward)
	if pair == null:
		return {"ok": false, "reason": "Een poort heeft twee muurstukken naast elkaar nodig"}
	if not Game.can_afford_build(GATE_COST):
		return {"ok": false, "reason": "Onvoldoende punten"}
	var walls := existing()
	var b1: Dictionary = walls[pair[0]]
	var b2: Dictionary = walls[pair[1]]
	Game.pay_build(GATE_COST)
	Game.builds.batch = true
	Game.builds.remove(b1)
	Game.builds.remove(b2)
	Game.builds.batch = false
	var gate: Dictionary = Game.gates.add_gate(pair[2], edge_yaw(pair[0]), pair[0], pair[1])
	clear_gate_lane(Vector3(gate.at), float(gate.yaw))
	Wachten.invalidate()
	Sfx.play("thud")
	check_enclosure()
	return {"ok": true, "reason": ""}


## Een poort ruimt de weg voor je voertuigen: bomen, stronken en rotsen vlak voor en achter de opening verdwijnen (zoals onder een gebouw), zodat een jeep of tank er nooit tegenaan blijft haken.
static func clear_gate_lane(at: Vector3, yaw: float) -> int:
	var half := Vector2(GATE_LANE_SIDE, GATE_LANE_ALONG)   # (langs de muur, door de poort)
	if absf(cos(yaw)) < 0.5:
		half = Vector2(half.y, half.x)
	return Foliage.clear_world_rects([Rect2(Vector2(at.x, at.z) - half, half * 2.0)], 0.0)


## Verkoopt een poort: de helft van de prijs als bouwtegoed; de plek blijft open.
static func sell_gate(g: Dictionary) -> void:
	Game.build_credit += GATE_COST / 2
	Game.gates.remove_gate(g)
	Wachten.invalidate()
	Sfx.play("buy")
