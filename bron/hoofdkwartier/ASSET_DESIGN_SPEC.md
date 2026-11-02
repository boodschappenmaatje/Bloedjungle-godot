# Hoofdkwartier (HK): Asset Design Specification

Status: goedgekeurd door Dennis op 2026-11-01 (keuzes 1C, 2A, 3A+3B, 4B, 5A, 6B). Het niveau-systeem (4B) wordt in overleg uitgewerkt, zie onderaan.

## Rol
Hart van de basis (Generals-plan B3). Het staat op de plek van de oude bunker en neemt zijn gameplaycontract over: zelfde botsblok (4,6 x 2 x 4,6 m), zelfde laag `Kit.LAYER_BUNKER`, zelfde `bunker.gd` (vijandelijke kogels doen 80% schade aan `Game.base_hp`), zelfde pivot. Als het vernield wordt is het game over. Na sneuvelen kom je er terug (deur opent).

## Uiterlijk (keuze 1C)
Gepantserd commandocentrum van twee verdiepingen: betonnen begane grond met olijfgroene pantserplaten, schietsleuven, een pantserdeur en luifel met lamp; bovenverdieping met glazen controlekamer (donkere schermen die gloeien), dak met borstwering, draaiende radarschotel, antennes met rood knipperlicht en een wapperende vlag; camouflagenet langs de westkant. Letters HQ en een ster boven de deur. Modelmaat 5,0 x 5,0 m, ca. 6,2 m hoog; in het spel op schaal 0,92 (past op het 4,6 m botsblok). Voorkant (deur) naar +Z.

## Animaties
| Clip | Type | Inhoud |
|---|---|---|
| `Radar-loop` | Blender | schotel draait rond in 8 s, naadloos |
| `Open` / `Dicht` | Blender | pantserdeur schuift 1,28 m opzij en terug (1 s); opent als je terugkomt |
| `Wapperen-loop` | Blender | vlag (zelfde doek en skelet als de verzamelvlag), 2 s |
Godot-gestuurd: rood lampje knippert (1,6 s), amberlampen en schermen gloeien sterker bij Avond/Nacht, schadelagen, niveau-onderdelen, camouflagenet als alfa-scissor.

## Onderdelen die Godot aan/uit zet
`Niveau2` (tweede schotel, antennerek, pantserplaten onder het glas), `Zandzakwal` (zandzakken rond het lagere dak, op elk niveau zichtbaar), `Niveau3` (zoeklicht, stalen luiken), `Schade1` (roet, onder 60% sterkte) en `Schade2` (brandplekken en scheuren, onder 30%). Bij vernietiging: bestaande rook en vuur, dan game over.

## Budget en materialen (herzien 2 november 2026: bunkerkwaliteit)
Dennis' eisen na de eerste versie: gelijk aan bunker en vliegveld, foto-realistisch, minimaal 40.000 driehoeken, 2K-texturen. Het hoofdkwartier is het centrale gebouw van de basis.
- **Spelversie** `assets/hoofdkwartier.glb`: ca. 42.600 driehoeken (alle niveaus en schadelagen samen), 8 materialen: twee gebakken atlassen (`HK_Gebakken_romp`, `HK_Gebakken_details`, elk 2048 px albedo, ORM met AO en normal), glas, rood en amber lampje, camonet (alfa), schadelagen (alfa) en het vlagdoek (1024 px).
- **Hoe de textuur ontstaat** (`bron/hoofdkwartier/hk_bake.py`): verweerde Cycles-materialen op de VQ2-brontexturen, met AO-vuil in hoeken, randslijtage met roest, regenstrepen, algen onderaan, stof op bovenvlakken, modder en microreliëf. Alles wordt in één unieke atlas gebakken (Smart UV, onzichtbare vlakken eerst weggesneden). De VQ2-brontexturen zijn native 1024 px; de gebakken atlas is uniek en 2K.
- **LOD1** `assets/hoofdkwartier_lod1.glb` (vanaf 45 m, 1024 px atlas) en **HQ-bron** `bron/hoofdkwartier/uit/Hoofdkwartier_HQ.blend` (zwaardere afronding, levende procedurele materialen, bewerkbaar).
- **Detail**: bekistingspanelen met ankergaten, pantserluiken met klinknagels en lasnaden, buitentrap met geel gemarkeerde treden, airco's, ventilatieschacht, leidingen en kabelgoten, vuurblusser, waarschuwingsbordjes, raamwerk met scharnieren, ribbenschotel met voedingsarm, vakwerkmasten met tuidraden, dakbedekking met naden, klimop, zandzakwal rond het lagere dak (alle niveaus).
- **Herziening 2 november 2026, na de screenshot van Dennis** ("niet compleet, je ziet een heel gat"): de kniemuur onder de ramen ontbrak in `hoofdkwartier.glb`. Oorzaak: `hk_bake.cull_hidden` (verborgen vlakken weghalen) mat een groot vlak met maar vijf punten, die alle vijf achter dunne panelen lagen; het vlak ging weg. Nu meet de snoeier ook bij de hoeken, de randen en met een raster over grote vierhoeken. `tests/hq_omgeving_test.gd` controleert dat de kniemuur er is (rays en driehoeken in de echte spel-glb).
- **Niveau 1 af** (`build_vol`, altijd zichtbaar): betonnen stoep voor de deur, leidingstrang en aansluitkastjes op het lagere dak, voorraadkratten met banden en een opgerold zeil (westkant), regenpijpen met trechters (achterwand), twee luchtroosters met lamellen (westwand), kooilamp met kabel links van de deur, op het dak een airco met ventilator, twee ventilatiekappen en twee zweepantennes. Het net is groter (4,8 x 2,6 m), lichter olijf/bruin, met touwruiten en een zoom.
- **Helderheid**: de gebakken albedo was te donker (gemiddeld 45/255 tegen 87-96 bij de vliegvelden). `hk_bake.compose`: AO nog maar 30% in de albedo (zit al in de ORM) en een lineaire winst van 2,4. Nieuw gemiddelde 100-104/255 (de spelcamera met ACES en contrast 1,2 maakt het weer donkerder).
- Geen iPhone-, Safari- of Quick Look-meting gedaan (NIET GETEST).

## Niveaus (4B)
Het huidige niveau staat in `Game.hq_level` (1 tot 3). Voordelen per niveau (code: `scripts/hq_perks.gd`, `hq_dakgeweer.gd`, `artillerie.gd`, `artillerie_aim.gd`):
- **Niveau 2** (1500 punten, +400 sterkte): radar. Vijanden binnen 85 m van het hoofdkwartier staan als stip op de tactische kaart (ring met zwaaiende lijn); een nieuwe groep geeft de melding "RADAR: VIJAND NADERT" met windrichting en afstand; alle bouw- en opleidingstijden 25% korter (`Buildings.time_factor`). Modelmatig: tweede schotel, antennerek, pantserlijsten (`Niveau2`).
- **Niveau 3** (2500 punten, +500 sterkte): automatisch dakgeweer op het dak (10 s zichtbaar opgebouwd: plaat, poten, paal, schild, geweer zakt erin; schiet binnen 25 m op de dichtstbijzijnde vijand, 300 patronen, `Defenses.refill` vult aan) en het artilleriecommando (knop boven de luchtsteun: vasthouden en slepen om te richten, loslaten roept 5 granaten, 90 s afkoeling, schade alleen aan vijanden). Het dakgeweer hergebruikt het bestaande MG42-model uit `assets/wapens.glb` met een in Godot gebouwde affuit (Godot-gestuurd, geen Blender-clip). Modelmatig: zoeklicht en luiken (`Niveau3`); de zandzakwal staat sinds v174 op alle niveaus (Dennis: de open dakrand moest op niveau 1 al dicht).

## Omgeving: voorplein (herziening 2 november 2026)
Bron `bron/hoofdkwartier/maak_omgeving.py`, spelversie `assets/hoofdkwartier_omgeving.glb`, Godot `scripts/hq_omgeving.gd`. Een betonnen voorplein van 10,8 x 10,8 m (16 platen met voegen, 5 cm dik, geen botsing: je loopt erover), gele randlijnen met een open ingang, witte stoplijn, gele schuine strepen, HQ-stencil, putdeksel en afvoerrooster. Twee lichtmasten van 5,9 m met armaturen (amberlenzen: gloed, bij Avond/Nacht echt licht), vier afzetblokken met reflecterende strepen en twee paaltjes langs de voorrand (ingang 4,5 m open), vijf vaten in een opvangbak, een pallet met munitiekisten en zeil, een kabelhaspel, grondkabels met een kabelbrug. Botsblokken op de laag `LAYER_WALL` (kogels en mensen stoppen, er kan niet op gebouwd worden); de weg vanaf de deur blijft vrij (test). Eén unieke 2K-atlas (albedo, ORM met AO, normal).

