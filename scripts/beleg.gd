class_name Beleg
extends RefCounted
## Het beleg van de vijandbasis zonder jou erbij (Generals-plan stap 5a-3a, keuze B van Dennis, 4 nov): soldaten die op hun plek voor het HK
## staan terwijl jij ver weg bent (onzichtbaar, zie Ally._is_far) vechten niet echt maar worden hier uitgerekend, één keer per seconde:
##  - elke soldaat beschadigt het HK (Ally.dmg x TREFFERS treffers per seconde; het HK laat 10% van kogelschade door, zoals altijd);
##  - de basis schiet terug: TORENVUUR schade per seconde per wachttoren van de vijandbasis op de soldaat met de minste levenspunten,
##    zodat ze één voor één sneuvelen (focus op de zwakste). Die soldaat is dan echt weg (en kan in de kazerne opnieuw worden opgeleid);
##  - meldingen: leger aangekomen, soldaat gesneuveld, leger verslagen.
## Zodra jij binnen 55 m komt, zijn ze weer echt en rekent dit niet meer (de basis heeft nog geen echte schutters).
## VOORLOPIG: de verdediging is nu een vast bedrag per wachttoren; stap 5a-3b (garnizoen en schietende MG-torens) vervangt dat door wat er echt
## nog staat en schiet.

const TREFFERS := 1.0     # treffers per soldaat per seconde (echt schieten 2 kogels per seconde; zonder richten telt de helft)
const TORENVUUR := 1.25   # schade per seconde per wachttoren aan het leger (4 torens: 5 per seconde, een soldaat van niveau 3 sneuvelt in 26 s)
const STIL := 3.0         # s zonder tikken: het beleg is voorbij (iedereen weg, dood of weer echt)
const MELDING_PAUZE := 5.0   # s tussen twee meldingen over gesneuvelden

static var vuur_factor := 1.0   # voor tests: 0 = de basis schiet niet terug
static var aantal := 0          # soldaten die nu beleggen (laatste tik)
static var verloren := 0        # soldaten die het beleg al kostte
static var _vorige := -1.0e9    # speltijd van de laatste tik
static var _gemeld := false     # "leger aangekomen" is al gemeld voor dit beleg
static var _melding_t := -1.0e9


## Speltijd in seconden (natuurkundige stappen), zodat het ook klopt in tests die sneller dan de klok lopen.
static func nu() -> float:
	return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)


## Loopt er een beleg (een tik in de laatste paar seconden met minstens één soldaat)? Voor de radar.
static func actief() -> bool:
	return aantal > 0 and nu() - _vorige < STIL


## Elke belegeraar roept dit aan bij elke stap; de rekensom zelf draait hooguit één keer per seconde.
static func step(tree: SceneTree) -> void:
	var t := nu()
	if t - _vorige > STIL:
		_vorige = t   # begin van een beleg: pas vanaf nu tellen
		_gemeld = false
		return
	if t - _vorige < 1.0:
		return
	var dt := minf(t - _vorige, 2.0)
	_vorige = t
	if Game.state != "play" and Game.state != "prep":
		return
	var siege: Array = []
	for a in Game.allies:
		if is_instance_valid(a) and a.beleg_bezig():
			siege.append(a)
	aantal = siege.size()
	if siege.is_empty():
		return
	if not _gemeld:
		_gemeld = true
		Game.banner.emit("LEGER BIJ DE VIJANDBASIS", "%d soldaten beschieten het HK. Kom erbij om te helpen." % siege.size(), 3.0)
	var hk := VijandHk.inst
	if hk != null and is_instance_valid(hk) and not hk.down:
		var raw := 0.0
		for a in siege:
			raw += float(a.dmg) * TREFFERS
		hk.damage(raw * dt, "bullet")
		if hk.down:
			return   # gesloopt: het spel is gewonnen
	var torens := 0
	for tower in tree.get_nodes_in_group("vijand_toren"):
		if tower is VijandM2Toren and tower.operational():
			torens += 1
	var schade := float(torens) * TORENVUUR * vuur_factor * dt
	if schade <= 0.0:
		return
	var zwakste = siege[0]
	for a in siege:
		if float(a.hp) < float(zwakste.hp):
			zwakste = a
	zwakste.hp -= schade
	if zwakste.hp <= 0.0:
		_sneuvel(zwakste, siege.size() - 1, hk, t)


static func _sneuvel(a, over: int, hk: VijandHk, t: float) -> void:
	verloren += 1
	Game.allies.erase(a)
	a.queue_free()
	aantal = over
	var pct := roundi(100.0 * hk.hp / VijandHk.HP) if hk != null and is_instance_valid(hk) else 0
	if over <= 0:
		Game.banner.emit("LEGER VERSLAGEN", "Je soldaten bij de vijandbasis zijn gesneuveld. Het HK staat nog op %d%%." % pct, 3.5)
		_melding_t = t
	elif t - _melding_t >= MELDING_PAUZE:
		Game.banner.emit("SOLDAAT GESNEUVELD", "Nog %d bij de vijandbasis. Het HK staat op %d%%." % [over, pct], 2.5)
		_melding_t = t
	Game.changed.emit()
