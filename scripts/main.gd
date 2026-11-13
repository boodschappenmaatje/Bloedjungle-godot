extends Node3D
## Hoofdscène: laadt de wereld en laat de vijand aanvalsgroepen sturen (stap 5a-2: geen golven meer). Na GROEP_RUST seconden rust komt de
## eerste groep uit de poort van de vijandbasis, daarna elke GROEP_TUSSEN seconden een nieuwe, ook als de vorige nog loopt. Is er geen groep
## meer onderweg, dan is het weer "prep" (wapenkamer en stadseditor); het aftellen loopt gewoon door. Bouwen kan altijd, ook in "play".
## Winnen: het vijandelijke hoofdkwartier slopen (VijandHk); verliezen: jouw hoofdkwartier (Game.damage_base).

const ENEMY := preload("res://scenes/enemy.tscn")

var queue: Array = []   # wachtende vijanden van alle groepen: {"kind", "n" (groepnummer), "routes"}
var spawn_t := 0.0
var clear_t := -1.0


func _ready() -> void:
	Progress.load_all()
	Game.reset()
	Game.defs = Defenses.new()
	add_child(Game.defs)
	Game.builds = Buildings.new()
	add_child(Game.builds)
	Game.supply = Voorraad.new()
	add_child(Game.supply)
	Game.gates = Gates.new()
	add_child(Game.gates)
	add_child(AanvalAI.new())   # slimme vijandaanval: één brein voor alle aanvalsgroepen (keuzes 1A-10A)
	GameSettings.apply_hz()
	add_child(PerfGovernor.new())
	add_child(JungleGeluid.new())
	add_child(Diagnose.new())
	Game.state = "menu"
	if Progress.autostart:
		Progress.autostart = false
		await _load_world()
		_start_world()
		_start_prep()
	else:
		Game.changed.emit()
		for m in get_tree().get_nodes_in_group("menus"):
			m.show_menu()


## Start een missie vanuit het hoofdmenu. De wereld wordt pas nu gebouwd, achter het laadscherm.
func begin() -> void:
	await _load_world()
	# Instellingen opnieuw toepassen nu de jungle er staat: Atmosphere deed dit al bij het opstarten, maar toen bestond het gras
	# nog niet (minder gras en geen palmschaduw tot je in Instellingen wisselde, v225).
	var atm := get_tree().get_first_node_in_group("atmosphere")
	if atm != null:
		atm.apply_settings()
	Game.reset()
	if Game.player:
		Game.player.refresh_look()
	_start_world()
	_start_prep()


## Zet de start van een nieuw spel neer. Oude spel: het eerste depot met een gratis truck en de eerste voorraadstapels in het vaste kamp.
## MCV-start: geen vast kamp; je zit in de bouwwagen op de open plek en kiest zelf waar het hoofdkwartier komt (mcv.gd).
## Depot, truck en voorraadstapels volgen in een volgende stap (Generals-plan, "Stap MCV").
func _start_world() -> void:
	for n in get_tree().get_nodes_in_group("mcv"):
		n.queue_free()
	for n in get_tree().get_nodes_in_group("mcv_wagen"):
		n.queue_free()   # de geparkeerde bouwwagen van een vorig spel
	for n in get_tree().get_nodes_in_group("mcv_hq"):
		n.queue_free()   # het hoofdkwartier van een vorig spel
	Garnizoen.start_game()   # F2: de vijand bezet zijn vier gebouwen in de stad (7A)
	Game.supply.start_game()   # MCV-start: alleen de voorraadstapels; het depot is gratis maar zet je zelf neer
	var mcv := Mcv.new()
	mcv.position = Mcv.START_POS
	add_child(mcv)
	if Data.mcv_autodeploy:
		mcv.global_position = Vector3.ZERO
		mcv.rotation.y = 0.0
		mcv.deploy_now()
		Game.state = "prep"
		return
	var p = Game.player
	if p != null and is_instance_valid(p):
		p.global_position = Vector3(Mcv.START_POS.x, 0.0, Mcv.START_POS.z)
		p.home = p.global_position


## Bouwt de wereld (eenmalig) achter een laadscherm en tekent daarna alles één keer, zodat vuur, explosies en
## de eerste vijanden niet midden in een golf hapering geven.
func _load_world() -> void:
	var lvl: Node3D = $Level
	if lvl.get("built"):
		return
	var instant := DisplayServer.get_name() == "headless" or OS.has_environment("BJ_INSTANT")
	if not instant and not Engine.is_editor_hint():
		Data.randomize_world_seed()   # wereld per start (W1): nieuwe jungle-seed, eenmaal per spelsessie; headless/tests/editor blijven op Data.WORLD_SEED_DEFAULT
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
		# Do not prime legacy enemies while the Meshy-only mode is selected.
		if GameSettings.get_value("enemy_models") == "meshy" and kind != "assault":
			continue
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
	Barrel.populate(self)  # opgeblazen vaten komen terug
	queue.clear()
	Game.wave = maxi(0, Progress.test_groep - 1)   # testoptie: de eerste groep die uitrukt is dan groep test_groep
	Game.next_routes = AanvalRoutes.pick_group(Game.wave + 1)
	Game.routes = Game.next_routes.duplicate()  # de pijlen tonen al tijdens de rust waar de eerste groep vandaan komt
	if AanvalAI.aan and AanvalAI.ik != null:
		AanvalAI.ik.reset()
		Game.next_routes = []   # 9A: de kant zie je pas bij contact, niet meer tijdens het aftellen
		Game.routes = []
	Game.state = "prep"
	Game.prep_t = Progress.eerste_rust()
	clear_t = -1.0
	Game.changed.emit()
	if Progress.test_groep > 0:
		Game.banner.emit("TEST · START BIJ GROEP %d" % Progress.test_groep, PauseMenu.groep_inhoud(Progress.test_groep), 3.0)


## De volgende aanvalsgroep komt nu uit de poort van de vijandbasis ("Start nu", of het aftellen is op).
func start_wave() -> void:
	if Game.state != "prep":
		return
	_launch_group()


func _launch_group() -> void:
	Game.wave += 1
	PerfMonitor.note("groep %d begint" % Game.wave)
	Game.state = "play"
	Game.defs.refill()
	var routes: Array = Game.next_routes.duplicate()
	if routes.is_empty():
		routes = AanvalRoutes.pick_group(Game.wave)
	var was_leeg := queue.is_empty()
	var slim := AanvalAI.aan and AanvalAI.ik != null
	if slim:
		queue.append_array(AanvalAI.ik.nieuwe_groep(Game.wave, Data.build_group(Game.wave)))
	else:
		for kind in Data.build_group(Game.wave):
			queue.append({"kind": kind, "n": Game.wave, "routes": routes})
	# voertuigen (Dennis, keuze 1B): ze rukken uit voor de soldaten, en rijden hun eigen weg (AanvalRoutes.voertuig_pad)
	var voertuigen := Data.groep_voertuigen(Game.wave)
	for i in voertuigen.size():
		queue.insert(i, {"kind": voertuigen[i], "n": Game.wave, "voertuig": true})
	if was_leeg:
		spawn_t = 0.5   # de enige wachtende groep: de eerste vijand komt snel
	clear_t = -1.0
	Game.routes = routes
	Game.next_routes = AanvalRoutes.pick_group(Game.wave + 1)
	Game.prep_t = Data.GROEP_TUSSEN
	if slim:
		Game.routes = []
		Game.next_routes = []
		Game.banner.emit("GROEP %d ONDERWEG" % Game.wave, "Kant onbekend · torens, soldaten en de satelliet verkennen", 1.5)
	else:
		Game.banner.emit("GROEP %d ONDERWEG" % Game.wave, "Ze komen " + AanvalRoutes.describe(routes), 1.5)
	Game.changed.emit()


func _process(delta: float) -> void:
	if Game.state == "prep" or Game.state == "play":
		# het aftellen naar de volgende groep loopt altijd door, behalve zolang het bouwscherm open is
		# MCV-start: de klok van de eerste groep staat stil tot de wagen is uitgeklapt
		if not (Game.state == "prep" and Game.build_mode) and Game.mcv_deployed:
			Game.prep_t -= delta
			if Game.prep_t <= 0.0:
				_launch_group()
	if Game.state == "play":
		if queue.size():
			spawn_t -= delta
			var max_alive := 22 + mini(18, Game.wave * 2)
			var volgend: Variant = queue[0]
			var wacht_op_plek: bool = volgend is Dictionary and volgend.get("voertuig", false) and get_tree().get_nodes_in_group("vijand_voertuig").size() >= Data.VOERTUIG_MAX
			if wacht_op_plek and queue.size() > 1:
				queue.push_back(queue.pop_front())   # er rijden al drie voertuigen: de soldaten gaan voor, het voertuig wacht achteraan
			elif spawn_t <= 0.0 and Game.enemies.size() < max_alive and not wacht_op_plek:
				_spawn(queue.pop_front())
				spawn_t = maxf(0.25, 1.2 - Game.wave * 0.06) * randf_range(0.6, 1.3)
				if queue.is_empty() and not AanvalAI.aan:
					Game.routes = Game.next_routes.duplicate()   # alles is uitgerukt: de pijlen wijzen al naar de volgende groep
		elif Game.enemies.is_empty():
			if clear_t < 0.0:
				clear_t = 1.6
			clear_t -= delta
			if clear_t <= 0.0:
				_wave_cleared()


## Eén vijand uit de wachtrij laten uitrukken. Een kale soort ("rocket") mag ook (tests): dan gelden de routes van nu.
func _spawn(item: Variant) -> void:
	PerfMonitor.note("vijand gespawnd")
	if item is Dictionary and item.get("voertuig", false):
		_spawn_voertuig(item)
		return
	var entry: Dictionary = item if item is Dictionary else {"kind": String(item), "n": maxi(1, Game.wave), "routes": Game.routes if not Game.routes.is_empty() else AanvalRoutes.pick_group(1)}
	# Resolve again at spawn time: the setting may change while a group
	# is already queued. Never leave old, invisible attackers in the world.
	var kind: String = "assault" if GameSettings.get_value("enemy_models") == "meshy" else str(entry.kind)
	if kind == "assault" and GameSettings.get_value("enemy_models") == "meshy":
		var assault_path := SoldierModel.SCENE_ASSAULT_MODEL_PATH
		if not ResourceLoader.exists(assault_path) or ResourceLoader.load(assault_path) == null:
			push_error("Alleen Meshy: Assault-model ontbreekt; vijand niet gespawnd")
			Game.banner.emit("MESHY-MODEL ONTBREEKT", "Controleer de OTA-update en herstart het spel", 3.0)
			return
	var e := ENEMY.instantiate()
	e.setup(kind, int(entry.n))
	if kind == "rocket" and not Game.rocket_seen:
		Game.rocket_seen = true
		Game.banner.emit("RAKETWERPERS", "Ze schieten je gebouwen kapot", 2.5)
	# elke vijand komt uit de poort van de vijandbasis en loopt een van de vaste stadsroutes van zijn groep
	e.position = VijandBasis.spawn_point()
	if entry.has("groep") and AanvalAI.ik != null:
		add_child(e)
		AanvalAI.ik.lid_erbij(entry.groep, e)   # het groepsbrein geeft hem zijn pad, zijn plek in de waaier en zijn kant
		return
	var routes: Array = entry.get("routes", [])
	if routes.is_empty():
		routes = AanvalRoutes.pick_group(1)
	e.path = AanvalRoutes.path_from_base(routes.pick_random())
	add_child(e)


## Een vijandelijk voertuig rijdt uit de poort van de vijandbasis: de weg staat in AanvalRoutes.voertuig_pad. De jeep (stap V1) rijdt snel en schiet met zijn MG,
## de tank (stap V2) rijdt langzaam, stopt op afstand van het eerste doel en beschiet het met granaten.
func _spawn_voertuig(entry: Dictionary) -> void:
	var tank: bool = str(entry.kind) == "tank"
	var v: Node3D = VijandTank.make(AanvalRoutes.voertuig_pad(true), int(entry.n)) if tank else VijandJeep.make(AanvalRoutes.voertuig_pad(), int(entry.n))
	v.position = VijandBasis.gate_inside() + Vector3(0.0, 0.0, -2.0)
	v.rotation.y = PI   # met de neus naar de poort (zuid)
	add_child(v)
	if AanvalAI.ik != null:
		AanvalAI.ik.voertuig_erbij(int(entry.n), v)   # fase 3: de groep wacht op hem
	Game.banner.emit("VIJANDELIJKE TANK ONDERWEG" if tank else "VIJANDELIJKE JEEP ONDERWEG", "Hij rijdt door de stad naar je basis" if not tank else "Hij belegert alles binnen 38 m met granaten", 2.0)
	if Game.builds != null and Game.builds.radio != null:
		Game.builds.radio.say("voertuig_onderweg")   # Dennis neemt de zin nog op; zonder opname blijft het stil


## 7A najagen: een ploeg van `n` man rukt meteen uit naar een kant van jouw kamp die net is weggevallen (AanvalAI._check_najagen).
func ploeg_uitsturen(g: Dictionary, n: int) -> void:
	if Game.state not in ["prep", "play"]:
		return
	for i in n:
		var e := ENEMY.instantiate()
		e.setup("assault", maxi(1, Game.wave))
		e.position = VijandBasis.spawn_point() + Vector3(i * 1.2, 0.0, 0.0)
		add_child(e)
		g.leden.append(e)
		g.start += 1
		e.ai_groep = g
		e.ai_kant = g.kant
		e.path = AanvalAI.ik.najaag_pad(g)
	Game.state = "play"
	Game.changed.emit()


## Applied by the Settings toggle, including while the mission is paused.
## Existing legacy enemies leave the combat list and are freed, never merely
## hidden while continuing to collide, shoot or damage the player.
func apply_enemy_model_filter() -> void:
	if GameSettings.get_value("enemy_models") != "meshy":
		return
	for item in queue:
		if item is Dictionary and not item.get("voertuig", false):
			item["kind"] = "assault"
	for enemy in Game.enemies.duplicate():
		if not is_instance_valid(enemy) or str(enemy.get("type")) == "assault" or enemy.is_in_group("vijand_voertuig"):
			continue
		Game.enemies.erase(enemy)
		enemy.visible = false
		enemy.set_process(false)
		enemy.set_physics_process(false)
		enemy.queue_free()


## Alle vijanden van de groepen zijn uitgeschakeld: weer "prep" (wapenkamer en stadseditor) tot de volgende groep uitrukt. Bouwen kan ook tijdens een groep.
func _wave_cleared() -> void:
	Game.state = "prep"
	clear_t = -1.0
	Game.routes = Game.next_routes.duplicate()
	Barrel.populate(self)  # opgeblazen vaten komen terug
	if Progress.test_groep == 0:   # een testspel (start bij groep N) telt niet mee als "beste groep"
		Progress.stats.bestWave = maxi(Progress.stats.bestWave, Game.wave)
		Progress.save()
	Game.banner.emit("GROEP %d AFGESLAGEN" % Game.wave, "Volgende groep over %d s" % ceili(maxf(Game.prep_t, 0.0)), 3.0)
	Game.changed.emit()
