extends Node3D
## Hoofdscène: pauze tussen golven, golven laten aanvallen en de bonus na een overleefde golf.
## Zoals 13-waves.js, 24-shop.js (waveCleared) en de hoofdlus in 26-main.js.

const ENEMY := preload("res://scenes/enemy.tscn")

var queue: Array = []
var spawn_t := 0.0
var clear_t := -1.0


func _ready() -> void:
	Game.reset()
	_start_prep()


func _start_prep() -> void:
	Game.wave += 1
	Game.state = "prep"
	Game.prep_t = GameSettings.prep_time()
	Game.changed.emit()


func start_wave() -> void:
	if Game.state != "prep":
		return
	Game.state = "play"
	queue = Data.build_wave(Game.wave)
	spawn_t = 0.5
	clear_t = -1.0
	Game.banner.emit("GOLF %d" % Game.wave, "Ze komen eraan", 1.5)
	Game.changed.emit()


func _process(delta: float) -> void:
	if Game.state == "prep":
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
	var e := ENEMY.instantiate()
	e.setup(kind, Game.wave)
	var a := randf() * TAU
	e.position = Vector3(cos(a), 0, sin(a)) * Data.SPAWN_R
	add_child(e)


func _wave_cleared() -> void:
	var bonus := 150 + Game.wave * 60 + roundi(Game.base_hp / Game.base_max * 200.0)
	Game.add_points(bonus)
	Game.bonus = bonus
	var w := Game.wave
	_start_prep()
	Game.banner.emit("GOLF %d OVERLEEFD" % w, "Bonus +%d" % bonus, 3.0)
