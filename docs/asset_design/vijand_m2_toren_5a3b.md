# Asset Design Specification — Browning M2HB MG-wachttoren (D2 / 5a-3b)

**Datum:** 2026-11-05. **Status:** ontwerpkeuzes én origineel Meshy-bronmodel door Dennis goedgekeurd; **Godot-import, mobiele optimalisatie, animaties en gameplay nog niet voltooid**.  
**Repo:** `boodschappenmaatje/Bloedjungle-godot` · **Branch:** `feature/vijandbasis-5a-3b-browning-m2`.  
**Kwaliteit:** [ASSET_QUALITY_STANDARD.md](../ASSET_QUALITY_STANDARD.md), [VIJANDBASIS_MESHY_MODELLEN.md](../VIJANDBASIS_MESHY_MODELLEN.md), [GENERALS_PLAN.md](../GENERALS_PLAN.md).

## 1. Definitieve keuzes van Dennis (1–21)

| Codes | Specificatie |
|---|---|
| 1C/2C/3C | 4 slimme MG-torens en **12 verdedigers totaal, inclusief de 4 schutters**; moeilijk maar eerlijk |
| 4C/8B | Tactische dekking, onderdrukking en flankeren binnen basis; geen onbegrensde achtervolging |
| 5C/6C/7B | Nieuwe hoogwaardige Meshy-torens, cinematische clips, realistische unieke ruimtelijke audio met licentiebewijs |
| 9C/10B | Schutter en toren apart uitschakelbaar; echte zichtlijnen, richtvertraging, salvo-/herlaadpauzes |
| 11A | 4 MG-schutters, 4 poortbewakers, 2 HK-bewakers en 2 mobiele reserves |
| 12B/13B | Eén reserve mag vrije MG bemannen na werkelijk klimmen; overlevenden hergroeperen bij HK na poortdoorbraak |
| 14B/15B/16B | **6 schade per raak schot; 8 schoten per salvo; 650 HP per toren; 36 m schietbereik** |
| 17B/18B | Halfgesloten onderbouw, ladder plus klein tussenbordes aan de binnenzijde |
| 19B/20B | Zichtbare forse schade/instorting met blijvende ruïne en collision; volledige klim- en overnamebeweging |
| 21 | **Amerikaanse Browning M2HB .50 cal**, geen MG42 |

Een gedode schutter wordt **niet** vanzelf vervangen. Alleen één van de maximaal twee levende reserves kan na een echte route- en klimanimatie een lege MG overnemen; nooit een extra spawn.

## 2. Exacte maten en integratie in de bestaande vijandbasis

De huidige code `scripts/vijand_basis.gd` plaatst vier bloktorens, nog zonder vuurlogica. De basis is **64 × 56 m**, centrum `Data.VIJAND_POS = (-32,0,-243)`, poort aan de zuidkant **6,8 m breed**. Behoud de bestaande torencentra, lokale x=±**30,2** m en z=±**26,2** m ten opzichte van het basiscentrum (de vier combinaties).

| Eigenschap | Contract voor nieuw model |
|---|---|
| Buitenfootprint toren | **2,6 × 2,6 m**; geen onnodige uitbreiding over muur of looppaden |
| Hoogte inclusief dak | **6,0 m** |
| MG-platformvloer | **4,4 m boven maaiveld** |
| Origin | Midden van voetafdruk, op maaiveld, 1 unit = 1 meter |
| Voorzijde | **+Z naar buiten**; klimpad/ladder aan **-Z naar binnen**; per hoek correct roteren |
| Torenposities | Exact gelijk aan bestaande `VijandBasis._toren` posities |
| Collision | Stilstaand, nauw passend op de dragende onderbouw; aparte colliders voor schild/schutter, ruïne na sloop blijvend |
| Materialen | Verweerd beton en donker staal, matte subtiele groen-gele vijandmarkering |
| Hergebruik | Eén identieke, gedeelde GLB-resource, op 4 hoeken geïnstantieerd |

De huidige bloktoren is ongeveer **5,6 m hoog**, met platform rond 4,4 m en een dak van 2,7 m. Controleer vervanging met bovenaanzicht, muurdoorgang, schootssector en laddertoegang; wijzig geen basisgebouwen, poort of speelveld.

## 3. Meshy-model en Blender/Godot-hiërarchie

Meshy produceert mogelijk één samengevoegde mesh. Splits/rig die daarna zo nodig in Blender: een statische toren kan de afgesproken schutter-, ladder- en MG-animaties **niet** zelfstandig leveren. Houd het bestaande gerigde Assault-vijandmodel **buiten** de Meshy-toren en verbind dit via een anker.

| Naam | Functionele rol |
|---|---|
| `TowerRoot` | Transform op grond-origin |
| `TowerStatic` | Onderbouw, trap/ladder, borstwering, zandzakken |
| `MG_Yaw` | Draaiaffuit en beschermschild: horizontaal richten |
| `MG_Pitch` | Verticaal richten van loop/receiver |
| `MG_Recoil` | Zichtbare mechanische terugslag |
| `AmmoBelt` | Bewegende munitieband tijdens schieten |
| `Muzzle`, `CasingEject` | Exacte schot-, VFX- en hulzenposities |
| `ShooterMount` | Plaats waar gerigde vijandsoldaat de MG bemant |
| `LadderStart`, `LadderLanding`, `LadderEnd` | Waypoints voor reserve; toegankelijk vanaf binnenplaats |
| `TowerIntact`, `TowerWreck` | Intacte en vernielde geometry, zonder verlies van ruïnecollision |

**Godot bestuurt de richtpivots en projecteert echte kogels; Blender levert zichtbare animaties waar ze nodig zijn.** Eerste richtlimiet: ±150° horizontaal vanuit de buitenzijde, controleren op dak/schild-occlusie. Geen bullets door muren. Richt-LOD en schiet-/audio-LOD beperken belasting op iPhone.

## 4. Animatiecontract (voorgestelde namen)

| Animatie | Richtduur | Implementatie |
|---|---|---|
| `MG_Idle` | looping | Bestaande wacht-/schietpose, lichte beweging |
| `MG_Fire` | ~0,115 s per schot | Terugslag, munitieband; echte kogels/VFX via Godot |
| `MG_Reload` | ~2,5 s | Nieuwe munitieband/handeling, gameplay lock |
| `Shooter_Aim` | looping | Soldier rig richt op MG-doelpivot |
| `Shooter_Hit`, `Shooter_Die` | ~0,5 / 1,2 s | Raken, sterven, MG direct onbemand |
| `Ladder_Climb` | ~3 s | Reserve beklimt ladder via 3 ankers |
| `MG_Mount` | ~1 s | Pas na dit einde kan nieuwe schutter vuren |
| `Tower_Collapse` | ~1,4 s | Gedeeltelijke instorting, daarna statisch wrak met collision |

**Niet claimen dat animaties al aanwezig zijn.** Dit is de gewenste export-/code-interface. Test daadwerkelijke zichtbare beweging van de pivots en bestaande soldier rig.

## 5. Balans en spelcontract

- **MG:** 36 meter afstand, 0,8 seconde doelverwerving als startwaarde, **8 schoten × 6 schade**, voor prototype 0,115 seconde tussen schoten en een pauze 0,9–1,2 seconde per salvo. De 0,8 en 0,115 seconden zijn **voorstellen**, niet afzonderlijk bevestigde gebruikerskeuzes.
- **Toren:** 650 HP, zichtbaar licht/zwaar beschadigd, vervolgens permanente ruïne. Bazooka is nu 240 basisschade in `Data.WEAPONS`; werkelijke treffersterkte hangt af van explosieafstand/schadesysteem.
- **Verdedigers — eerste testwaarden, nog niet definitief:** MG-schutter 90 HP (4), poort 85 HP (4), HK 110 HP (2), reserve 90 HP (2). De bestaande Assault heeft 65 HP, speler heeft basis 100 HP.
- **Reserves:** nooit meer dan 2; alleen echte overlevenden mogen bemannen; overlijden van reserve of toren onderbreekt overname; geen teleportatie, geen onsterfelijkheid.
- **Tactiek:** doelprioriteit zwaarste directe dreiging (raket/tank), mits in bereik en zicht; schietsectoren en cooldown zodat alle MG's niet oneerlijk tegelijk locken. Poortsoldaten verdedigen met dekking, HK-bewakers blijven rond HQ; bij doorbraak worden overlevenden naar HK-positie gestuurd.
- **Offscreen-beleg:** `scripts/beleg.gd` gebruikt nu vaste **1,25 schade per toren per seconde**, ook als er geen schutter is. Vervang dat bij implementatie door statusbewuste berekening (levend, bemand, intact, kan mikken). Geen dubbele schade wanneer speler binnen/buiten de 55 m-grens beweegt; torens en verliezen blijven persistent.
- **Botsing en zichtlijn:** schietposities passen bij schutterhoogte, muur en MG-schild; afzonderlijke hitboxes voor `shooter` en `tower`; ruïne blijft blocking. Torens mogen niet verdwijnen als de speler tegen de muur loopt.

## 6. PBR, licenties, mobiele prestaties

- Werkelijk HQ-`.blend`-bronbestand en geoptimaliseerde `.glb` voor Godot; PBR albedo/OpenGL normal/roughness/metallic. Bron 2K; mobiele atlas testen op 1–2K.
- **Voorlopig mobiel budget:** ≤35.000 driehoeken voor toren-LOD0 exclusief soldaat, ≤8.000 voor LOD1, bij voorkeur maximaal twee gedeelde materiaalsets. Dit zijn streefwaarden, geen bewezen FPS-limieten. Alle vier torens delen GLB en PBR.
- Kies materialen eerst uit bestaande CC0-bibliotheek of bespreek 2–4 Poly Haven-opties vóór nieuwe downloads; volgens kwaliteitsstandaard. Geen betalingen.
- Authentieke M2-geluiden: schot, mechaniek, munitie/herladen, hulzen en impact. Alle externe clips met controleerbare CC0/CC BY-licentie en attributie. Geen ongedocumenteerde audio.
- Lever ook `.usdz` voor iPhone Bestanden/Quick Look en werkende animatieviewer zodra het model echt bestaat. **Native iPhone-performancetest: NIET UITGEVOERD.**

## 7. Meshy Pro prompt (maximaal 800 tekens)

```text
Photorealistic WWII American fortified guard tower for a jungle military base. Exact size 2.6 x 2.6 m footprint, 6.0 m height, MG platform 4.4 m above ground. Half-enclosed concrete and weathered steel lower section, heavy supports, bolts, rivets, sandbags, protective armored gun shield. Separate historically correct Browning M2HB .50 cal machine gun on a swivel mount, visible ammo belt, ammo boxes, receiver, long heavy barrel and shell ejection. Inward-facing steel ladder with small landing for one soldier. Subtle dark olive and dirty-yellow camouflage. Highly detailed PBR materials and realistic wear. Modular construction, moving gun parts separable for animation, accurate proportions. Isolated 3D asset, no soldiers, no ground, no vegetation, no background.
```

**Promptlengte: 769 tekens.** Meshy-model zonder soldaat; later bestaande Assault-rig koppelen. Geen Meshy-credits uitgegeven bij deze documentatiestap.

## 8. Bouwvolgorde / definitie van gereed

1. Meshy-basisglb verkrijgen, werkelijke schaal/materialen/geometrie controleren.
2. Blender HQ-opsplitsing, exacte pivots, ladder, ankers, rig/clips, mobiele LOD/wrak maken; GLB/USDZ en viewer beschikbaar.
3. Godot: vier oude bloktorens vervangen op bestaande plaatsen; 12 unieke verdedigers toevoegen; MG-doelkeuze, bullet/hitboxes, botstesten, herbemanning, schade en puin.
4. `Beleg` aanpassen voor 4 torenstatussen/12 echte soldaten; dichtbij/ver weg zonder dubbele gevechten; route naar HK, hergroeperen en overwinning intact.
5. Gericht testen: 4 torens, precies 12 verdedigers, 650 HP, 36m, 8-schots salvo, geen kogels door muren, schutter vs. toren, twee reserve-overnamepogingen, ladder/poort, sloopcollision, live/offscreen, native iPhone.
6. Draft PR tonen met werkende viewer, teststatus en echte modelbestanden. **Geen merge/OTA zonder afzonderlijk expliciet akkoord.**

**Dit document is de gestarte ontwerpspecificatie — geen claim dat het complete speelsysteem al is gebouwd.**

## 9. Door Dennis goedgekeurd bronmodel — 5 november 2026

**Definitieve visuele bron:** [Meshy M2HB Guard Tower (Google Drive)](https://drive.google.com/file/d/1gl5CrJgdwT8JSqOcK_vR22GlBdmffV4v/view?usp=drivesdk). Dennis: **"Dit is de toren verander het uiterlijk niet zo is die goed."** De toren mag **niet** worden vervangen door een nieuw ontwerp of opnieuw door AI worden gegenereerd. Alle vormen, kleuren, textuurpatronen, het machinegeweer en het silhouet blijven volgens de bron.

**Technische inspectie, uitgevoerd op de originele bytes uit Drive (geen wijziging aan model):**

| Item | Gemeten/geverifieerd |
|---|---|
| Drive-bestand | `export_Meshy_AI_2026-11-05_cc5f29.obj`, **119.824.864 bytes** |
| Werkelijke inhoud | ZIP, ondanks bestandsextensie `.obj`; bevat **één OBJ, één MTL en één PNG** |
| Interne naam | `Meshy_AI_WWII_M2HB_Guard_Tower_1105083159_image-to-3d-texture` |
| Polygonen | **2.486.536 driehoekige faces** (OBJ, 1.242.576 vertices, 1.365.161 UV-coördinaten, 1.240.240 normals) |
| Textuur | **4096 × 4096 RGB** diffuse/albedo PNG gekoppeld via de MTL |
| Bounding box OBJ-ruimte | x: **1,429339**, y: **1,903092**, z: **1,084466** eenheden |
| Bij uniforme schaal naar 6 meter hoogte | Visuele buitenafmetingen ongeveer **4,51 × 3,42 × 6,00 m** inclusief alle uitstekende details; dit is **niet hetzelfde** als de afgesproken 2,6 × 2,6 m constructievoet |
| Source SHA-256 | `d023680c07b59a7505cc1a46c062b2b1de0477781c3324c6beac10eed495a94e` |

**Cruciale integratieregels:**

1. **Origineel bewaren.** De originele ZIP/OBJ/MTL/PNG is de ongewijzigde *visuele referentie*. Maak een technisch geoptimaliseerde, zelfstandige gamekopie; behoud materiaaluitstraling, vormen en herkenbare details bij controle in dezelfde camera. Geen herontwerp, geen kleurwijziging en geen stille vervanging van onderdelen.
2. **Schaalcheck vóór import.** De volledige bounding box omvat mogelijk uitstekende MG/ladder-details. Meet afzonderlijk de daadwerkelijke voetafdruk van de dragende constructie. Gebruik bij voorkeur **uniforme schaal** om vervorming te voorkomen. Als de toren niet binnen de bestaande hoekposities past, beoordeel eerst een technische verplaatsing/rotatie van de instance, **zonder het model visueel te veranderen** en zonder muur, poort en paden kapot te maken.
3. **Mesh optimaliseren.** De bron heeft ongeveer 2,49 miljoen triangles: vier ruwe instances zijn te duur voor het beoogde native iPhone-budget. LOD/retopologie met behoud van silhouet en gebakken oorspronkelijke 4K-textuurdetails is nodig; de eerdere mobiele trianglebudgetten zijn streefwaarden. Dit is technische verwerking, **geen artistiek herontwerp**.
4. **Animaties niet verzinnen.** De OBJ bevat één `o`-object en geen skeleton/animatieclips. De M2 kan pas werkelijk mikken/vuren zodra MG-onderdelen zonder zichtbaar uiterlijkverlies zijn afgesplitst en correcte pivots hebben. Voeg de bestaande gerigde schutter toe als afzonderlijk game-object. De ontbrekende dedicated normal-/roughness-/metallic-maps moeten gecontroleerd technisch worden afgeleid of worden aangevuld zonder het albedo uiterlijk te overschrijven.
5. **GitHub / authenticiteit.** De originele ZIP is **>100 MB**, de geëxtraheerde OBJ **>250 MB**: niet als gewoon GitHub-bronbestand pushen. Gebruik de gecontroleerde Drive-link als bron en plaats alleen de later gevalideerde, geoptimaliseerde game-GLB op een passende opslagroute (Git LFS/release/bestaande assetpijplijn, volgens repo-afspraken). Download of gebruik geen alternatief model.
6. **Acceptatie.** Vergelijk renders van bron en geoptimaliseerde GLB vanuit dezelfde gamecamera; textuur en silhouet moeten voor Dennis identiek ogen. Gameplay-integratie, echte iPhone-test en performance zijn **nog NIET GETEST**.


## 10. Productiestatus 5 november 2026

Een eerste Godot-implementatie en 60k GLB staan op deze Draft PR. Dit is **nog geen afgeronde 5a-3b**. Zie `bron/m2hb_toren/README.md` voor productie, echte beperkingen en open kwaliteitsgates. `tests/vijand_basis_test.gd` en `tests/vijand_m2_toren_test.gd` slagen; de lange aanvalstest slaagt na aanpassing van de testfixture voor de nu schietende MG’s. Native iPhone niet getest.
