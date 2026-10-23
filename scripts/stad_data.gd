class_name StadData
## De indeling van de stad achter de brug, gemaakt met de stadseditor (stad_editor.gd) en vastgelegd in de code.
## Elke regel: [soort, x, z, kwartslagen (0-3), gespiegeld (0 of 1)]. De soorten staan in Stad.KINDS.
const ITEMS := [
	# hoofdstraat vanaf de brug, met een zijstraat naar het oosten en een plein aan het eind
	["weg_recht", 0, -96, 0, 0],
	["weg_kruis", 0, -102, 0, 0],
	["weg_recht", 0, -108, 0, 0],
	["plein", 0, -117, 0, 0],
	["weg_recht", 6, -102, 1, 0],
	["weg_recht", 12, -102, 1, 0],
	["weg_recht", 18, -102, 1, 0],
	["weg_recht", 24, -102, 1, 0],
	["weg_recht", 30, -102, 1, 0],
	["weg_recht", -6, -102, 1, 0],
	# de twee gebouwen die er al stonden
	["woonhuis", 11, -110, 0, 0],
	["winkel", 22, -110.5, 0, 0],
	# grijze blokken voor de gebouwen die nog gemaakt moeten worden
	["benzine", -13, -109.5, 0, 0],
	["hotel", -27, -111, 0, 0],
	["magazijn", 36, -112, 0, 0],
	# straatmeubilair
	["lantaarn", 3.5, -99, 0, 0],
	["lantaarn", -3.5, -105, 0, 0],
	["lantaarn", 3.5, -111, 0, 0],
	["auto", 9, -100.5, 1, 0],
	["autowrak", -9, -103.5, 3, 0],
]
