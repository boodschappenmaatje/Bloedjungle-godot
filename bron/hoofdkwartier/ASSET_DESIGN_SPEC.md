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

## Budget en materialen (keuze 6B)
Spelversie 5.842 driehoeken (gepland ca. 8.000), HQ-bron 15.1k, LOD1 3.3k (vanaf 45 m). 10 materialen: beton, olijfstaal, donker metaal, glas, rood lampje, amber lampje, witte verf, camonet, schade, vlagdoek. Texturen: de VQ2-brontexturen (concrete, olive, steel) zijn native 1024 px en niet eerlijk op te schalen naar 2K; het gegenereerde net/schade/doek gebruikt 1024. Nieuwe 2K-bronnen (Poly Haven) alleen na jouw goedkeuring van de materialen.

## Niveaus (4B)
Zie de afspraken in de PR; het huidige niveau staat in `Game.hq_level` (1 tot 3).
