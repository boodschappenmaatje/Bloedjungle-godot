class_name StadData
## De indeling van de stad achter de brug, gemaakt met de stadseditor (stad_editor.gd) en vastgelegd in de code.
## Elke regel: [soort, x, z, kwartslagen (0-3), gespiegeld (0 of 1)]. De soorten staan in Stad.KINDS.
const ITEMS := [
	# hoofdstraat vanaf de brug naar het plein (zebrapad bij de brug, kruispunt met de dwarsstraat)
	["weg_zebra", 0, -96, 0, 0],
	["weg_kruis", 0, -102, 0, 0],
	["weg_recht", 0, -108, 0, 0],
	["weg_recht", 0, -114, 0, 0],
	["weg_recht", 0, -120, 0, 0],
	["weg_recht", 0, -126, 0, 0],
	# plein met fontein, omringd door stoep
	["plein", 0, -135, 0, 0],
	["stoep", -9, -132, 0, 0],
	["stoep", -9, -138, 0, 0],
	["stoep", 9, -132, 0, 0],
	["stoep", 9, -138, 0, 0],
	# dwarsstraat naar het oosten en een stukje naar het westen
	["weg_recht", 6, -102, 1, 0],
	["weg_recht", 12, -102, 1, 0],
	["weg_recht", 18, -102, 1, 0],
	["weg_recht", 24, -102, 1, 0],
	["weg_recht", 30, -102, 1, 0],
	["weg_recht", -6, -102, 1, 0],
	# aan het plein: kerk met toren aan het eind, hotel links en winkel met flat rechts (voordeur naar het plein)
	["kerk", 0, -152, 0, 0],
	["hotel", -12, -146, 0, 0],
	["winkel", 12, -145, 0, 0],
	# langs de hoofdstraat en de zijstraat
	["woonhuis", 11, -110, 0, 0],
	["woonhuis", -11, -111, 0, 0],
	["magazijn", 36, -112, 0, 0],
	["benzine", 48, -111, 0, 0],
	# straatmeubilair: lantaarns om de 12 m, bij de brug een bushokje en zandzakken
	["lantaarn", 3.5, -99, 0, 0],
	["lantaarn", -3.5, -105, 0, 0],
	["lantaarn", 3.5, -111, 0, 0],
	["lantaarn", -3.5, -117, 0, 0],
	["lantaarn", 3.5, -123, 0, 0],
	["lantaarn", -11, -129.5, 0, 0],
	["lantaarn", 11, -129.5, 0, 0],
	["bushokje", -4.6, -98, 0, 0],
	["zandzakken", 4.6, -98, 0, 0],
	["brandkraan", -3.4, -111.5, 0, 0],
	["prullenbak", 3.4, -106.5, 0, 0],
	["bankje", -9, -135, 1, 0],
	["bankje", 9, -135, 3, 0],
	["boom", -12.5, -139.5, 0, 0],
	["boom", 12.5, -139.5, 0, 0],
	["struik", -14, -131, 0, 0],
	["struik", 14, -131, 0, 0],
	# oorlogssfeer: wrakken, een brandende auto en puin als dekking
	["auto", 9, -100.5, 1, 0],
	["autowrak", -9, -103.5, 3, 0],
	["bus", 20, -100.5, 1, 0],
	["autobrand", 1, -118, 0, 0],
	["puin", -1.5, -124, 0, 0],
	["hek", -8, -107.5, 0, 0],
]
