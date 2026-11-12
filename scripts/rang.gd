class_name Rang
extends RefCounted
## Generaalsrang met krachten (Generals-plan stap E1; Dennis' keuzes 1A 2A 3A 4A 5A 6A 7A 8A van 11 november 2026, plus Napalm als vierde kracht
## en geen killstreaks meer).
##
## Je score (Game.score: elke vijand levert er al een paar tientallen tot 300 op) bepaalt je rang: vijf sterren, de vijfde is Generaal. Elke ster is
## een punt (Game.rang_punten) dat je uitgeeft aan een nieuwe kracht of aan een upgrade (niveau 1 tot 3) van een kracht die je al hebt.
## Een kracht is herbruikbaar met een eigen afkoeltijd (Game.kracht_cd). De rang geldt per spel en blijft staan als je sneuvelt.
## Het artilleriecommando kan ook via het hoofdkwartier niveau 3 (keuze 5A): wie dat heeft, heeft artillerie op niveau 1.
## Staat in Game: rang, rang_punten, krachten, kracht_cd, kracht_sel, satelliet_t.

const GRENZEN := [600, 2000, 4500, 8000, 13000]     # score voor ster 1 tot 5 (voorstel: bijstellen na Dennis' test)
const NAMEN := ["SOLDAAT", "SERGEANT", "LUITENANT", "KAPITEIN", "MAJOOR", "GENERAAL"]
const MAX_NIVEAU := 3
const GERICHT := ["artillerie", "napalm", "luchtaanval", "parachutisten"]   # krachten met een richthulp (stick of slepen); satelliet en reparatie gaan meteen
const VOLGORDE := ["artillerie", "luchtaanval", "napalm", "satelliet", "reparatie", "parachutisten"]   # in het wiel (zes vakken van 60 graden, met de klok mee vanaf boven)

## Per kracht: naam, afkoeling per niveau (s) en de waarde die per niveau groeit.
const KRACHTEN := {
	"artillerie": {"naam": "ARTILLERIE", "cd": [90.0, 75.0, 60.0], "waarde": [5, 8, 12]},        # granaten
	"napalm": {"naam": "NAPALM", "cd": [120.0, 100.0, 80.0], "waarde": [10.0, 14.0, 18.0]},      # s dat de strook brandt
	"satelliet": {"naam": "SATELLIET", "cd": [120.0, 100.0, 80.0], "waarde": [20.0, 30.0, 45.0]}, # s dat alle vijanden op de kaart staan
	"reparatie": {"naam": "REPARATIE", "cd": [60.0, 50.0, 40.0], "waarde": [0.4, 0.7, 1.0]},      # deel dat wordt geheeld
	"luchtaanval": {"naam": "LUCHTAANVAL", "cd": [100.0, 85.0, 70.0], "waarde": [1, 1, 2]},       # P-47 toestellen (niveau 2: ook raketten; niveau 3: een tweede toestel)
	"parachutisten": {"naam": "PARACHUTISTEN", "cd": [150.0, 130.0, 110.0], "waarde": [4, 6, 8], "kort": "PARA'S"}, # soldaten die springen (E2)
}
const REPARATIE_STRAAL := [20.0, 28.0, 36.0]   # m rond jou

# De napalmstrook (het toestel, het vuur en de richthulp gebruiken deze maten).
const NAPALM_LENGTH := 20.0  # m lengte van de brandstrook
const NAPALM_WIDTH := 5.0    # m breed
const NAPALM_RANGE_MIN := 8.0
const NAPALM_RANGE_MAX := 30.0
const NAPALM_TAP := 14.0     # alleen tikken: zo ver recht vooruit

# Luchtaanval (E2, Dennis' keuzes 1C 2A 3A 4A 5A): P-47 duikt over een strook; mikken zoals napalm (strook, 8 tot 26 m).
const LUCHT_LENGTH := 30.0   # m lengte van de beschietingsstrook
const LUCHT_WIDTH := 6.0     # m breed
const LUCHT_STICK_MIN := 8.0
const LUCHT_STICK_MAX := 26.0
const LUCHT_RANGE_MIN := 8.0   # slepen vanaf de knop (computer)
const LUCHT_RANGE_MAX := 34.0
# Parachutisten (E2, keuzes 6A 7A 8A 9A): transportvliegtuig, soldaten landen verspreid binnen DROP_STRAAL rond het doel (artillerie-bereik 14 tot 26 m met de stick).
const DROP_STRAAL := 10.0
const DROP_SOORTEN := [
	["geweer", "geweer", "geweer", "geweer"],
	["geweer", "geweer", "geweer", "geweer", "geweer", "raket"],
	["geweer", "geweer", "geweer", "geweer", "raket", "sluipschutter", "hospik", "geweer"],
]


## Test: alle krachten op niveau 3 zonder afkoeling (instelling "Test: alle krachten").
static func test() -> bool:
	return GameSettings.get_value("t_krachten") == "on"


# ---------------------------------------------------------------- rang en punten

static func naam(r: int) -> String:
	return NAMEN[clampi(r, 0, NAMEN.size() - 1)]


## Rang (0 tot 5) bij een score.
static func voor_score(score: int) -> int:
	var r := 0
	for g in GRENZEN:
		if score >= int(g):
			r += 1
	return r


## Hoever je bent naar de volgende ster: {done, span, volgende}. Op de hoogste rang is de balk vol en volgende = -1.
static func voortgang() -> Dictionary:
	var r: int = Game.rang
	if r >= GRENZEN.size():
		return {"done": 1, "span": 1, "volgende": -1}
	var prev := 0 if r == 0 else int(GRENZEN[r - 1])
	var nxt := int(GRENZEN[r])
	return {"done": clampi(Game.score - prev, 0, nxt - prev), "span": nxt - prev, "volgende": nxt}


## Wordt aangeroepen als de score verandert (Game.add_score en add_points): bevordert zo vaak als nodig en geeft per ster een punt.
static func check() -> void:
	var nieuw := voor_score(Game.score)
	while Game.rang < nieuw:
		Game.rang += 1
		Game.rang_punten += 1
		Game.banner.emit("BEVORDERD TOT %s" % naam(Game.rang), "Rang %d van %d · tik op KIES voor een kracht" % [Game.rang, GRENZEN.size()], 3.2)
		Sfx.play("buy")
		Game.changed.emit()


# ---------------------------------------------------------------- krachten

## Niveau van een kracht zoals je hem hebt gekozen (0 = nog niet), mét het hoofdkwartier (artillerie vanaf HK niveau 3 is minstens niveau 1).
static func echt_niveau(id: String) -> int:
	var n := int(Game.krachten.get(id, 0))
	if id == "artillerie" and Game.hq_level >= 3:
		n = maxi(n, 1)
	return n


## Niveau waarmee de kracht nu werkt (in de test altijd het hoogste).
static func niveau(id: String) -> int:
	return MAX_NIVEAU if test() else echt_niveau(id)


static func heeft(id: String) -> bool:
	return niveau(id) > 0


## De krachten die je nu hebt, in de volgorde van het wiel.
static func beschikbaar() -> Array:
	var out := []
	for id in VOLGORDE:
		if heeft(id):
			out.append(id)
	return out


## De gekozen kracht van de knop: je keuze, of anders de eerste die je hebt ("" als je er geen hebt).
static func huidig() -> String:
	if heeft(Game.kracht_sel):
		return Game.kracht_sel
	var all := beschikbaar()
	return "" if all.is_empty() else String(all[0])


static func cd_rest(id: String) -> float:
	return 0.0 if test() else float(Game.kracht_cd.get(id, 0.0))


static func klaar(id: String) -> bool:
	return heeft(id) and cd_rest(id) <= 0.0


## Afkoeltijd (s) bij het huidige niveau.
static func afkoeling(id: String) -> float:
	return float(KRACHTEN[id].cd[clampi(niveau(id), 1, MAX_NIVEAU) - 1])


## Waarde van de kracht op een niveau (granaten, seconden vuur, seconden satelliet, deel geheeld).
static func waarde(id: String, n: int) -> Variant:
	return KRACHTEN[id].waarde[clampi(n, 1, MAX_NIVEAU) - 1]


## Wat een niveau doet, in een korte zin voor het kiesscherm en het wiel.
static func tekst(id: String, n: int) -> String:
	n = clampi(n, 1, MAX_NIVEAU)
	var cd := "%d s afkoeling" % roundi(float(KRACHTEN[id].cd[n - 1]))
	var w: Variant = waarde(id, n)
	match id:
		"artillerie":
			return "%d granaten, %s" % [int(w), cd]
		"napalm":
			return "strook van %d m, vuur %d s, %s" % [roundi(NAPALM_LENGTH), roundi(float(w)), cd]
		"satelliet":
			return "alle vijanden %d s op de kaart, %s" % [roundi(float(w)), cd]
		"luchtaanval":
			var extra := "" if n == 1 else (", raketten" if n == 2 else ", raketten en een tweede toestel")
			return "P-47 over een strook van %d m, mitrailleurs en 2 bommen%s, %s" % [roundi(LUCHT_LENGTH), extra, cd]
		"parachutisten":
			return "%d parachutisten springen bij je doel, %s" % [int(w), cd]
		_:
			return "heelt %d%% in %d m, %s" % [roundi(float(w) * 100.0), roundi(float(REPARATIE_STRAAL[n - 1])), cd]


static func start_cd(id: String) -> void:
	Game.kracht_cd[id] = afkoeling(id)


## Afkoeltijden lopen tijdens het spel (Game._process); ook de seconden van de satelliet.
static func tick(delta: float) -> void:
	for id in Game.kracht_cd.keys():
		var left := float(Game.kracht_cd[id]) - delta
		if left <= 0.0:
			Game.kracht_cd.erase(id)
		else:
			Game.kracht_cd[id] = left
	if Game.satelliet_t > 0.0:
		Game.satelliet_t = maxf(0.0, Game.satelliet_t - delta)


## Geeft een punt uit: een nieuwe kracht of een niveau hoger. Returns false als dat niet kan (geen punt of al niveau 3).
static func punt_uitgeven(id: String) -> bool:
	if Game.rang_punten <= 0 or not KRACHTEN.has(id) or echt_niveau(id) >= MAX_NIVEAU:
		return false
	var n := echt_niveau(id) + 1
	Game.krachten[id] = n
	Game.rang_punten -= 1
	if Game.kracht_sel == "" or not heeft(Game.kracht_sel):
		Game.kracht_sel = id
	Game.banner.emit("%s NIVEAU %d" % [String(KRACHTEN[id].naam), n], tekst(id, n), 2.2)
	Sfx.play("buy")
	Game.changed.emit()
	return true


## Voert een kracht uit en zet de afkoeling. at/dir: doel van artillerie en napalm. Returns false als hij niet klaar is.
static func gebruik(id: String, main: Node, at: Vector3, dir: Vector3) -> bool:
	if not klaar(id) or main == null or not is_instance_valid(main):
		return false
	var n := niveau(id)
	match id:
		"artillerie":
			Artillerie.call_in(main, at, int(waarde(id, n)))
		"napalm":
			var a := NapalmAanval.new()
			a.burn_time = float(waarde(id, n))
			main.add_child(a)
			a.start(at, dir)
		"satelliet":
			Game.satelliet_t = float(waarde(id, n))
			Game.banner.emit("SPIONAGESATELLIET", "Alle vijanden staan %d s op de kaart" % roundi(Game.satelliet_t), 2.4)
			Sfx.play("ping", 1.0)
		"reparatie":
			NoodReparatie.start(main, Game.player.global_position, n)
		"luchtaanval":
			LuchtAanval.start_aanval(main, at, dir, n)
		"parachutisten":
			Parachutisten.start_drop(main, at, n)
	start_cd(id)
	Game.krachten_gebruikt[id] = int(Game.krachten_gebruikt.get(id, 0)) + 1
	Game.changed.emit()
	return true


## Pictogram van een kracht (voor het wiel, de knop en het kiesscherm); c = midden, s = schaal (1 = wielgrootte).
static func teken_icoon(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color) -> void:
	var dark := Color(0.05, 0.06, 0.04, 0.9)
	match id:
		"artillerie":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -15) * s, c + Vector2(3.6, -9) * s, c + Vector2(3.6, -1) * s, c + Vector2(-3.6, -1) * s, c + Vector2(-3.6, -9) * s]), col)
			ci.draw_rect(Rect2(c + Vector2(-3.6, -1) * s, Vector2(7.2, 3.0) * s), dark)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-3.6, 2) * s, c + Vector2(3.6, 2) * s, c + Vector2(5.5, 6) * s, c + Vector2(-5.5, 6) * s]), col)
			for x in [-11.0, 0.0, 11.0]:
				ci.draw_arc(c + Vector2(x, 12) * s, 4.2 * s, PI, TAU, 8, col, 2.2 * s)
		"napalm":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -14) * s, c + Vector2(5, -6) * s, c + Vector2(10, 1) * s, c + Vector2(8, 8) * s, c + Vector2(0, 12) * s,
				c + Vector2(-8, 8) * s, c + Vector2(-10, 0) * s, c + Vector2(-5, -5) * s, c + Vector2(-3, -9) * s]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -2) * s, c + Vector2(4, 4) * s, c + Vector2(0, 9) * s, c + Vector2(-4, 4) * s]), dark)
		"satelliet":
			# een schotel met een zendarm en radiogolven
			ci.draw_arc(c + Vector2(-2, 2) * s, 9.0 * s, 0.35, 0.35 + PI * 1.05, 14, col, 3.0 * s, true)
			ci.draw_line(c + Vector2(-2, 2) * s, c + Vector2(7, -9) * s, col, 2.0 * s, true)
			ci.draw_circle(c + Vector2(8, -10) * s, 2.4 * s, col)
			ci.draw_line(c + Vector2(-2, 11) * s, c + Vector2(-2, 15) * s, col, 2.4 * s)
			ci.draw_line(c + Vector2(-8, 15) * s, c + Vector2(4, 15) * s, col, 2.4 * s)
			ci.draw_arc(c + Vector2(8, -10) * s, 6.0 * s, -0.2, 1.4, 6, col, 1.6 * s, true)
			ci.draw_arc(c + Vector2(8, -10) * s, 10.0 * s, -0.2, 1.4, 8, col, 1.4 * s, true)
		"reparatie":
			# een dik kruis in een ring
			ci.draw_arc(c, 13.0 * s, 0.0, TAU, 24, col, 2.0 * s, true)
			ci.draw_rect(Rect2(c + Vector2(-3.5, -9) * s, Vector2(7, 18) * s), col)
			ci.draw_rect(Rect2(c + Vector2(-9, -3.5) * s, Vector2(18, 7) * s), col)
		"luchtaanval":
			# jager van boven: romp, vleugels, staartvlak en de cirkel van de propeller
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -13) * s, c + Vector2(3, -8) * s, c + Vector2(3, 8) * s, c + Vector2(0, 13) * s, c + Vector2(-3, 8) * s, c + Vector2(-3, -8) * s]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-14, -1) * s, c + Vector2(-3, -4) * s, c + Vector2(-3, 2) * s, c + Vector2(-14, 2) * s]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(14, -1) * s, c + Vector2(3, -4) * s, c + Vector2(3, 2) * s, c + Vector2(14, 2) * s]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 10) * s, c + Vector2(-2, 7) * s, c + Vector2(-2, 11) * s, c + Vector2(-6, 12) * s]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(6, 10) * s, c + Vector2(2, 7) * s, c + Vector2(2, 11) * s, c + Vector2(6, 12) * s]), col)
			ci.draw_arc(c + Vector2(0, -14) * s, 6.0 * s, PI * 1.15, PI * 1.85, 6, col, 1.6 * s)
		"parachutisten":
			# koepel met lijnen naar een springer
			ci.draw_arc(c + Vector2(0, -2) * s, 12.0 * s, PI, TAU, 14, col, 3.0 * s, true)
			ci.draw_line(c + Vector2(-12, -2) * s, c + Vector2(0, 11) * s, col, 1.4 * s, true)
			ci.draw_line(c + Vector2(12, -2) * s, c + Vector2(0, 11) * s, col, 1.4 * s, true)
			ci.draw_line(c + Vector2(-4, -12) * s, c + Vector2(0, 11) * s, col, 1.2 * s, true)
			ci.draw_line(c + Vector2(4, -12) * s, c + Vector2(0, 11) * s, col, 1.2 * s, true)
			ci.draw_circle(c + Vector2(0, 13) * s, 2.4 * s, col)
		"ster":
			ci.draw_colored_polygon(ster_punten(c, 12.0 * s, 5.0 * s), col)


## Vijfpuntige ster (voor de knop, het kiesscherm en de rangbalk).
static func ster_punten(c: Vector2, r_buiten: float, r_binnen: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + float(i) * PI / 5.0
		var r := r_buiten if i % 2 == 0 else r_binnen
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts
