extends Node3D
## Hoofdscène: pauze tussen golven, golven laten aanvallen en de bonus na een overleefde golf.
## Zoals 13-waves.js, 24-shop.js (waveCleared) en de hoofdlus in 26-main.js.

const ENEMY := preload("res://scenes/enemy.tscn")

var queue: Array = []
var spawn_t := 0.0
var clear_t := -1.0


func _ready() -> void:
	Progress.load_all()
	Game.reset()
	Game.defs = Defenses.new()
	add_child(Game.defs)
	Game.builds = Buildings.new()
	add_child(Game.builds)
	Game.gates = Gates.new()
	add_child(Game.gates)
	GameSettings.apply_hz()
	add_child(PerfGovernor.new())
	add_child(JungleGeluid.new())
	add_child(Wachtpost.new())
	add_child(Patrouille.new())
	add_child(Diagnose.new())
	Game.state = "menu"
	if Progress.autostart:
		Progress.autostart = false
		await _load_world()
		_start_prep()
	else:
		Game.changed.emit()
		for m in get_tree().get_nodes_in_group("menus"):
			m.show_menu()


## Start een missie vanuit het hoofdmenu. De wereld wordt pas nu gebouwd, achter het laadscherm.
func begin() -> void:
	await _load_world()
	Game.reset()
	if Game.player:
		Game.player.refresh_look()
	_start_prep()


## Bouwt de wereld (eenmalig) achter een laadscherm en tekent daarna alles één keer, zodat vuur, explosies en
## de eerste vijanden niet midden in een golf hapering geven.
func _load_world() -> void:
	var lvl: Node3D = $Level
	if lvl.get("built"):
		return
	var instant := DisplayServer.get_name() == "headless" or OS.has_environment("BJ_INSTANT")
	var screen := Loading.new()
	if not instant:
		add_child(screen)
		await get_tree().process_frame
	var progress := func(frac: float, text: String) -> void:
		screen.set_progress(frac, text)
	if instant:
		lvl.build_now()
	else:
		await lvl.build_stepped(progress)
		progress.call(0.82, "Alles klaarzetten...")
		await get_tree().process_frame
		await _warm_up()
		progress.call(1.0, "Klaar")
		await get_tree().process_frame
	PerfGovernor.grace_until = Time.get_ticks_msec() + 3000
	screen.queue_free()


## Zet één van alles kort in beeld (onder het laadscherm): modellen, vijandtypes, kogels en effecten.
func _warm_up() -> void:
	var warm := Node3D.new()
	add_child(warm)
	var base: Vector3 = Game.player.global_position if Game.player else Vector3(0, 0, 4)
	# Prime the shared grass shader/textures under the existing loading screen.
	# The base camera itself cannot see the exterior grass during normal warm-up.
	var grass := GrassField.preview("all")
	grass.position = base + Vector3(0, 0, -4)
	warm.add_child(grass)
	var n := 0
	for path in ["res://assets/soldaat.glb", "res://assets/soldaat_vq2.glb", "res://assets/klimmen.glb", "res://assets/kazerne.glb", "res://assets/garage.glb", "res://assets/helipad.glb", "res://assets/zwaailamp.glb", "res://assets/apache.glb", "res://assets/loopgraaf.glb", "res://assets/poort.glb", "res://assets/wachttoren.glb", "res://assets/vrachtwagen.glb", "res://assets/straaljager.glb"]:
		if not ResourceLoader.exists(path):
			continue
		var m: Node3D = (load(path) as PackedScene).instantiate()
		m.position = base + Vector3(-4.0 + n * 1.2, 0, -5.0)
		warm.add_child(m)
		var kind: String = path.get_file().get_basename()
		Kit.skin(m, kind)
		n += 1
	var i := 0
	for kind in Data.ETYPES:
		var e := ENEMY.instantiate()
		e.setup(kind, 1)
		e.position = base + Vector3(-3.0 + i * 2.0, 0, -9.0)
		warm.add_child(e)
		e.process_mode = Node.PROCESS_MODE_DISABLED
		Game.enemies.erase(e)
		i += 1
	var at: Vector3 = base + Vector3(0, 0, -7.0)
	Fx.explosion(warm, at, 1.0)
	Fx.muzzle(warm, at + Vector3.UP)
	Fx.blood(warm, at, Vector3.UP)
	Fx.dust(warm, at)
	Fx.impact(warm, at, Vector3.UP)
	Fx.ground_blood(warm, at)
	Fx.burning(warm, at + Vector3(2, 0, 0), true)
	Bullet.fire(warm, at + Vector3.UP, 0.0, 10.0, 0.0, 0.5, true)
	Bullet.fire_rocket(warm, at + Vector3(0, 1, 2), 0.0, 0.0, 0.4)
	Fx.flame(warm, at + Vector3(-2, 0, 0), 1.5, true)
	Fx.embers(warm, at + Vector3(-2, 0, 0))
	Fx.spark(warm, at, Vector3.UP)
	Fx.casing(warm, at + Vector3.UP)
	Fx.rocket_launch(warm, at + Vector3(1, 1, 0), 0.0)
	Fx.wreck(warm, at + Vector3(3, 0, 0))
	Fx.crater(warm, at + Vector3(0, 0, 2), 1.0, true)  # kraters krijgen hun eigen shader; in de basis zelf komt er geen
	# wrakken en brandende auto's/bussen (zwart wrakmateriaal, deuk-vorm): vroeger pas bij de eerste ontploffing
	var k := 0
	for v in [Auto.make("autowrak", 1), Auto.make("autobrand", 2), Bus.make("buswrak", 3)]:
		v.position = base + Vector3(-6.0 + k * 4.0, 0, -13.0)
		warm.add_child(v)
		v.process_mode = Node.PROCESS_MODE_DISABLED
		k += 1
	# puin van elk soort gebouw: rondvliegende brokken (MultiMesh) en een puinhoop
	var soorten := {}
	for h in Woonhuis.all:
		if is_instance_valid(h) and not soorten.has(h.kind):
			soorten[h.kind] = true
			h.warm_puin(warm, at + Vector3(-3.0 + soorten.size() * 1.5, 0, 1.5))
			h.warm_shapes()
	await _settle(8)
	warm.queue_free()
	Game.enemies.clear()


## Wacht tot Godot geen nieuwe shader-pipelines meer compileert (minstens min_frames beelden, hooguit ~4 s).
func _settle(min_frames: int) -> void:
	var last := -1
	var calm := 0
	for f in 240:
		await get_tree().process_frame
		var n := _pipeline_compiles()
		calm = calm + 1 if n == last else 0
		last = n
		if f >= min_frames and calm >= 4:
			return


static func _pipeline_compiles() -> int:
	var n := 0
	for k in [RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH, RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE,
			RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW, RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION]:
		n += RenderingServer.get_rendering_info(k)
	return n


func _start_prep() -> void:
	Barrel.populate(self)  # opgeblazen vaten komen elke golf terug
	Game.wave += 1
	Game.routes = AanvalRoutes.pick(Game.wave)  # de pijlen tonen al tijdens de pauze waar ze vandaan komen
	Game.state = "prep"
	Game.prep_t = GameSettings.prep_time()
	Game.changed.emit()


func start_wave() -> void:
	if Game.state != "prep":
		return
	PerfMonitor.note("golf %d begint" % Game.wave)
	Game.state = "play"
	Game.defs.refill()
	queue = Data.build_wave(Game.wave)
	spawn_t = 0.5
	clear_t = -1.0
	Game.banner.emit("GOLF %d BEGONNEN" % Game.wave, "Ze komen " + AanvalRoutes.describe(Game.routes), 1.5)
	Game.changed.emit()


func _process(delta: float) -> void:
	if Game.state == "prep" and not Game.build_mode:
		Game.prep_t -= delta
		if Game.prep_t <= 0.0:
			start_wave()
	elif Game.state == "play":
		if queue.size():
			spawn_t -= delta
			var max_alive := 22 + mini(18, Game.wave * 2)
			if spawn_t <= 0.0 and Game.enemies.size() < max_alive:
				_spawn(queue.pop_front())
				spawn_t = maxf(0.25, 1.2 - Game.wave * 0.06) * randf_range(0.6, 1.3)
		elif Game.enemies.is_empty():
			if clear_t < 0.0:
				clear_t = 1.6
			clear_t -= delta
			if clear_t <= 0.0:
				_wave_cleared()


func _spawn(kind: String) -> void:
	PerfMonitor.note("vijand gespawnd")
	var e := ENEMY.instantiate()
	e.setup(kind, Game.wave)
	if kind == "rocket" and not Game.rocket_seen:
		Game.rocket_seen = true
		Game.banner.emit("RAKETWERPERS", "Ze schieten je gebouwen kapot", 2.5)
	if Game.routes.is_empty():
		var a := randf() * TAU
		e.position = Vector3(cos(a), 0, sin(a)) * Data.SPAWN_R
	else:
		# elke vijand loopt een van de vaste routes van deze golf
		e.path = AanvalRoutes.path_for(Game.routes.pick_random())
		e.position = AanvalRoutes.spawn_at(e.path)
	add_child(e)


func _wave_cleared() -> void:
	var bonus := 150 + Game.wave * 60 + roundi(Game.base_hp / Game.base_max * 200.0)
	Game.add_points(bonus)
	Game.bonus = bonus
	var w := Game.wave
	Game.streak_reset()
	Progress.stats.bestWave = maxi(Progress.stats.bestWave, w)
	Progress.save()
	_start_prep()
	Game.banner.emit("GOLF %d OVERLEEFD" % w, "Bonus +%d" % bonus, 3.0)
