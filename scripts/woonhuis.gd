class_name Woonhuis
extends Node3D
## Gebouwen in de stad achter de brug, gemaakt in Blender (bron/woonhuis, bron/winkel, bron/kerk, bron/benzine, bron/magazijn). Eén script voor alle
## soorten: de maten, trappen en sloopregels staan per soort in _spec().
## Je kunt naar binnen: het dak verdwijnt, en ook de verdiepingen boven je, en de muren aan de camerakant
## gaan weg zodat je jezelf ziet. Trappen brengen je naar boven (hoogte via floor_at, zoals de toren met elev).
## Alles kan kapot: elk muurstuk (M0*, M1*, M2*, P*, S*, T_*) gaat van heel naar kapot naar weg, met puin als dekking.
## Vallen er genoeg muurstukken van een laag weg, dan zakken de verdiepingen erboven in; bij de winkel stort
## het hele gebouw in (de 'Ruine' uit het model komt ervoor in de plaats). De kerk heeft twee delen die elk apart
## instorten: de toren en het schip ('parts', met elk een eigen ruïne). Bij het benzinestation zijn dat het winkeltje en de
## luifel (kolommen K*); de pompen en olievaten (XPomp*, XVat*) ontploffen (pomp.gd).
## Lokale maten (Godot): voorkant (deur) aan +Z. Trappen en gaten in Blender-y (b = -z).

const STAIR_LIFT := 1.0
const HP := {"M": 320.0, "P": 160.0, "T": 140.0}


## Per soort: model, vloerhoogtes, grondvlak, trappen [x0, x1, b0 (onder), b1 (boven), van laag, naar laag],
## trapgaten [laag, x0, x1, b0, b1], balkon [x0, x1, z0, z1, laag], botsvlakken [midden, maat, (deel)],
## instorten: regels {pre, need} met "fall" (laag waarvanaf alles inzakt) of "ruin" ("all" of een deel uit "parts").
## Optioneel: "foot" (grondvlak als rechthoeken [x0, x1, z0, z1]), "floor_rects" (waar een verdieping vloer heeft),
## "hp" (levens per soort muurstuk), "roof_pre"/"roof_need" (welke muren het dak dragen), "roof_levels" (tot welke
## laag het dak weggaat als je binnen bent), "covers" (knooppunt dat weggaat als je eronder staat, met de rechthoek).
static func _spec(kind: String) -> Dictionary:
	if kind == "kerk":
		return _spec_kerk()
	if kind == "benzine":
		return _spec_benzine()
	if kind == "hotel":
		return _spec_hotel()
	if kind == "magazijn":
		return _spec_magazijn()
	if kind == "winkel":
		var f0 := 0.3
		var f1 := 3.8
		var f2 := 6.8
		return {
			"glb": "res://assets/winkel.glb", "levels": [f0, f1, f2], "hx": 4.5, "hz": 4.0,
			"groups": ["Begane", "Verdieping", "Verdieping2"],
			"stairs": [[-4.25, -3.25, -1.4, 2.6, 0, 1], [-3.25, -2.25, 2.6, -1.4, 1, 2]],
			"holes": [[1, -4.3, -3.2, -1.0, 2.6], [2, -3.3, -2.2, -1.4, 2.2]],
			"balcony": [-1.15, 1.15, 3.95, 4.95, 1],
			"guards": [
				# trap A: wang aan de winkelkant; muurtje tussen trap A en B (boven vloer 1, ook reling boven)
				[Vector3(-3.19, (f0 + f1) * 0.5 - 0.1, -0.85), Vector3(0.1, f1 - f0 - 0.2, 3.5)],
				[Vector3(-3.2, (f1 + f2 + 1.0) * 0.5, -0.6), Vector3(0.1, f2 + 1.0 - f1, 4.0)],
				# trap B: wang aan de kamerkant en de dichte kant onder het bovenste bordes
				[Vector3(-2.19, (f1 + f2 - 0.2) * 0.5, -0.35), Vector3(0.1, f2 - f1 - 0.2, 3.5)],
				[Vector3(-2.75, (f1 + f2 - 0.2) * 0.5, 1.46), Vector3(1.0, f2 - f1 - 0.2, 0.1)],
				# reling trapgat vloer 1 (voorkant) en vloer 2 (oost en achter)
				[Vector3(-3.75, f1 + 0.55, 1.03), Vector3(1.0, 1.1, 0.1)],
				[Vector3(-2.19, f2 + 0.55, -0.4), Vector3(0.1, 1.1, 3.6)],
				[Vector3(-2.75, f2 + 0.55, -2.23), Vector3(1.1, 1.1, 0.1)],
				# balkonhek
				[Vector3(0.0, f1 + 0.55, 4.88), Vector3(2.2, 1.1, 0.1)],
				[Vector3(-1.08, f1 + 0.55, 4.45), Vector3(0.1, 1.1, 0.9)],
				[Vector3(1.08, f1 + 0.55, 4.45), Vector3(0.1, 1.1, 0.9)],
			],
			"doors": ["DeurVoor", "DeurAchter", "DeurBinnen0", "DeurBinnen1", "DeurBinnen2"],
			"collapse": [{"pre": "M0", "need": 5, "ruin": "all"}, {"pre": "M1", "need": 5, "fall": 2}], "ruin": true,
			"ruin_boxes": [[Vector3(0, 0.8, 0), Vector3(8.4, 1.6, 7.4)], [Vector3(0, 1.9, 0.2), Vector3(5.6, 1.4, 5.0)]],
			"roof_y": 8.0, "roof_r": 5.5, "roof_c": Vector3(-0.6, 9.9, 0.8),
			"fall_piles": [[Vector3(2.0, f0, -0.5), 1.15], [Vector3(-0.8, f0, 1.4), 1.0], [Vector3(1.0, f0, 2.0), 1.0]],
			"near": 10.0, "banner": "WINKEL INGESTORT",
		}
	var f0 := 0.3
	var f1 := 3.2
	return {
		"glb": "res://assets/woonhuis.glb", "levels": [f0, f1], "hx": 4.0, "hz": 3.5,
		"groups": ["Begane", "Verdieping"],
		"stairs": [[-3.75, -2.75, -1.8, 2.25, 0, 1]],
		"holes": [[1, -3.85, -2.65, -1.2, 2.25]],
		"balcony": [-0.15, 2.15, 3.45, 4.5, 1],
		"guards": [
			# trapwang aan de kamerkant en de achterkant van de trap onder de overloop
			[Vector3(-2.69, (f0 + f1) * 0.5 - 0.1, -(-1.8 + 0.5 + 2.25) * 0.5), Vector3(0.1, f1 - f0 - 0.2, 2.25 + 1.8 - 0.5)],
			[Vector3(-3.25, f0 + 1.3, -2.31), Vector3(1.0, 2.0, 0.1)],
			# reling boven
			[Vector3(-2.69, f1 + 0.55, -(-1.2 + 2.25) * 0.5), Vector3(0.1, 1.1, 2.25 + 1.2)],
			[Vector3(-3.25, f1 + 0.55, 1.24), Vector3(1.1, 1.1, 0.1)],
			# balkonhek (balkon x -0.1..2.1, z 3.5..4.45)
			[Vector3(1.0, f1 + 0.55, 4.45), Vector3(2.2, 1.1, 0.1)],
			[Vector3(-0.08, f1 + 0.55, 3.97), Vector3(0.1, 1.1, 0.95)],
			[Vector3(2.08, f1 + 0.55, 3.97), Vector3(0.1, 1.1, 0.95)],
		],
		"doors": ["DeurVoor", "DeurAchter", "DeurBinnen0", "DeurBinnen1"],
		"collapse": [{"pre": "M0", "need": 6, "fall": 1}], "ruin": false, "ruin_boxes": [],
		"roof_y": 4.0, "roof_r": 5.0, "roof_c": Vector3(0, 7.0, 0),
		"fall_piles": [[Vector3(2.2, f0, -0.5), 1.15], [Vector3(-1.0, f0, -1.5), 1.0]],
		"near": 9.0, "banner": "HUIS INGESTORT",
	}


## Oude kerk: schip (x -4,75..4,75, z -9,5..4,5) met de toren ervoor (x -2,5..2,5, z 4,5..9,5, deur aan +Z).
## Toren: vloeren 0,3 / 3,9 / 7,5 / 11,1 (ingang, uurwerk, klokkenkamer, torendak met kantelen). Trap A en C langs de
## westmuur naar achter, trap B langs de oostmuur naar voor. De toren en het schip storten elk apart in.
static func _spec_kerk() -> Dictionary:
	var f := [0.3, 3.9, 7.5, 11.1]
	var rail := 1.1   # hoogte van de relingen rond de trapgaten
	return {
		"glb": "res://assets/kerk.glb", "levels": f, "hx": 4.75, "hz": 9.5,
		"foot": [[-2.5, 2.5, 4.5, 9.5], [-4.75, 4.75, -9.5, 4.5]],
		"floor_rects": {1: [-2.0, 2.0, 5.0, 9.0], 2: [-2.0, 2.0, 5.0, 9.0], 3: [-2.15, 2.15, 4.85, 9.15]},
		"groups": ["Begane", "Toren1", "Toren2", "Toren3"],
		"stairs": [[-2.0, -0.7, -9.0, -6.0, 0, 1], [0.7, 2.0, -5.0, -8.0, 1, 2], [-2.0, -0.7, -9.0, -6.0, 2, 3]],
		"holes": [[1, -2.0, -0.7, -8.6, -6.0], [2, 0.7, 2.0, -8.0, -6.2], [3, -2.0, -0.7, -8.6, -6.0]],
		# alleen waar de trap dicht is: ver van de voet en de top, zodat je er zijwaarts opstapt (een muurdikte + straal van de rand)
		"guards": [
			[Vector3(-0.7, 2.0, 6.5), Vector3(0.1, 3.4, 1.0), "Toren"],   # trapA, kamerkant
			[Vector3(0.7, f[1] + 1.7, 7.4), Vector3(0.1, 3.4, 1.2), "Toren"],   # trap B, bovenste deel
		],
		"doors": ["DeurVoorL", "DeurVoorR", "DeurZij"],
		"hp": {"M": 650.0, "S": 420.0, "P": 500.0},
		# twee van de drie torenmuren beneden weg: de toren valt; twee muren van een hogere laag: de rest erboven breekt af;
		# vijf muren van het schip: het schip stort in (het dak valt al na drie)
		"collapse": [{"pre": "M0", "need": 2, "ruin": "Toren"}, {"pre": "M1", "need": 2, "fall": 2},
			{"pre": "M2", "need": 2, "fall": 3}, {"pre": "S0", "need": 5, "ruin": "Schip"}],
		"ruin": false, "ruin_boxes": [],
		"parts": {
			"Toren": {"node": "RuineToren", "rect": [-2.5, 2.5, 4.5, 9.5], "hide": ["TorenVoet", "Toren1", "Toren2", "Toren3"],
				"pre": ["M", "P"], "fall": 1, "roof": 1, "exit": Vector3(4.2, 0.0, 11.0), "banner": "KERKTOREN INGESTORT",
				"boxes": [[Vector3(0, 1.1, 7.0), Vector3(5.0, 2.2, 5.0)], [Vector3(0.5, 0.45, 10.8), Vector3(3.8, 0.9, 2.4)]]},
			"Schip": {"node": "RuineSchip", "rect": [-4.75, 4.75, -9.5, 4.5], "hide": ["Schip", "Dak"],
				"pre": ["S"], "exit": Vector3(6.8, 0.0, -1.0), "banner": "KERK INGESTORT",
				"boxes": [[Vector3(0, 0.9, 0.8), Vector3(8.6, 1.8, 6.4)], [Vector3(0, 0.8, -5.0), Vector3(8.6, 1.6, 7.0)]]},
		},
		"roof_pre": "S0", "roof_need": 3, "roof_levels": 0,
		"roof_y": 6.0, "roof_r": 7.5, "roof_c": Vector3(0, 10.5, -2.5), "roof_pile": Vector3(0.0, 0.3, -2.0),
		"fall_roof": false, "fall_c": Vector3(0, 0, 7.0), "fall_r": Vector2(2.5, 2.5), "fall_banner": "TOREN BREEKT AF",
		# y < 0: op de vloer onder het stuk dat afbreekt
		"fall_piles": [[Vector3(0.3, -1.0, 6.6), 0.85], [Vector3(3.4, 0.0, 10.4), 0.9]],
		"near": 14.0, "banner": "KERK INGESTORT",
	}


## Benzinestation: winkeltje (x -3,5..3,5, z -5,2..0, één laag, plat dak) met de luifel ervoor (x -4,8..4,8, z 0,3..5,4) op
## vier kolommen K0..K3, en twee pompeilanden met elk twee pompen. Het winkeltje en de luifel storten elk apart in.
static func _spec_benzine() -> Dictionary:
	var f0 := 0.2
	return {
		"glb": "res://assets/benzine.glb", "levels": [f0], "hx": 4.8, "hz": 5.4,
		"foot": [[-3.5, 3.5, -5.2, 0.0]],
		"groups": ["Begane"],
		"stairs": [], "holes": [],
		"guards": [
			# toonbank, de rekken en de koeling in het winkeltje
			[Vector3(2.05, f0 + 0.5, -1.9), Vector3(0.7, 1.0, 2.0), "Winkel"],
			[Vector3(-0.6, f0 + 0.8, -2.22), Vector3(2.0, 1.6, 0.95), "Winkel"],
			[Vector3(-3.0, f0 + 1.0, -1.6), Vector3(0.5, 2.0, 2.0), "Winkel"],
			[Vector3(0.9, f0 + 0.95, -3.45), Vector3(1.2, 1.9, 0.6), "Winkel"],
			# pompeilanden
			[Vector3(-1.6, 0.1, 2.85), Vector3(0.9, 0.2, 3.1)],
			[Vector3(1.6, 0.1, 2.85), Vector3(0.9, 0.2, 3.1)],
		],
		"doors": ["DeurVoor", "DeurAchter", "DeurBinnen0"],
		"hp": {"M": 300.0, "P": 160.0, "K": 260.0},
		# twee kolommen weg: de luifel klapt in; vijf muren van het winkeltje weg: het winkeltje stort in (het dak valt na vier)
		"collapse": [{"pre": "K", "need": 2, "ruin": "Luifel"}, {"pre": "M0", "need": 5, "ruin": "Winkel"}],
		"ruin": false, "ruin_boxes": [],
		"parts": {
			"Winkel": {"node": "RuineWinkel", "rect": [-3.5, 3.5, -5.2, 0.0], "hide": ["Begane", "Dak"],
				"pre": ["M", "P"], "exit": Vector3(0.0, 0.0, 1.6), "banner": "BENZINESTATION INGESTORT",
				"boxes": [[Vector3(0, 0.75, -2.6), Vector3(6.8, 1.5, 5.0)]]},
			"Luifel": {"node": "RuineLuifel", "rect": [-4.8, 4.8, 0.3, 5.4], "hide": ["Luifel"],
				"pre": ["K"], "exit": Vector3(0.0, 0.0, 7.0), "banner": "LUIFEL INGESTORT",
				"boxes": [[Vector3(-3.3, 0.55, 2.85), Vector3(3.6, 1.1, 4.4)], [Vector3(3.3, 0.55, 2.85), Vector3(3.6, 1.1, 4.4)]]},
		},
		"covers": [["LuifelDak", [-4.8, 4.8, 0.3, 5.4]]],
		"roof_y": 3.0, "roof_r": 4.5, "roof_c": Vector3(0, 3.6, -2.6), "roof_pile": Vector3(0.5, f0, -2.4),
		"fall_piles": [],
		"near": 9.0, "banner": "BENZINESTATION INGESTORT",
	}


## Hotel: vier lagen (lobby met balie en bar, drie verdiepingen met elk vier kamers), 10 x 9 m, plat dak met reclame. Bordestrap langs de
## westmuur: A (lobby naar 1) en C (2 naar 3) lopen naar achter, B (1 naar 2) ernaast terug naar voor. Muren M0..M3 per laag, kamerwanden P1a..P3c.
static func _spec_hotel() -> Dictionary:
	var f0 := 0.3
	var f1 := 3.8
	var f2 := 6.8
	var f3 := 9.8
	return {
		"glb": "res://assets/hotel.glb", "levels": [f0, f1, f2, f3], "hx": 5.0, "hz": 4.5,
		"groups": ["Begane", "Verdieping", "Verdieping2", "Verdieping3"],
		"stairs": [[-4.75, -3.75, -1.4, 2.6, 0, 1], [-3.75, -2.75, 2.6, -1.4, 1, 2], [-4.75, -3.75, -1.4, 2.6, 2, 3]],
		"holes": [[1, -4.8, -3.7, -1.0, 2.6], [2, -3.8, -2.7, -1.4, 2.2], [3, -4.8, -3.7, -1.0, 2.6]],
		"balcony": [-1.15, 1.15, 4.45, 5.4, 1],
		"guards": [
			# trap A: wang aan de kant van trap B; muurtje tussen A en B (boven vloer 1)
			[Vector3(-3.74, (f0 + f1) * 0.5 - 0.1, -0.85), Vector3(0.03, f1 - f0 - 0.2, 3.5)],
			[Vector3(-3.74, (f1 + f2 + 1.0) * 0.5, -0.6), Vector3(0.03, f2 + 1.0 - f1, 4.0)],
			# trap B: wang aan de kamerkant en de dichte kant onder het bovenste bordes
			[Vector3(-2.69, (f1 + f2 - 0.2) * 0.5, -0.35), Vector3(0.1, f2 - f1 - 0.2, 3.5)],
			[Vector3(-3.25, (f1 + f2 - 0.2) * 0.5, 1.46), Vector3(1.0, f2 - f1 - 0.2, 0.1)],
			# reling trapgat vloer 1 (voorkant) en vloer 2 (oost en achter)
			[Vector3(-4.25, f1 + 0.55, 1.03), Vector3(1.0, 1.1, 0.1)],
			[Vector3(-2.69, f2 + 0.55, -0.4), Vector3(0.1, 1.1, 3.6)],
			[Vector3(-3.25, f2 + 0.55, -2.23), Vector3(1.1, 1.1, 0.1)],
			# trap C: wang, muurtje tussen B en C, reling trapgat vloer 3 (voor en oost)
			[Vector3(-3.74, (f2 + f3) * 0.5 - 0.1, -0.85), Vector3(0.03, f3 - f2 - 0.2, 3.5)],
			[Vector3(-3.74, (f2 + f3 + 1.0) * 0.5, -0.6), Vector3(0.03, f3 + 1.0 - f2, 4.0)],
			[Vector3(-4.25, f3 + 0.55, 1.03), Vector3(1.0, 1.1, 0.1)],
			[Vector3(-3.69, f3 + 0.55, -0.8), Vector3(0.1, 1.1, 3.6)],
			# balkonhek
			[Vector3(0.0, f1 + 0.55, 5.38), Vector3(2.2, 1.1, 0.1)],
			[Vector3(-1.08, f1 + 0.55, 4.95), Vector3(0.1, 1.1, 0.9)],
			[Vector3(1.08, f1 + 0.55, 4.95), Vector3(0.1, 1.1, 0.9)],
		],
		"doors": ["DeurVoor", "DeurAchter", "DeurBinnen0",
			"DeurBinnen1a", "DeurBinnen1b", "DeurBinnen1c", "DeurBinnen1d", "DeurBinnen2a", "DeurBinnen2b", "DeurBinnen2c", "DeurBinnen2d",
			"DeurBinnen3a", "DeurBinnen3b", "DeurBinnen3c", "DeurBinnen3d"],
		"hp": {"M": 360.0, "P": 160.0},
		# zes muren van de lobby weg: alles stort in; vijf muren van een verdieping: alles erboven zakt in
		"collapse": [{"pre": "M0", "need": 6, "ruin": "all"}, {"pre": "M1", "need": 5, "fall": 2}, {"pre": "M2", "need": 5, "fall": 3}],
		"ruin": true,
		"ruin_boxes": [[Vector3(0, 0.9, 0), Vector3(9.6, 1.8, 8.4)], [Vector3(0, 2.1, 0.2), Vector3(6.4, 1.6, 5.6)]],
		"roof_y": 11.0, "roof_r": 6.5, "roof_c": Vector3(-0.6, 12.9, 0.8),
		"fall_piles": [[Vector3(2.4, f0, -0.5), 1.2], [Vector3(-0.8, f0, 1.4), 1.0], [Vector3(1.0, f0, 2.0), 1.0]],
		"near": 11.0, "banner": "HOTEL INGESTORT",
	}


## Militair bevoorradingsmagazijn: één open vloer, een brede dubbele deur en een zijdeur.
## Twee lange stellingen geven dekking; de middenbaan blijft vrij voor speler en vijanden.
static func _spec_magazijn() -> Dictionary:
	var f0 := 0.21
	return {
		"glb": "res://assets/magazijn.glb", "levels": [f0], "hx": 6.0, "hz": 4.0,
		"groups": ["Begane"],
		"stairs": [], "holes": [],
		"guards": [
			[Vector3(-4.25, 1.55, 0.0), Vector3(1.32, 2.9, 5.15)],
			[Vector3(4.25, 1.55, 0.0), Vector3(1.32, 2.9, 5.15)],
			[Vector3(-2.15, 0.82, -2.45), Vector3(0.98, 1.3, 0.86)],
			[Vector3(2.15, 0.82, -2.45), Vector3(0.98, 1.3, 0.86)],
			[Vector3(-2.15, 0.82, 2.45), Vector3(0.98, 1.3, 0.86)],
			[Vector3(2.15, 0.82, 2.45), Vector3(0.98, 1.3, 0.86)],
			[Vector3(-2.6, 0.55, -3.0), Vector3(0.78, 1.1, 0.78)],
			[Vector3(2.6, 0.55, -3.0), Vector3(0.78, 1.1, 0.78)],
			[Vector3(-2.7, 0.55, 3.15), Vector3(0.78, 1.1, 0.78)],
			[Vector3(2.7, 0.55, 3.15), Vector3(0.78, 1.1, 0.78)],
		],
		"doors": ["DeurVoorL", "DeurVoorR", "DeurZij"],
		"collapse": [{"pre": "M0", "need": 12, "ruin": "all"}],
		"ruin": true,
		"ruin_boxes": [
			[Vector3(0.0, 0.48, -0.4), Vector3(10.0, 0.96, 6.0)],
			[Vector3(-3.1, 0.82, 1.8), Vector3(3.6, 1.64, 2.1)],
			[Vector3(3.0, 0.72, -2.0), Vector3(3.2, 1.44, 2.2)],
		],
		"roof_pre": "M0", "roof_need": 5, "roof_levels": 0,
		"roof_y": 5.3, "roof_r": 7.3, "roof_c": Vector3(0.0, 5.2, 0.0),
		"roof_pile": Vector3(4.2, f0, -0.9),
		"fall_piles": [[Vector3(-2.2, f0, -0.7), 0.95], [Vector3(2.1, f0, 1.0), 1.0]],
		"near": 9.0, "banner": "MAGAZIJN INGESTORT",
	}


static var all: Array = []

var kind := "woonhuis"
var spec: Dictionary
var levels: Array
var model: Node3D
var segs: Array = []        # {name, node, heel, kapot, body, shape_heel, shape_kapot, hp, max, staat, out, floor}
var doors: Array = []       # {node, closed, t}
var _dak: Node3D
var _dak_heel: Node3D
var _dak_kapot: Node3D
var _ver: Node3D           # eerste verdieping (Verdieping)
var _groups: Array = []     # Begane, Verdieping, (Verdieping2): per laag
var _puin: Dictionary = {}
var _collapsed := false     # er is iets ingestort
var _fall := 99             # laagste laag die is ingestort
var _ruin := false          # het hele gebouw ligt plat
var _ruined: Dictionary = {}  # delen (kerk: "Toren", "Schip") die al zijn ingestort
var _gone: Array = []       # knooppunten die met een ingestort deel zijn verdwenen
var _guard_body: StaticBody3D
var _guard_bodies: Dictionary = {}   # per deel ("" = het hele gebouw)
var _inside := -1           # -1 buiten, anders de laag waarop je staat
var _hidden: Array = []     # muurstukken die nu voor de camera weg zijn
var pumps: Array = []       # pompen en olievaten (benzinestation)
var _covers: Array = []     # [knooppunt, rechthoek]: gaat weg als je eronder staat (luifel)
var _meubels: Array = []    # {body, group, level}: botsvormen van de inrichting (zie _furniture)


## Zet een huis neer in de wereld (Level), yaw in radialen.
static func place(parent: Node3D, at: Vector3, yaw := 0.0, soort := "woonhuis") -> Woonhuis:
	var h := Woonhuis.new()
	h.kind = soort
	h.position = at
	h.rotation.y = yaw
	parent.add_child(h)
	return h


func _ready() -> void:
	all.append(self)
	add_to_group("huis")
	add_to_group(kind)
	spec = _spec(kind)
	levels = spec.levels
	model = (load(spec.glb) as PackedScene).instantiate()
	add_child(model)
	for l in model.find_children("*", "Light3D", true, false):
		l.visible = false   # lampen pas 's nachts (scheelt op de iPhone)
	_dak = model.find_child("Dak", true, false)
	_ver = model.find_child("Verdieping", true, false)
	for g in spec.groups:
		_groups.append(model.find_child(g, true, false))
	var ruine: Node3D = model.find_child("Ruine", true, false)
	if ruine:
		ruine.visible = false
	var puin: Node3D = model.find_child("Puin", true, false)
	for c in puin.get_children():
		_puin[c.name] = c
	puin.visible = false
	for n in model.find_children("*", "Node3D", true, false):
		var heel := n.get_node_or_null(NodePath(String(n.name) + "_heel")) as MeshInstance3D
		var kapot := n.get_node_or_null(NodePath(String(n.name) + "_kapot")) as MeshInstance3D
		if heel == null or kapot == null:
			continue
		kapot.visible = false
		if n.name == "Dak":
			_dak_heel = heel
			_dak_kapot = kapot
			continue
		if String(n.name).begins_with("Vloer"):
			continue
		if String(n.name).begins_with("X"):
			pumps.append(Pomp.attach(self, n, heel, kapot))
			continue
		_add_seg(n, heel, kapot)
	for c in spec.get("covers", []):
		var cn: Node3D = model.find_child(c[0], true, false)
		if cn:
			_covers.append([cn, c[1]])
	for nm in spec.doors:
		var d: Node3D = model.find_child(nm, true, false)
		if d:
			var closed := d.rotation.z if kind == "magazijn" else d.rotation.y
			doors.append({"node": d, "closed": closed, "t": 0.0})
	_guards()
	_furniture()


func _exit_tree() -> void:
	all.erase(self)


func _add_seg(n: Node3D, heel: MeshInstance3D, kapot: MeshInstance3D) -> void:
	var body := HouseBody.new()
	body.collision_layer = Kit.LAYER_WALL
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh_heel := _wall_shape(heel)
	cs.shape = sh_heel
	body.add_child(cs)
	heel.add_child(body)
	var kind := String(n.name).substr(0, 1)
	var hp: float = spec.get("hp", {}).get(kind, HP.get(kind, 200.0))
	var s := {"name": String(n.name), "node": n, "heel": heel, "kapot": kapot, "body": body, "cs": cs,
		"shape_heel": sh_heel, "shape_kapot": null, "hp": hp, "max": hp, "staat": 0,
		"floor": _seg_floor(String(n.name))}
	body.house = self
	body.seg = s
	segs.append(s)


## Laag van een muurstuk: M1V0 en P1 horen bij laag 1, S0* (kerkschip) en T_* (tuin) bij 0.
static func _seg_floor(nm: String) -> int:
	if nm.length() > 1 and (nm[0] == "M" or nm[0] == "P" or nm[0] == "S") and nm[1].is_valid_int():
		return int(nm[1])
	return 0


## Botsvorm van alleen het metselwerk (pleister/binnen/baksteen): kozijnen, luiken en vensterbanken zitten niet in de weg.
func _wall_shape(mi: MeshInstance3D) -> Shape3D:
	var src := mi.mesh
	var keep := ArrayMesh.new()
	for i in src.get_surface_count():
		var m := src.surface_get_material(i)
		if m and m.resource_name in ["Pleister", "Binnen", "Baksteen", "Steen"]:
			keep.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(i))
	if keep.get_surface_count() == 0:
		return src.create_trimesh_shape()
	return keep.create_trimesh_shape()


## Extra botsvlakken: trapwangen, relingen rond de trapgaten en het balkonhek. Per deel een eigen body, zodat ze
## meegaan als dat deel instort (derde waarde = deel).
func _guards() -> void:
	for g in spec.guards:
		var part: String = g[2] if g.size() > 2 else ""
		if not _guard_bodies.has(part):
			var b := StaticBody3D.new()
			b.collision_layer = Kit.LAYER_WALL
			b.collision_mask = 0
			b.set_meta("nocam", true)   # relingen en trapwangen zijn binnen: de camera kijkt er doorheen
			add_child(b)
			_guard_bodies[part] = b
		_box(_guard_bodies[part], g[0], g[1])
	_guard_body = _guard_bodies.get("")


## Meubels zijn massief: van elk knooppunt "Inrichting*" in het model (de samengevoegde meubels van een laag) wordt elk los
## voorwerp een botsblok, zodat je er niet doorheen loopt. Nieuwe gebouwen krijgen dit vanzelf zolang het meubilair in een mesh
## "Inrichting<laag>" onder de groep van die laag zit. Een voorwerp is een groep driehoeken die dezelfde hoekpunten delen.
## Niet massief: platte dingen op de vloer (kleden), dingen die hoger beginnen dan je lang bent (lampen, ventilators) en piepkleine
## dingen (poten, flessen, spijlen).
const FURN_MIN_AREA := 0.012     # m2 grondvlak
const FURN_MIN_TOP := 0.06       # m: lager dan dit boven de vloer = kleed
const FURN_MAX_BOTTOM := 1.6     # m: begint het hoger boven de vloer, dan loop je eronderdoor


func _furniture() -> void:
	var holder := Node3D.new()
	holder.name = "Meubels"
	add_child(holder)
	var zones := _door_zones()
	for mi: MeshInstance3D in model.find_children("Inrichting*", "MeshInstance3D", true, false):
		var group := String(mi.get_parent().name)
		var gi: int = spec.groups.find(group)
		var level: float = levels[gi] if gi >= 0 else levels[0]
		var body := StaticBody3D.new()
		body.collision_layer = Kit.LAYER_WALL
		body.collision_mask = 0
		body.set_meta("nocam", true)   # meubels zijn binnen: de camera kijkt er doorheen
		holder.add_child(body)
		var n := 0
		for bb: AABB in _objects(mi):
			if bb.end.y - level < FURN_MIN_TOP or bb.position.y - level > FURN_MAX_BOTTOM or bb.size.x * bb.size.z < FURN_MIN_AREA:
				continue
			if _in_doorway(bb, zones):
				continue
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = bb.size
			cs.shape = sh
			cs.position = bb.get_center()
			body.add_child(cs)
			n += 1
		if n == 0:
			body.queue_free()
		else:
			_meubels.append({"body": body, "group": group, "level": maxi(gi, 0)})


## Voor elke deur een strook van de breedte van de opening en 0,6 m aan weerszijden, en de trappen zelf: daar mag geen meubel staan,
## anders kom je niet meer door de deur of de trap op. Meubels die erin vallen, krijgen geen botsblok. Gemeten in de ruimte van dit gebouw (xz-rechthoek + hoogte).
func _door_zones() -> Array:
	var zones: Array = []
	for nm: String in spec.doors:
		var d: Node3D = model.find_child(nm, true, false)
		if d == null:
			continue
		var xf := global_transform.affine_inverse() * d.global_transform
		var a := xf * Vector3(0.0, 0.0, -0.6)
		var b := xf * Vector3(0.94, 0.0, 0.6)
		var r := Rect2(Vector2(minf(a.x, b.x), minf(a.z, b.z)), Vector2(absf(b.x - a.x), absf(b.z - a.z)))
		zones.append([r, xf.origin.y, xf.origin.y + 1.8])
	# trappen: wat in de trap of tegen de wang staat (trapmuurtjes en dergelijke) heeft een eigen botsvlak in "guards"
	for st in spec.stairs:
		var z0 := minf(-st[2], -st[3])
		var z1 := maxf(-st[2], -st[3])
		zones.append([Rect2(Vector2(st[0] - 0.1, z0 - 0.1), Vector2(st[1] - st[0] + 0.2, z1 - z0 + 0.2)), levels[st[4]], levels[st[5]] + 1.8])
	return zones


func _in_doorway(bb: AABB, zones: Array) -> bool:
	var r := Rect2(Vector2(bb.position.x, bb.position.z), Vector2(bb.size.x, bb.size.z))
	for z in zones:
		if r.intersects(z[0]) and bb.end.y > z[1] and bb.position.y < z[2]:
			return true
	return false


## De losse voorwerpen van een mesh als AABB's in de ruimte van dit gebouw.
func _objects(mi: MeshInstance3D) -> Array:
	var xf := global_transform.affine_inverse() * mi.global_transform
	var parent := {}   # hoekpunt -> ouder (union-find)
	var mesh := mi.mesh
	var surfaces: Array = []
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		if idx.is_empty():
			idx = PackedInt32Array(range(vs.size()))
		var keys := PackedVector3Array()
		keys.resize(vs.size())
		for i in vs.size():
			var k := Vector3i((vs[i] * 1000.0).round())
			keys[i] = Vector3(k)
			if not parent.has(keys[i]):
				parent[keys[i]] = keys[i]
		for t in range(0, idx.size() - 2, 3):
			_union(parent, keys[idx[t]], keys[idx[t + 1]])
			_union(parent, keys[idx[t + 1]], keys[idx[t + 2]])
		surfaces.append([vs, keys])
	var boxes := {}
	for sv in surfaces:
		var vs: PackedVector3Array = sv[0]
		var keys: PackedVector3Array = sv[1]
		for i in vs.size():
			var r := _find(parent, keys[i])
			var p := xf * vs[i]
			if boxes.has(r):
				boxes[r] = (boxes[r] as AABB).expand(p)
			else:
				boxes[r] = AABB(p, Vector3.ZERO)
	return boxes.values()


static func _find(parent: Dictionary, k: Vector3) -> Vector3:
	var r := k
	while parent[r] != r:
		r = parent[r]
	var c := k
	while parent[c] != r:
		var nx: Vector3 = parent[c]
		parent[c] = r
		c = nx
	return r


static func _union(parent: Dictionary, a: Vector3, b: Vector3) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[ra] = rb


## Meubels van ingestorte verdiepingen en delen verdwijnen mee.
func _drop_furniture(from_level := -1, groups: Array = []) -> void:
	for m in _meubels.duplicate():
		if (from_level >= 0 and int(m.level) >= from_level) or groups.has(m.group):
			if is_instance_valid(m.body):
				(m.body as Node).queue_free()
			_meubels.erase(m)


func _box(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	body.add_child(cs)


# ---------------------------------------------------------------- hoogte (trap en verdieping)

## Vloerhoogte op wereldpositie p voor iemand die nu op hoogte cur staat; -1 als p niet bij een huis hoort.
static func floor_at(p: Vector3, cur: float) -> float:
	for h: Woonhuis in all:
		var y := h._floor_local(h.to_local(p), cur)
		if y >= 0.0:
			return y
	return -1.0


func _floor_local(lp: Vector3, cur: float) -> float:
	if _ruin:
		return -1.0
	var b := -lp.z
	# balkon: alleen voor wie boven is
	var bal: Array = spec.get("balcony", [])
	if not bal.is_empty():
		var bl: int = bal[4]
		if bl < _fall and cur > levels[bl] - 0.6 and lp.x > bal[0] and lp.x < bal[1] and lp.z > bal[2] and lp.z < bal[3]:
			return levels[bl]
	if not _in_foot(lp, 0.05):
		return -1.0
	# de hoogste vloer of trede onder je voeten waar je bij kunt (een trede op, of vallen)
	var lim := cur + 0.6
	var best: float = levels[0]
	if _near_edge(lp, 0.25):
		best = levels[0] * 0.5   # drempels: buiten de muren loopt de grond van 0 naar de vloer
	var rects: Dictionary = spec.get("floor_rects", {})
	for k in range(1, mini(levels.size(), _fall)):
		if levels[k] <= lim and levels[k] > best and not _in_hole(k, lp.x, b) and (not rects.has(k) or _in_rect(rects[k], lp, 0.0)):
			best = levels[k]
	for st in spec.stairs:
		if st[5] >= _fall:
			continue
		if lp.x > st[0] - 0.1 and lp.x < st[1] + 0.1 and b > minf(st[2], st[3]) - 0.05 and b < maxf(st[2], st[3]) + 0.05:
			var t := clampf((b - st[2]) / (st[3] - st[2]), 0.0, 1.0)
			var y := lerpf(levels[st[4]], levels[st[5]], t)
			if y <= cur + STAIR_LIFT and y > best:   # de voet van een trap ligt een muurdikte van de rand: ruim opstappen
				best = y
	return best


## Grondvlak: rechthoeken [x0, x1, z0, z1] (lokaal); standaard één rechthoek van hx bij hz.
func _foot() -> Array:
	return spec.get("foot", [[-spec.hx, spec.hx, -spec.hz, spec.hz]])


static func _in_rect(r: Array, lp: Vector3, m: float) -> bool:
	return lp.x > r[0] - m and lp.x < r[1] + m and lp.z > r[2] - m and lp.z < r[3] + m


## Binnen het grondvlak (met marge m) en niet in een deel dat al is ingestort.
func _in_foot(lp: Vector3, m: float) -> bool:
	for r in _foot():
		if _in_rect(r, lp, m):
			for nm in _ruined:
				if _in_rect(spec.parts[nm].rect, lp, m):
					return false
			return true
	return false


## Dicht bij de buitenrand: een stapje opzij en je staat buiten (een gedeelde rand tussen toren en schip telt niet).
func _near_edge(lp: Vector3, d: float) -> bool:
	for o in [Vector3(d, 0, 0), Vector3(-d, 0, 0), Vector3(0, 0, d), Vector3(0, 0, -d)]:
		var inside := false
		for r in _foot():
			if _in_rect(r, lp + o, 0.0):
				inside = true
				break
		if not inside:
			return true
	return false


func _in_hole(k: int, x: float, b: float) -> bool:
	for h in spec.holes:
		if h[0] == k and x > h[1] and x < h[2] and b > h[3] and b < h[4]:
			return true
	return false


# ---------------------------------------------------------------- zicht: dak, verdieping en de muren voor de camera

func _process(delta: float) -> void:
	var p = Game.player
	var where := -1
	if p != null and not p.driving:
		var lp := to_local(p.global_position)
		var bal: Array = spec.get("balcony", [])
		var on_balcony: bool = not bal.is_empty() and p.position.y > levels[bal[4]] - 0.6 and lp.x > bal[0] - 0.05 \
			and lp.x < bal[1] + 0.05 and lp.z > bal[2] and lp.z < bal[3] + 0.1
		if not _ruin and (_in_foot(lp, 0.3) or on_balcony):
			where = 0
			for k in range(1, levels.size()):
				if p.position.y > levels[k] - 0.6:
					where = k
	if where != _inside:
		_inside = where
		_apply_view()
	# onder de luifel of in de winkel erachter: de luifel gaat weg zodat je jezelf en de pompen ziet
	for c in _covers:
		var under := _inside >= 0
		if p != null and not p.driving:
			under = under or _in_rect(c[1], to_local(p.global_position), 0.2)
		(c[0] as Node3D).visible = not under
	# deuren gaan open als er iemand dichtbij is
	for d in doors:
		var n: Node3D = d.node
		var near := false
		if p != null:
			var dp: Vector3 = n.global_position - p.global_position
			var reach := 2.8 if kind == "magazijn" and String(n.name).begins_with("DeurVoor") else 1.9
			near = Vector2(dp.x, dp.z).length() < reach and absf(dp.y) < 1.5
		d.t = move_toward(d.t, 1.0 if near else 0.0, delta * 3.0)
		if kind == "magazijn":
			n.rotation.z = d.closed + d.t * PI * 0.5
		else:
			n.rotation.y = d.closed + d.t * PI * 0.5


func _apply_view() -> void:
	for s in _hidden:
		_show_seg(s, true)
	_hidden.clear()
	if _ruin:
		return
	if _dak:
		_dak.visible = _inside < 0 or _inside > int(spec.get("roof_levels", 99))
	for k in range(1, _groups.size()):
		if _groups[k]:
			(_groups[k] as Node3D).visible = _inside < 0 or k <= _inside or k >= _fall
	for n in _gone:
		(n as Node3D).visible = false
	if _inside < 0:
		return
	# muren van deze verdieping die naar de camera (+Z in de wereld) kijken
	var cam_dir := Vector3(0, 0, 1)
	for s in segs:
		if s.staat >= 2 or String(s.name).begins_with("T") or String(s.name).begins_with("K"):
			continue
		if s.floor != _inside:
			continue
		var outward := _outward(s)
		if String(s.name).begins_with("P") or outward.dot(cam_dir) > 0.4:
			_show_seg(s, false)
			_hidden.append(s)


func _show_seg(s: Dictionary, vis: bool) -> void:
	(s.heel as Node3D).visible = vis and s.staat == 0
	(s.kapot as Node3D).visible = vis and s.staat == 1


# ---------------------------------------------------------------- slopen

## Ontploffing in de buurt van huizen (raketten, tankgranaten): muurstukken in de straal krijgen schade.
static func blast_all(at: Vector3, radius: float, dmg: float) -> void:
	for h: Woonhuis in all:
		if h.global_position.distance_to(at) < radius + float(h.spec.near):
			h.blast(at, radius, dmg)


func blast(at: Vector3, radius: float, dmg: float) -> void:
	if _ruin:
		return
	for s in segs.duplicate():
		if s.staat >= 2:
			continue
		var aabb: AABB = (s.heel as MeshInstance3D).global_transform * (s.heel as MeshInstance3D).get_aabb()
		var closest := at.clamp(aabb.position, aabb.end)
		var d := closest.distance_to(at)
		if d < radius:
			damage(s, dmg * 2.2 * (1.0 - d / radius), at)
	if _dak_heel and _dak.visible and not _ruin:
		var top := to_global(spec.roof_c)
		if Vector2(at.x - top.x, at.z - top.z).length() < spec.roof_r and at.y > spec.roof_y:
			_roof_state(1)


func damage(s: Dictionary, dmg: float, from := Vector3.INF) -> void:
	if s.staat >= 2 or dmg <= 0.0 or _ruin:
		return
	s.hp -= dmg
	var c := _center(s)
	if randf() < 0.6:
		Fx.dust(get_parent(), c + Vector3(randf_range(-0.6, 0.6), randf_range(-0.8, 0.8), randf_range(-0.6, 0.6)))
	if s.staat == 0 and s.hp < s.max * 0.55:
		_set_state(s, 1)
		_chunks(s, 3)
		Sfx.play("thud", 0.8, c)
	if s.hp <= 0.0:
		_set_state(s, 2)
		_chunks(s, 5)
		_rubble(s)
		Sfx.play("thud", 1.0, c)
		_check_collapse()


func _set_state(s: Dictionary, st: int) -> void:
	s.staat = st
	var hidden_now: bool = _hidden.has(s)
	(s.heel as Node3D).visible = st == 0 and not hidden_now
	(s.kapot as Node3D).visible = st == 1 and not hidden_now
	var cs: CollisionShape3D = s.cs
	if st == 1:
		if s.shape_kapot == null:
			s.shape_kapot = _wall_shape(s.kapot)
		cs.shape = s.shape_kapot
		# de body hangt onder 'heel'; zelfde plek als 'kapot', dus alleen de vorm wisselt
	elif st >= 2:
		cs.disabled = true
		(s.body as StaticBody3D).collision_layer = 0
	var top: String = spec.get("roof_pre", "M%d" % (levels.size() - 1))
	if String(s.name).begins_with(top) and st >= 2:
		var gone := segs.filter(func(x): return String(x.name).begins_with(top) and x.staat >= 2).size()
		_roof_state(2 if gone >= int(spec.get("roof_need", 4)) else 1)


## Voor het mikken van de tank: midden en buitenrichting van een muurstuk.
func seg_center(s: Dictionary) -> Vector3:
	return _center(s)


func seg_outward(s: Dictionary) -> Vector3:
	return _outward(s)


func _center(s: Dictionary) -> Vector3:
	var mi: MeshInstance3D = s.heel
	return (mi.global_transform * mi.get_aabb()).get_center()


func _outward(s: Dictionary) -> Vector3:
	var basis := (s.node as Node3D).global_transform.basis
	# Blender's Y-up GLB import maps warehouse wall normals through local +Y; the
	# other buildings use the original local +Z convention.
	var o: Vector3 = basis.y if kind == "magazijn" else basis.z
	o.y = 0.0
	return o.normalized()


## Brokken die wegvliegen en blijven liggen.
func _chunks(s: Dictionary, n: int) -> void:
	var c := _center(s)
	var out := _outward(s)
	for i in n:
		var src: Node3D = _puin.get("Brok%d" % (i % 4))
		if src == null:
			return
		var m: Node3D = src.duplicate()
		m.visible = true
		get_parent().add_child(m)
		m.global_position = c + Vector3(randf_range(-0.6, 0.6), randf_range(-0.5, 0.8), randf_range(-0.6, 0.6))
		m.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var land := m.global_position + out * randf_range(1.0, 3.2) + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
		land.y = 0.12
		var tw := m.create_tween()
		var top := (m.global_position + land) * 0.5 + Vector3.UP * randf_range(0.8, 1.8)
		var p0 := m.global_position
		tw.tween_method(func(t: float) -> void:
			m.global_position = p0.lerp(top, t).lerp(top.lerp(land, t), t)
			m.rotate_x(0.15), 0.0, 1.0, 0.55)
		tw.tween_interval(25.0)
		tw.tween_callback(m.queue_free)


## Puinhoop aan de voet van een weggeslagen muur: blijft liggen als dekking (houdt kogels tegen).
func _rubble(s: Dictionary, big := false) -> void:
	var c := _center(s)
	var out := _outward(s)
	var foot := c + out * (0.9 if s.floor == 0 else 2.0)
	foot.y = 0.0
	var small: bool = not big and (String(s.name).begins_with("T") or String(s.name).begins_with("P") or String(s.name).begins_with("K"))
	_pile(foot, "PuinKlein" if small else "PuinGroot", 0.75 if small else 0.85)
	for k in 3:
		Fx.dust(get_parent(), c + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)))


func _pile(at: Vector3, kind: String, sc: float) -> void:
	var src: Node3D = _puin.get(kind)
	if src == null:
		return
	var m: Node3D = src.duplicate()
	m.visible = true
	add_child(m)
	m.global_position = at
	m.rotation.y = randf() * TAU
	m.scale = Vector3.ONE * sc
	var body := StaticBody3D.new()
	body.collision_layer = Kit.LAYER_WALL
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	var r := (1.5 if kind == "PuinGroot" else 0.8) * sc
	b.size = Vector3(r * 1.5, 0.75 * sc + 0.2, r * 1.5)
	cs.shape = b
	cs.position.y = b.size.y * 0.5
	body.add_child(cs)
	m.add_child(body)


func _roof_state(st: int) -> void:
	if _dak_heel == null:
		return
	if st == 1 and _dak_heel.visible == false and _dak_kapot.visible == false and _dak.get_meta("weg", false):
		return
	if st == 1:
		if _dak_heel.visible:
			_dak_heel.visible = false
			_dak_kapot.visible = true
			Fx.dust(get_parent(), to_global(spec.roof_c))
	elif st >= 2 and not _dak.get_meta("weg", false):
		_dak.set_meta("weg", true)
		_dak_heel.visible = false
		_dak_kapot.visible = false
		# het dak valt op de hoogste vloer die nog staat
		var y: float = levels[mini(_fall, levels.size()) - 1]
		_pile(to_global(spec.get("roof_pile", Vector3(1.5, y, 0.5))), "PuinGroot", 1.0)


## Te veel muren van een laag weg: alles erboven zakt in. Bij de winkel stort dan het hele gebouw in, bij de kerk
## de toren of het schip.
func _check_collapse() -> void:
	if _ruin:
		return
	for rule: Dictionary in spec.collapse:
		if rule.has("fall") and int(rule.fall) >= _fall:
			continue
		if rule.has("ruin") and _ruined.has(rule.ruin):
			continue
		var pre: String = rule.pre
		var gone := segs.filter(func(x): return String(x.name).begins_with(pre) and x.staat >= 2).size()
		if gone < int(rule.need):
			continue
		if rule.has("ruin"):
			if rule.ruin == "all":
				_ruin_all()
			else:
				_ruin_part(rule.ruin)
		else:
			_fall_from(int(rule.fall))
		return


## Verdieping k en alles erboven zakt in: vloeren kapot, inrichting weg, muren erboven kapot of weg, dak weg.
func _fall_from(k: int) -> void:
	_fall = k
	_collapsed = true
	_drop_furniture(k)
	for j in range(k, levels.size()):
		var g: Node3D = _groups[j]
		var vh: Node3D = model.find_child("Vloer%d_heel" % j, true, false)
		var vk: Node3D = model.find_child("Vloer%d_kapot" % j, true, false)
		if vh and vk:
			vh.visible = false
			vk.visible = true
		if g:
			for c in g.get_children():
				var nm := String(c.name)
				if nm.begins_with("Inrichting") or nm.begins_with("DeurBinnen") or nm == "Balkon":
					c.visible = false
	for s in segs:
		if s.floor >= k and s.staat < 2:
			_set_state(s, 2 if randf() < 0.6 else 1)
	if spec.get("fall_roof", true):
		_roof_state(2)
	for fp in spec.fall_piles:
		var at: Vector3 = fp[0]
		if at.y < 0.0:
			at.y = levels[k - 1]
		_pile(to_global(at), "PuinGroot", fp[1])
	var mid: float = levels[k]
	var fc: Vector3 = spec.get("fall_c", Vector3.ZERO)
	var fr: Vector2 = spec.get("fall_r", Vector2(spec.hx, spec.hz))
	Fx.explosion(get_parent(), to_global(fc + Vector3(0, mid, 0)), 1.4)
	for n in 8:
		Fx.dust(get_parent(), to_global(fc + Vector3(randf_range(-fr.x, fr.x), randf_range(0.5, mid + 2.0), randf_range(-fr.y, fr.y))))
	if spec.has("fall_banner"):
		Game.banner.emit(spec.fall_banner, "", 1.4)
	else:
		Game.banner.emit(spec.banner if k == 1 else "VERDIEPING INGESTORT", "", 1.4)
	_apply_view()


## Het hele gebouw stort in: alles weg, de ruïne uit het model komt ervoor in de plaats (houdt kogels tegen).
func _ruin_all() -> void:
	_ruin = true
	_collapsed = true
	_fall = 0
	for s in segs:
		s.staat = 2
		(s.cs as CollisionShape3D).disabled = true
		(s.body as StaticBody3D).collision_layer = 0
	for g in _groups:
		if g:
			(g as Node3D).visible = false
	if _dak:
		_dak.visible = false
	for c in get_children():
		if c is StaticBody3D or (c is Node3D and c != model):
			c.queue_free()   # losse puinhopen en de relingen
	var ruine: Node3D = model.find_child("Ruine", true, false)
	if ruine:
		ruine.visible = true
	var body := StaticBody3D.new()
	body.collision_layer = Kit.LAYER_WALL
	body.collision_mask = 0
	add_child(body)
	for rb in spec.ruin_boxes:
		_box(body, rb[0], rb[1])
	# wie binnen stond, wordt bedolven en naar buiten geduwd
	var p = Game.player
	if p != null and _inside >= 0 and not p.driving:
		p.global_position = to_global(Vector3(0, 0, spec.hz + 2.6))
		p.position.y = 0.0
		p.hit(60.0, Vector3(0, 0, 1), false)
	_inside = -1
	for n in 3:
		Fx.explosion(get_parent(), to_global(Vector3(randf_range(-2, 2), 2.0 + n * 2.5, randf_range(-2, 2))), 1.6)
	for n in 14:
		Fx.dust(get_parent(), to_global(Vector3(randf_range(-5, 5), randf_range(0.3, 6.0), randf_range(-4.5, 4.5))))
	Sfx.play("thud", 1.0, global_position)
	Game.banner.emit(spec.banner, "", 1.6)


## Eén deel van het gebouw stort in (kerk: de toren of het schip): de muren van dat deel weg, de knooppunten uit
## "hide" verdwijnen, de ruïne van dat deel komt ervoor in de plaats. Zijn alle delen ingestort, dan ligt alles plat.
func _ruin_part(nm: String) -> void:
	if _ruined.has(nm):
		return
	var part: Dictionary = spec.parts[nm]
	_ruined[nm] = true
	_collapsed = true
	for s in segs:
		for pre: String in part.pre:
			if String(s.name).begins_with(pre):
				s.staat = 2
				(s.cs as CollisionShape3D).disabled = true
				(s.body as StaticBody3D).collision_layer = 0
				_show_seg(s, false)
	_drop_furniture(-1, part.hide)
	for hn: String in part.hide:
		var n: Node3D = model.find_child(hn, true, false)
		if n:
			n.visible = false
			_gone.append(n)
	if part.has("fall"):
		_fall = mini(_fall, int(part.fall))
	if _guard_bodies.has(nm):
		(_guard_bodies[nm] as Node).queue_free()
		_guard_bodies.erase(nm)
	var rn: Node3D = model.find_child(part.node, true, false)
	if rn:
		var holder := rn.get_parent() as Node3D   # 'Ruine'
		holder.visible = true
		rn.visible = true
		for c in holder.get_children():
			if not _ruined.has(String(c.name).trim_prefix("Ruine")):
				(c as Node3D).visible = false
	var body := StaticBody3D.new()
	body.collision_layer = Kit.LAYER_WALL
	body.collision_mask = 0
	add_child(body)
	for rb in part.boxes:
		_box(body, rb[0], rb[1])
	if int(part.get("roof", 0)) > 0:
		_roof_state(int(part.roof))
	# wie in dit deel stond, wordt bedolven en naar buiten geduwd
	var p = Game.player
	var r: Array = part.rect
	if p != null and not p.driving:
		var lp := to_local(p.global_position)
		if _in_rect(r, lp, 0.3):
			p.global_position = to_global(part.exit)
			p.position.y = 0.0
			p.hit(60.0, (to_global(part.exit) - global_position).normalized(), false)
	var c := Vector3((r[0] + r[1]) * 0.5, 0.0, (r[2] + r[3]) * 0.5)
	var hw: float = (r[1] - r[0]) * 0.5
	var hd: float = (r[3] - r[2]) * 0.5
	for n in 3:
		Fx.explosion(get_parent(), to_global(c + Vector3(randf_range(-1.5, 1.5), 2.0 + n * 2.5, randf_range(-1.5, 1.5))), 1.6)
	for n in 12:
		Fx.dust(get_parent(), to_global(c + Vector3(randf_range(-hw, hw), randf_range(0.3, 6.0), randf_range(-hd, hd))))
	Sfx.play("thud", 1.0, to_global(c))
	Game.banner.emit(part.banner, "", 1.6)
	if _ruined.size() >= spec.parts.size():
		_ruin = true
		_fall = 0
	_inside = -1
	_apply_view()
