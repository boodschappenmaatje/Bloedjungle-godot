class_name VoertuigZoek
extends RefCounted
## Eén zoekactie van de routezoeker van je eigen jeep en tank (A* over `VoertuigRaster`): de weg van `from` naar `to` om bomen, rotsen, muren en gebouwen heen, door de poort van jouw kamp.
## De zoekactie rekent in stukjes (`step`, elk beeld hooguit een paar tienden milliseconde, samen met alle andere zoekacties 1,8 ms) zodat het spel op 60 beelden per seconde blijft.
## Daarna vlakt hij de route af (alleen hoekpunten waar het echt moet) en geeft `path`: de punten om langs te rijden, zonder het beginpunt.
##
## - `ok`: het doel is bereikt. `snapped`: het doel zelf lag in een dichte cel (een boom, een rots), de route eindigt bij de dichtstbijzijnde vrije plek.
## - `partial`: er is geen weg naar het doel (afgesloten plek, of te ver zoeken); de route eindigt zo dicht als hij kon komen.
## - Beide leeg (`path` leeg): geen vrije plek bij het begin of het doel; het voertuig rijdt dan rechtdoor, zoals voor de routezoeker.

const MAX_EXPAND := 6000         # zoveel cellen onderzoekt hij hooguit (daarna de beste tot nu toe)
const SNAP_START := 3            # cellen: zo ver zoekt hij een vrije plek bij het voertuig zelf
const SNAP_GOAL := 5             # en bij het doel
const SMOOTH_LOOK := 40          # cellen: zo ver kijkt de afvlakking vooruit
const DX := [1, -1, 0, 0, 1, 1, -1, -1]
const DY := [0, 0, 1, -1, 1, -1, 1, -1]
const COST := [2.5, 2.5, 2.5, 2.5, 3.5355, 3.5355, 3.5355, 3.5355]

var r: VoertuigRaster
var start_pos: Vector3
var goal_pos: Vector3
var done := false
var ok := false
var partial := false
var snapped := false
var path: Array = []
var expanded := 0
var micros := 0                  # totale rekentijd (µs), voor de test

var _stage := 0                  # 0 beginnen, 1 zoeken, 2 afvlakken
var _sx := 0
var _sy := 0
var _gx := 0
var _gy := 0
var _g := PackedFloat32Array()
var _came := PackedInt32Array()
var _closed := PackedByteArray()
var _hf := PackedFloat32Array()
var _hi := PackedInt32Array()
var _best := -1
var _best_h := INF
var _raw: Array = []
var _sm_a := 0
var _sm_out: Array = []


func _init(raster_: VoertuigRaster, from: Vector3, to: Vector3) -> void:
	r = raster_
	start_pos = from
	goal_pos = to


## Rekent een stukje (binnen het budget van dit beeld). Roep dit elk beeld aan tot `done`.
func step(space: PhysicsDirectSpaceState3D) -> void:
	if done:
		return
	var budget := VoertuigRaster.take()
	if budget <= 0:
		return
	var t0 := Time.get_ticks_usec()
	r.tick()
	if _stage == 0:
		_begin(space)
	if _stage == 1 and not done:
		_search(space, t0, budget)
	if _stage == 2 and not done:
		_smooth(space, t0, budget)
	var dt := Time.get_ticks_usec() - t0
	micros += dt
	VoertuigRaster.spent(dt)


## Rekent door tot hij klaar is (voor een test of een berekening buiten het spel).
func finish(space: PhysicsDirectSpaceState3D) -> void:
	var guard := 0
	while not done and guard < 100000:
		r.tick()
		var t0 := Time.get_ticks_usec()
		if _stage == 0:
			_begin(space)
		if _stage == 1 and not done:
			_search(space, t0, 1 << 60)
		if _stage == 2 and not done:
			_smooth(space, t0, 1 << 60)
		guard += 1


func _begin(space: PhysicsDirectSpaceState3D) -> void:
	var sc := r.cell_of(start_pos)
	var s := r.nearest_free(space, sc.x, sc.y, SNAP_START)
	if s.x < 0:
		_fail()
		return
	_sx = s.x
	_sy = s.y
	var gc := r.cell_of(goal_pos)
	var g := r.nearest_free(space, gc.x, gc.y, SNAP_GOAL)
	if g.x < 0:
		_gx = gc.x
		_gy = gc.y
		snapped = true   # geen vrije plek bij het doel: de beste benadering
	else:
		_gx = g.x
		_gy = g.y
		snapped = g != gc
	var n := VoertuigRaster.W * VoertuigRaster.H
	_g.resize(n)
	_g.fill(INF)
	_came.resize(n)
	_came.fill(-1)
	_closed.resize(n)
	_closed.fill(0)
	var si := _sy * VoertuigRaster.W + _sx
	_g[si] = 0.0
	_best = si
	_best_h = _h(_sx, _sy)
	_push(_best_h, si)
	_stage = 1


func _fail() -> void:
	path = []
	ok = false
	partial = false
	done = true


func _h(x: int, y: int) -> float:
	var dx := absi(x - _gx)
	var dy := absi(y - _gy)
	return VoertuigRaster.CELL * (float(maxi(dx, dy)) + 0.4142 * float(mini(dx, dy)))


@warning_ignore("integer_division")
func _search(space: PhysicsDirectSpaceState3D, t0: int, budget: int) -> void:
	var w := VoertuigRaster.W
	while true:
		if _hi.is_empty():
			_end_search(false)
			return
		var cur := _pop()
		if _closed[cur] == 1:
			continue
		_closed[cur] = 1
		var cx := cur % w
		var cy := cur / w
		if cx == _gx and cy == _gy:
			_end_search(true)
			return
		var gcur := _g[cur]
		for k in 8:
			var nx: int = cx + int(DX[k])
			var ny: int = cy + int(DY[k])
			var st := r.cell_state(space, nx, ny)
			if st == 2:
				continue
			if k >= 4 and not (r.is_open(space, nx, cy) and r.is_open(space, cx, ny)):
				continue   # niet schuin langs een hoek (een voertuig is breder dan een cel)
			var ni := ny * w + nx
			if _closed[ni] == 1:
				continue
			var ng: float = gcur + float(COST[k]) + (VoertuigRaster.SOFT_COST if st == 3 else 0.0)
			if ng < _g[ni]:
				_g[ni] = ng
				_came[ni] = cur
				var h := _h(nx, ny)
				_push(ng + h * 1.05, ni)   # een tikje gretig: sneller bij grote open stukken
				if h < _best_h:
					_best_h = h
					_best = ni
		expanded += 1
		if expanded >= MAX_EXPAND:
			_end_search(false)
			return
		if (expanded & 7) == 0 and Time.get_ticks_usec() - t0 > budget:
			return


@warning_ignore("integer_division")
func _end_search(reached: bool) -> void:
	var w := VoertuigRaster.W
	var end := _gy * w + _gx if reached else _best
	ok = reached
	partial = not reached
	var chain: Array = []
	var cur := end
	while cur >= 0:
		chain.append(cur)
		cur = _came[cur]
	chain.reverse()
	_raw = []
	for c in chain:
		_raw.append(r.center(int(c) % w, int(c) / w))
	_sm_a = 0
	_sm_out = []
	if _raw.size() <= 1:
		path = []
		done = true
		return
	_stage = 2


## Vlakt de route af: vanaf elk hoekpunt zoekt hij het verste punt waar hij in een rechte lijn heen kan rijden (met een binaire zoektocht, de lijn is zelf elke keer gecontroleerd).
func _smooth(space: PhysicsDirectSpaceState3D, t0: int, budget: int) -> void:
	var last := _raw.size() - 1
	while _sm_a < last:
		var hi := mini(_sm_a + SMOOTH_LOOK, last)
		var lo := _sm_a + 1
		if r.line_free(space, _raw[_sm_a], _raw[hi]):
			lo = hi
		else:
			var l := _sm_a + 1
			var h := hi - 1
			while l < h:
				var mid := (l + h + 1) >> 1
				if r.line_free(space, _raw[_sm_a], _raw[mid]):
					l = mid
				else:
					h = mid - 1
			lo = l
		_sm_out.append(_raw[lo])
		_sm_a = lo
		if Time.get_ticks_usec() - t0 > budget:
			break
	if _sm_a >= last:
		if ok and not snapped:
			_sm_out[_sm_out.size() - 1] = Vector3(goal_pos.x, 0.0, goal_pos.z)   # precies op het doel
		path = _sm_out
		done = true


# ---------------------------------------------------------------- stapel (kleinste eerst)

func _push(f: float, id: int) -> void:
	var n := _hf.size()
	_hf.append(f)
	_hi.append(id)
	while n > 0:
		var p := (n - 1) >> 1
		if _hf[p] <= f:
			break
		_hf[n] = _hf[p]
		_hi[n] = _hi[p]
		n = p
	_hf[n] = f
	_hi[n] = id


func _pop() -> int:
	var top := _hi[0]
	var n := _hf.size() - 1
	var f := _hf[n]
	var id := _hi[n]
	_hf.resize(n)
	_hi.resize(n)
	if n > 0:
		var i := 0
		while true:
			var c := 2 * i + 1
			if c >= n:
				break
			if c + 1 < n and _hf[c + 1] < _hf[c]:
				c += 1
			if _hf[c] >= f:
				break
			_hf[i] = _hf[c]
			_hi[i] = _hi[c]
			i = c
		_hf[i] = f
		_hi[i] = id
	return top
