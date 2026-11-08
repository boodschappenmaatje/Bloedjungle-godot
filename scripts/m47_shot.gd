class_name M47Shot
extends RefCounted
## Eén schot van het M-47 Muurbreker in het spel: bepaalt waar de plasmaschacht inslaat, speelt het M47Vfx-effect af en
## laat op het inslagmoment een zware ontploffing los die muren, huizen, bouwwerken, voertuigen en vijanden raakt.
## Speler-eigen bouwwerken krijgen net als bij de bazooka maar een klein deel van de schade (Buildings.blast own = true).

const RANGE := 26.0
const MASK := Bullet.MASK_WALL | Bullet.MASK_BUNKER | Bullet.MASK_FORTIFICATION | Bullet.MASK_VEHICLE | Bullet.MASK_NATURE
const ENEMY_HIT_R := 0.8

static var _pool: Array[M47Vfx] = []


static func fire(parent: Node3D, from: Vector3, face: float, dmg: float, radius: float) -> void:
	var dir := Vector3(sin(face), 0.0, cos(face))
	var at := _impact_point(parent, from, dir)
	var vfx := _vfx(parent)
	vfx.fire(from, at, null)
	vfx.impact.connect(func(pos: Vector3) -> void: _blast(pos, radius, dmg), CONNECT_ONE_SHOT)


static func _vfx(parent: Node3D) -> M47Vfx:
	_pool = _pool.filter(func(v: M47Vfx) -> bool: return is_instance_valid(v))
	for v in _pool:
		if v.is_idle():
			return v
	var v := M47Vfx.new()
	parent.add_child(v)
	_pool.append(v)
	return v


## Eerste muur/voertuig/boom op de baan, of een vijand die er vlak langs staat; anders het einde van het bereik.
static func _impact_point(parent: Node3D, from: Vector3, dir: Vector3) -> Vector3:
	var end := from + dir * RANGE
	var q := PhysicsRayQueryParameters3D.create(from, end, MASK)
	var hit := parent.get_world_3d().direct_space_state.intersect_ray(q)
	var at: Vector3 = hit.position if not hit.is_empty() else end
	var best := from.distance_to(at)
	for e in Game.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var rel: Vector3 = e.global_position - from
		var along := rel.dot(dir)
		if along < 0.5 or along > best:
			continue
		var side := Vector2(rel.x - dir.x * along, rel.z - dir.z * along).length()
		if side < ENEMY_HIT_R:
			best = along
			at = from + dir * along
	return at


static func _blast(at: Vector3, r: float, dmg: float) -> void:
	Game.note_blast(at, r)
	Barrel.catch_blast(at, r)
	VijandHk.blast(at, r, dmg)
	VijandM2Toren.blast(at, r, dmg)
	VijandBasis.blast(at, r, dmg)   # muur van de vijandelijke basis: stukken breken weg
	if Game.builds:
		Game.builds.blast(at, r, dmg, true)   # inclusief Woonhuis.blast_all: huizen en muren gaan stuk
		_kampmuren(at, r)
	if Game.gates:
		for i in Game.gates.list.size():
			var g: Dictionary = Game.gates.list[i]
			var gd: float = maxf(0.0, Vector2(Game.gates.pos_of(g).x - at.x, Game.gates.pos_of(g).z - at.z).length() - Data.GATE_GAP)
			if not g.broken and gd < r:
				Game.gates.damage(i, dmg * 3.0 * (1.0 - gd / r), "explosive")
	for e in Game.enemies.duplicate():
		if is_instance_valid(e) and not e.dead:
			var d: float = e.global_position.distance_to(at)
			if d < r and not BaseWallRules.blocks_blast(at, e.global_position):
				e.hit(dmg * (1.0 - d / r * 0.7), (e.global_position - at).normalized(), true)


## Eigen kampmuren (bouwstukken van 1500 sterkte): het M-47 breekt ze veel sneller dan een gewone ontploffing (die doet maar de helft).
## Alles binnen ongeveer de halve straal gaat in één schot weg, dus ook je eigen basismuur kan kapot.
static func _kampmuren(at: Vector3, r: float) -> void:
	for b in Game.buildings.duplicate():
		if b.kind != "kampmuur" or b.down or not is_instance_valid(b.node):
			continue
		var d: float = maxf(0.0, Vector2(b.at.x - at.x, b.at.z - at.z).length() - Kampmuur.STEP * 0.5)
		if d < r:
			Game.builds.damage(b, 3000.0 * (1.0 - d / r))
