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
`Niveau2` (tweede schotel, antennerek, pantserplaten onder het glas), `Niveau3` (zoeklicht, zandzakrand, stalen luiken), `Schade1` (roet, onder 60% sterkte) en `Schade2` (brandplekken en scheuren, onder 30%). Bij vernietiging: bestaande rook en vuur, dan game over.

## Budget en materialen (herzien 2 november 2026: bunkerkwaliteit)
Dennis' eisen na de eerste versie: gelijk aan bunker en vliegveld, foto-realistisch, minimaal 40.000 driehoeken, 2K-texturen. Het hoofdkwartier is het centrale gebouw van de basis.
- **Spelversie** `assets/hoofdkwartier.glb`: ca. 42.600 driehoeken (alle niveaus en schadelagen samen), 8 materialen: twee gebakken atlassen (`HK_Gebakken_romp`, `HK_Gebakken_details`, elk 2048 px albedo, ORM met AO en normal), glas, rood en amber lampje, camonet (alfa), schadelagen (alfa) en het vlagdoek (1024 px).
- **Hoe de textuur ontstaat** (`bron/hoofdkwartier/hk_bake.py`): verweerde Cycles-materialen op de VQ2-brontexturen, met AO-vuil in hoeken, randslijtage met roest, regenstrepen, algen onderaan, stof op bovenvlakken, modder en microreliëf. Alles wordt in één unieke atlas gebakken (Smart UV, onzichtbare vlakken eerst weggesneden). De VQ2-brontexturen zijn native 1024 px; de gebakken atlas is uniek en 2K.
- **LOD1** `assets/hoofdkwartier_lod1.glb` (vanaf 45 m, 1024 px atlas) en **HQ-bron** `bron/hoofdkwartier/uit/Hoofdkwartier_HQ.blend` (zwaardere afronding, levende procedurele materialen, bewerkbaar).
- **Detail**: bekistingspanelen met ankergaten, pantserluiken met klinknagels en lasnaden, buitentrap met geel gemarkeerde treden, airco's, ventilatieschacht, leidingen en kabelgoten, vuurblusser, waarschuwingsbordjes, raamwerk met scharnieren, ribbenschotel met voedingsarm, vakwerkmasten met tuidraden, dakbedekking met naden, klimop, zandzakken (niveau 3).
- Geen iPhone-, Safari- of Quick Look-meting gedaan (NIET GETEST).

## Niveaus (4B)
Zie de afspraken in de PR; het huidige niveau staat in `Game.hq_level` (1 tot 3).
