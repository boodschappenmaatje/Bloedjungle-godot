# Bloedjungle — Schietsysteem 2.0: tactisch richten en trefferfeedback (optie B)

**Keuze:** optie B, 5 november 2026. **Status:** de eerste *jeep-MG pilot* is in Draft PR #230 in code gebouwd; regressie/IPA en native iPhone-acceptatie nog te verifiëren. Dezelfde UI uitbreiden naar handwapens is een volgende subfase. Alleen mergen na groen CI; de gebruiker heeft toestemming gegeven op 5 november. Geen OTA rechtstreeks vanaf deze Draft PR.

## 1. Probleem en doel

In de native iPhone-opname tijdens het schieten vanuit de bestuurbare jeep naar de vijandelijke M2-torens is slecht zichtbaar:
- waar de daadwerkelijke 3D-schietlijn van het wapen uitkomt;
- of de rechterstick een levende schutter selecteert, in plaats van de torenvoet of het bewegende metalen schild;
- waarom een schot geblokkeerd wordt;
- of de kogel echt schade heeft toegebracht.

**Doel:** de speler ziet *vóór* een schot het verwachte richtpunt en *ná* een schot uitsluitend fysiek bevestigde schadefeedback, zonder wijzigingen aan schadeberekening, besturing of de bestaande, smalle richthulp. Visuele stijl: subtiel militair, C&C Generals-achtig, leesbaar in liggende én staande iPhone-stand.

**Eerste verticaal speelbare proef:** bestuurbare jeep-M2 tegen een losse schutter op een vijandelijke M2-toren. Daarna hergebruik voor de soldaat met individuele vuurwapens (met name M1911), gevolgd door de overige direct gerichte spelerwapens. Tankkanon, raketten, explosies, artillery en teambevelen krijgen geen impliciete wijziging van hun gevechtsregels.

## 2. Vaststaand contract uit de huidige code

- `scripts/touch_sticks.gd`: rechterstick bepaalt `Game.aim`; naar de buitenring duwen bepaalt `Game.fire`. De bestaande M1911-trigger/hysterese en handmatig vuren blijven onveranderd.
- `scripts/jeep.gd`: `_aim_driven()` draait de MG en vuurt vanaf `_monding.global_position`. `_tower_gunner_solution(from, angle)` laat binnen **0,065 rad (~3,7°), 39 m en 0,56 hoogtehelling** alleen bij vrije 3D-zichtlijn beperkte schutterhulp toe. Geen groter aim-assistgebied, geen nieuwe lock-on en geen wijziging aan MG-spreiding, ritme of schade (**0,1 s; 9 damage**).
- `scripts/bullet.gd`: werkelijke kogel raakt tijdens `_physics_process()` het eerste geldige colliderobject; extra fortificatiecheck en afzonderlijke voertuigdetectie zijn bestaande uitzonderingen. Kogels kunnen afwijken door bestaande spreiding. **Een richtpreview mag nooit als bevestigde treffer worden geteld.**
- `scripts/vijand_m2_toren.gd`: bewegend metalen schild heeft een eigen fysieke collider; de losse torenschutter heeft een eigen vijandcapsule en HP; toren zelf heeft 650 HP. Onderscheid schutter, schild en torenvoet altijd expliciet.
- `scripts/enemy.gd` heeft al een optionele gezondheidsmarkering; `scripts/vijand_hk.gd` een bestaande levensbalk. Hergebruik waar mogelijk om dubbele balken te vermijden.
- `scripts/hud_extra.gd` en `scripts/touch_sticks.gd` beheren de bestaande overlays. HUD mag rechterstick, radar, teamwiel, pauze, grote kaart, munitie en schadevignet niet onderscheppen of afdekken.
- De bermfix (#223), muur-zichtbaar-fix (#224) en bestaande poort/slagboomlogica zijn buiten scope.

## 3. UX-specificatie (optie B)

| Moment | Wat de speler ziet | Betekenis |
| --- | --- | --- |
| Niet richten / in menu | Geen richtkruis of doelbalk | Rustig beeld |
| Rechterstick actief | Klein kruiskruis op geprojecteerd **wereldpunt** | Geschatte middenlijn van de **huidige echte** looprichting |
| Vrije lijn zonder doel | Wit/neutraal kruiskruis | Geen bevestigde vijand |
| Levende schutter met geldige zichtlijn | Rode hoekmarkeringen rond **schutter** en één kleine HP-balk | Je richt op een kwetsbaar doel, nog **geen** treffer |
| Muur, zandzak of stalen schild voor de lijn | Geel/amber kruis met klein schild-/blokkadeaccent op **eerste obstakel** | Je kogel kan hier niet vrij bij het doel komen |
| Kogel raakt obstakel | Bestaande materiaalinslag/vonken; **geen** rode hitmarker | Geblokkeerd, geen vijandschade |
| Kogel doet aantoonbaar schade | Kort wit/rood trefferkruis (~0,12–0,18 s), kleine HP-daling | **Bevestigde** schade, niet alleen voorspelde aim |
| Doel sneuvelt | Eén korte killbevestiging, dan doelmarkering weg | Geen markering aan dood/verwijderd object |

De HP-balk is **uitsluitend voor het actuele doel** (geen extra permanente balken boven alle vijanden). Hij staat boven het doel, niet over de schutter heen; de al bestaande `RangeMarker` en HK-balk krijgen voorrang op een tweede nieuwe balk. Bij doelwissel verdwijnt de vorige onmiddellijk; bij verlies van zichtlijn wordt de balk gedimd/verborgen. Zowel kleur als vorm verschillen per toestand: uitsluitend op rood/groen vertrouwen is onvoldoende.

## 4. Technisch ontwerp, per module

### A — Eén gedeeld richtresultaat, geen tweede richthulp

Voeg een **read-only aim-presentatiemodule** toe, bijvoorbeeld `scripts/combat_aim_feedback.gd`, met resultaatvelden:
`{muzzle: Vector3, direction: Vector3, predicted_point: Vector3, blocker: Object?, target: Node3D?, state: idle|clear|enemy|blocked, predicted_distance: float}`.

- **Jeep:** lees na de bestaande MG-rotatie de *feitelijke* `_gun`-richting en `_monding`; raadpleeg dezelfde `_tower_gunner_solution` voor de bestaande schutterhulp (ook tijdens richten, zonder te schieten). Geen duplicatie/verbreding van de selectiecriteria.
- Voor de preview volgt een **begrensde fysieke 3D-ray** hetzelfde effectieve wapenmasker en de uitzonderingen uit `Bullet.fire`/`Bullet._physics_process` (inclusief fortificaties, eerste obstakel, laag/hoog en uitzonderlijke voertuigtreffers waar relevant). Vermijd een naïeve ray die schieten door muren of het MG-schild suggereert.
- Projecteer `predicted_point` met de actieve `Camera3D.unproject_position()` naar de HUD; plaats de indicatie dus bij het **werkelijke wereldpunt** en niet op het joystickcentrum. Geen projectie achter de camera of buiten veilige schermmarges.
- Preview = centrale, deterministische schietrichting; **werkelijk kogeltraject** behoudt het bestaande toevalsverschil en is leidend voor de latere bevestiging. Indien het traject uit bereik loopt, toon een neutraal eindpunt op maximaal effectief bereik, niet een gefingeerd geraakt object.
- Maximum één actief doel en maximaal één previewray per update; bij niet-richten, dode speler, instappen/uitstappen, bouwmodus, pauze, kaart, shop en game-over alles opruimen.

### B — Lichtgewicht wereldgebonden HUD

Nieuwe `scripts/combat_target_hud.gd` als niet-interactieve `Control` (`mouse_filter = IGNORE`), gekoppeld aan de bestaande HUD. Teken slechts één kruis, maximaal vier doelhoeken en één contextuele HP-balk. Geen nieuwe textuur-/modelassets nodig. Zichtbaarheid respecteert Godot-camera-clipping, schermranden en safe areas; behoud radar/pauze/rechterstick. Houd elementen klein op iPhone (richtkruis ~16–20 px, geen volle schermbreedte-laser).

### C — HP en doelsoort

Voeg een kleine **read-only targetresolver** toe die schutter, generieke vijand, torenbody, HK-body en inert materiaal onderscheidt. HP = echte `hp/max_hp` van de getroffen actor of relevante eigenaar. Een metalen `MG_ShieldCollision` geeft **blocked**, niet ten onrechte de 90-HP-schuttersbalk. De 650-HP-torenbalk hoort uitsluitend bij de toren als daadwerkelijk beschadigbaar doel; **geen** automatisch wisselen naar de toren achter het schild.

### D — Bevestigde hitfeedback vanuit de echte kogel

Koppel een kleine event/signal aan de **bestaande schade-uitvoering**, niet aan de previewray of het afvuren. Concept: `hit_confirmed(source, damaged_entity, world_hit, actual_hp_delta, kind)`. De definitieve emitter bevindt zich na de feitelijke `hit()`/`damage()`-beslissing, inclusief indirecte bodies zoals `VijandHkBody`. Meet/bevestig werkelijke HP-daling (of expliciet succesvol schaderesultaat) voordat een hitmarker verschijnt. Gebruik alleen speler-bestuurde schoten voor de persoonlijke hitmarker; andere eigen soldaten, AI-kogels, afgedekte schoten en een onbeschadigbare schildbotsing geven geen vals positief signaal. Schademodifiers en killstreak blijven leidend zoals ze zijn.

### E — Tracers: verbeteren wat al bestaat

`scripts/bullet.gd` heeft al lichte kogeltracers/meshsporen. **Geen tweede kogelbaan of continue laser toevoegen.** Geef bestaande spelerschoten een betere top-down-contrastwaarde en een korte inslagflits op de **feitelijke** botsingslocatie, met klein begrensd effectbudget. Materiaalkeuze: staal = vonk; aarde = stof; vijand = al bestaande hit-FX + bevestiging. Geen extra rookpartikels per iedere MG-kogel, geen aanpassing van audio/ballistiek.

## 5. Implementatie in vijf kleine commits op deze Draft PR

1. **Contracttests eerst:** tests voor projectie, bestaande schutter-LOS, schildblokkade, onderscheid preview/bevestigde treffer, en iPhone-HUD-marges schrijven. Bekende code moet zo nodig aantoonbaar falen vóór de implementatie.
2. **Richtpreview + read-only targetresolver:** uitsluitend jeep als eerste verticale slice; bestaande `_tower_gunner_solution` hergebruiken; geen wijzigingen aan `_shoot()` of `Bullet.fire()`-waarden.
3. **Doel-HUD + HP:** screen-space projectie uit een wereldpunt, maximaal één doel, compatibel met bestaande vijand/HK-balken; duidelijk blocked versus enemy.
4. **Echte hitbevestiging + tracerafwerking:** event pas ná werkelijke schade; bestaande traileffecten afstellen zonder nieuwe kogelgeometrie; daarna M1911/overige handwapens aansluiten op dezelfde laag.
5. **Validatie + native iPhone-kandidaat:** headless Godot tests, iOS unsigned import/export en OTA **preview** (niet publiceren), vergelijkbare screenshots/opname en framemetingen. Eventuele wijzigingen aan machinegeweerritme, auto-aim, damage, spread, animaties of audio zijn een afzonderlijke keuze/PR.

## 6. Verplichte regressie- en acceptatiematrix

Nieuwe tests (bestandsnamen *voorgesteld*, nog niet aangemaakt):
- `tests/combat_aim_feedback_test.gd`: berekend richtpunt vs. de echte MG-loop; neutraal bij lege baan; identificeer schutter vs. schild; geen doel door muur; zichtbare doelwisseling.
- `tests/combat_hit_feedback_test.gd`: alleen hitmarker na echte HP-daling; nul schade / eigen schot tegen schild / gemist schot = **geen** hitmarker; correcte bron bij jeep/soldaat; dood doel verdwijnt.
- `tests/combat_hud_layout_test.gd`: liggend/staand, safe areas, menublokkade, geen touch-interceptie of dubbele HP-balk.
- Bestaand opnieuw uitvoeren: `tests/jeep_m2_schutter_test.gd`, `tests/auto_wapens_test.gd`, `tests/hud_layout_test.gd` en betrokken M1911-tests; waar nodig CI uitbreiden.

Native iPhone-acceptatie (deze gebruikersopname is de baseline):
1. Jeep rijden richting M2-toren; rechterstick zónder vuren: kruiskruis beweegt mee met de echte MG-loop.
2. Richt op de losse schutter: rode doelhoeken/HP uitsluitend op de schutter. Op bewegend stalen schild: **amber/blokkade**, geen schutter-hitmarker.
3. Schiet op schild, beton en muur: correcte materiaalimpact zonder vals rood trefferkruis. Schiet daarna op de blootliggende schutter: bevestigde hitmarker, zichtbare HP-daling; toren blijft bestaan nadat schutter sterft.
4. Buiten 3,7° blijft bestaande richthulp uit. Met muur vóór de schutter blijft hij buiten bereik. Werkelijke spreiding kan een schot alsnog laten missen; HUD liegt dan niet.
5. Wissel van jeep naar soldaat, herlaad M1911, open teamwiel/grote kaart, pauzeer en hervat: géén zwevend oude markering, geen schietbediening kapot.
6. Controleer dat de zwarte bermstreep wegblijft en de muur niet meer voor de speler verdwijnt.

**Prestatie-afspraken (doel, nog NIET gemeten):** preview maximaal 10–15 Hz; geen extra per-frame raycasts voor elk vijandpersonage; alleen één actieve HUD-overlay; beperkte pooled impact-events; geen runtime texture-/shadercompilatie in het gevecht. Vergelijk FPS, 1%-low, p99 en drawcalls met gelijke gevechtsscène/resolutie/kwaliteit op **native iPhone**, plus Windows-basistest. Verlies moet meetbaar en verklaarbaar zijn, niet verdoezelen met lagere gebruikersinstellingen.

## 7. Niet wijzigen

- MG: **9 damage, 0,1 s ritme**, bestaande spreiding, physics/hitmaskers, schutterhulp (**3,7° / 39 m / max 29°**) en bestaande automatisch bewegen/richten.
- M1911 en overige wapens: huidige herlaad-, magazijn-, geluid- en vuursystemen blijven exact werken.
- Geen nieuwe lock-on, hit-scan-overschakeling, onzichtbare auto-hit, extra schade of kogels door muren.
- Bestaande vijand-HK/toren/bunker-damage, doelen, botsingen, animaties, andere HUD-modules, database/save en OTA-keten niet veranderen.

## 5B. Vervolg — soldaat te voet (6 november 2026)

**Beslissing:** na de geslaagde native iPhone-test van de jeep-MG volgen de vijf rechtuit schietende soldatenwapens: M1911, Thompson, M1 Garand, M1897 shotgun en MG42. Bazooka (explosie/traject) en granaten zijn een afzonderlijke stap, **niet stilzwijgend inbegrepen**.

**Implementatie:** dezelfde `CombatTargetHud` ondersteunt bron `infantry` naast `jeep`. De getoonde richtlijn begint bij `SoldierModel.muzzle_position()`, volgt de huidige feitelijke `player.face`, gebruikt de centrale baan en de bestaande wapenstatistieken `speed * life`. Een apart `predict_infantry` kopieert het huidige Bullet-botsmasker inclusief de bestaande `over_wall`-uitzondering. Slechts één read-only previewray per circa 85 ms bij actief richten, niet voor andere soldaten of vijanden. De geparkeerde jeep mag het infanterierichtkruis niet wissen.

Alleen `Player._shoot()` geeft gewone fysieke kogels `feedback_source = "infantry"`; `Bullet` bevestigt uitsluitend een werkelijk verminderde vijand-HP. Richtpreview geeft nooit schade. De huidige M1911 kamer/magazijn, touch-stick-ondersteuning, herlaadknoppen, recoil, spread, vuurtempo en basisschade zijn onaangeroerd.

**Acceptatie:** `tests/combat_infantry_feedback_test.gd` (echte Colt-kogel, HP-event, muren, bron-eigendom HUD), `tests/combat_feedback_test.gd` (jeep-regressie), `tests/m1911_ammo_reload_test.gd`, iOS-export en OTA-preview. Native iPhone-FPS en visuele kwaliteit blijven pas bewezen na een echte test.

**Status:** code in afzonderlijke Draft PR; `main` onveranderd totdat de gebruiker per stap merge toestaat.

## Fase 3A — Bazooka-richtpreview (6 november 2026)

**Status: kandidaat in afzonderlijke Draft PR; nog niet gemerged of native getest.**

- Gebruik de centrale schietrichting vanaf `SoldierModel.muzzle_position()`, `Game.wstat("bazooka").speed * life` als **nominale** afstand en dezelfde botslagen als `Bullet.fire()`. De werkelijk afgevuurde raket behoudt willekeurige spreiding, snelheids- en levensduurvariatie.
- `scripts/bazooka_aim_feedback.gd` zoekt het eerste fysieke obstakel, controleert daarnaast de hoge perimeter via de bestaande 1,5 m-fortificatiesweep en gebruikt ook `Bullet.vehicle_on_path` voor auto's/bussen. Dit is alleen een **visuele voorspelling**.
- `CombatTargetHud` projecteert bij een voorspelde botsing een gedempte, onderbroken cirkel met de **bestaande** explosiestraal van 4,8 m op inslaghoogte. Bij vrije baan alleen een neutraal punt op maximaal nominaal bereik: de bestaande bazooka-raket ontploft **niet** automatisch bij het aflopen van zijn levensduur.
- Bescherm het bestaande vuur-, schade- en munitiecontract: 240 basisschade, 32 m/s, 1,0 s vuurritme, 4,8 m radius; `Player._shoot`, `Bullet._explode`, `Game.combat_hit_confirmed`, `Grenade` en `GrenadeAim` niet wijzigen.
- De ring is geen garantie dat de raket exact daar landt of schade veroorzaakt. Geen hitmarker bij alleen richtpreview; fysieke treffers en daadwerkelijke explosies komen later in fase **3B**.
- Tests: `tests/combat_bazooka_aim_test.gd` voor lege baan zonder valse explosie, gewone muur, over-wall uitzondering, hoge fortificatie, bestaande radius/waarden, HUD-eigendom, geen hit-signaal; plus de bestaande infanterie- en jeepregressies, iOS-export en OTA-preview. Native iPhone-opname en FPS nog afzonderlijk te meten.

## 8. Status / releasepoort

- [x] Optie B gekozen door gebruiker.
- [x] Huidige Jeep-, Bullet-, Enemy-, HUD- en schuttercode op `main` gelezen.
- [x] Bouwplan in afzonderlijke branch/Draft PR opgeslagen.
- [x] Jeep-MG pilotcode, wereld-HUD en automatische regressietest toegevoegd; on-foot/handwapens volgen later.
- [ ] Godot headless, iOS CI en OTA-preview groen op **implementatiecommit**.
- [ ] Native iPhone-beeld en FPS door gebruiker gevalideerd.
- [ ] Expliciete toestemming voor merge + OTA, **niet inbegrepen in dit verzoek**.
