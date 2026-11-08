# GENERALS_PLAN.md — Bloedjungle wordt een C&C Generals-achtige RTS met een speelbare soldaat

**Canoniek ontwerpdocument voor Claude Code (`CLAUDE.md`) en ChatGPT Codex (`AGENTS.md`).** Beide lezen dit bestand en volgen dezelfde keuzes. Wijzig het plan hier, niet in een van de twee korte bestanden. Vastgesteld door Dennis op 2026-11-01 via de keuzepagina; de ruwe keuzes staan onderaan.

## Doel
Bloedjungle krijgt het ritme en de systemen van *Command & Conquer: Generals* (2003): voorraad ophalen, basis opbouwen in een techboom, eenheden produceren met tegen-eenheden (counters), een vijandelijke basis slopen, en generaalskrachten. **De eigen twist:** de speler is zelf een soldaat in het leger en loopt, schiet en bestuurt voertuigen terwijl hij ook de basis en het team commandeert. Visuele stijl blijft onze realistische militaire jungle (zie `referentie-stijl.png`), geen kopie van de Generals-look. Kopieer geen assets, namen, stemmen of teksten van het originele spel.

## Beslissingen van Dennis
1. **De huidige golven (waves) gaan eruit.** Ze passen niet meer bij de game. De tegenstander wordt een **vijandelijke basis** die je moet slopen (D2). Dennis wil daarvoor NIET de bestaande stad gebruiken: de basis komt ver in het noorden achter de stad (keuzes 2 november, zie "Stap D2" onderaan). Bestaande golfcode, golf-HUD en de gebieden/kaart-PR #69 worden dan herbruikt of verwijderd: overleg bij die stap eerst wat blijft (bijvoorbeeld routes, bezette gebieden, kaart).
2. **Volgorde: de Generals-kern eerst** (fase 1 hieronder).
3. Realistische stijl, weinig op het scherm, native iPhone-app is de acceptatietest (zie `CLAUDE.md`/`AGENTS.md`).

## Wat wel gekozen is (prioriteit P1 eerst; S klein, M middel, L groot)
| Id | Onderdeel | P | Werk |
|---|---|---|---|
| A1 | Voorraaddepot + voorraadtruck: voorraadstapels op de kaart raken op, een truck rijdt heen en weer (nieuw model) | P1 | L |
| A2 | Zelf voorraad halen: speler kan de truck besturen of kisten oppakken voor bonus | P2 | S |
| A3 | Olieboortoren veroveren voor geld per minuut (nieuw model) | P2 | M |
| A4 | Stroom die echt telt: generator wordt centrale; te weinig stroom remt torens, radar en productie | P2 | M |
| A5 | Geldkisten uit wrakken | P3 | S |
| B1 | Bouwtijd met steigers en voortgangsbalk (verkopen/repareren blijven) | P1 | M |
| B3 | Hoofdkwartier (Command Center) als hart van de basis, vervangt de bunker als doel (nieuw model) | P1 | M |
| B4 | Techboom: gebouwen ontgrendelen elkaar | P1 | S |
| B5 | De vier "binnenkort"-gebouwen: Ziekenboeg, Munitiedepot, Werkplaats, Radiopost (nieuwe modellen) | P2 | L |
| B6 | Echte verdedigingsbouw: luchtafweer, raketbunker, betonbunker waar soldaten in kunnen | P2 | L |
| C1 | Bouwrij met meerdere eenheden + verzamelpunt | P1 | M |
| C2 | Soorten soldaten: geweerschutter, raketsoldaat, sluipschutter, hospik, ingenieur | P1 | L |
| C3 | Steen-papier-schaar: pantsertypes, raketten tegen tanks, luchtafweer tegen lucht | P1 | M |
| C4 | Veteraanrangen met strepen | P2 | S |
| C5 | Upgrades per gebouw | P2 | M |
| C6 | Artillerie of luchtafweervoertuig (nieuw model) | P3 | L |
| D2 | **Vijandelijke basis (ver in het noorden achter de stad) slopen om te winnen** | P1 | L |
| D3 | Vijand die zelf voorraad haalt en bouwt | P3 | L |
| D4 | Facties met eigen kleur (wij olijfgroen, vijand rood/zand) | P2 | M |
| E1 | Generaalsrang met sterren; elke rang laat een kracht kiezen; killstreaks blijven als snelle beloning | P1 | M |
| E2 | Meer krachten: artillerie, parachutisten, spionagesatelliet, noodreparatie, P-47-aanval | P2 | M |
| F2 | Garnizoen: soldaten in stadsgebouwen schieten uit de ramen | P1 | L |
| F4 | Radar alleen met radiopost | P3 | S |
| G1 | Radiomeldingen (korte Nederlandse stem/tekst: "Eenheid gereed", "Basis onder vuur") | P1 | S |
| G2 | Commandobalk in de tactische stand (uitzoomen = Generals-overzicht) | P2 | M |
| G3 | Kader slepen om te selecteren, groepen onthouden | P2 | M |
| G4 | Teamkleur-accenten | P2 | S |
| G5 | Stemmetjes bij bevelen | P3 | M |
| H1 | Na sneuvelen terugkomen bij het hoofdkwartier (twist) | P1 | S |
| H2 | Leiderschap: soldaten bij de speler schieten beter (twist) | P2 | S |
| H3 | Vertraging bij het geven van bevelen in tactische stand (twist) | P2 | S |

## Niet gekozen (niet bouwen zonder nieuwe vraag)
- B2 "Jij bent de bouwer" (gebouw groeit alleen als de speler erbij staat) en een bulldozer: **niet gekozen.** Bouwen gaat via de bestaande bouwmodus met bouwtijd (B1). Vraag Dennis nog wie de bouwer is voordat je dit uitwerkt.
- D1 Vijandelijke voertuigen als golf-uitbreiding: niet gekozen. De vijandelijke basis (D2) krijgt wel tank en jeep uit zijn garage: zie "Stap D2" (keuze G).
- E3 Superwapen, F1 Fog of war, F3 Techgebouwen veroveren (olie A3 wel), H4 Vijandelijke generaal.
- A2-twist en andere ideeën zonder vinkje staan niet op de planning.

## Fasering (Generals-kern eerst)
**Fase 1 — kern:** B3 hoofdkwartier, B1 bouwtijd met steigers, B4 techboom, A1 voorraaddepot + truck, C1 bouwrij + verzamelpunt, G1 radiomeldingen, H1 terugkomen bij het hoofdkwartier.
**Fase 2 — leger en vijand:** C2 soldatensoorten, C3 counters, D2 vijandelijke basis (golven eruit), F2 garnizoen, E1 generaalsrang, D4 facties.
**Fase 3 — verdieping (P2):** A2, A3, A4, B5, B6, C4, C5, E2, G2, G3, G4, H2, H3.
**Fase 4 — later (P3):** A5, C6, D3, F4, G5.

## Hoe we werken (voor Claude én Codex)
- **Begeleiding met keuzes (Dennis, 2026-11-01):** begin elke stap met een korte keuzekaart of keuzepagina over uiterlijk, gevoel, techniek en prestaties, met een aanbeveling. Bouw daarna de gekozen variant.
- **Eén stap per keer.** Dennis test elke stap voordat de volgende begint. Begin geen volgende fase zonder zijn "ga door".
- **Per stap:** korte voorstelbeschrijving, eigen featurebranch, **Draft PR**, tests (`tests/`) en voor/na-opnames. **Niet naar `main` mergen en niet naar de gedeelde OTA publiceren** zonder afzonderlijke uitdrukkelijke goedkeuring (zie `CLAUDE.md`/`AGENTS.md`).
- **Nieuwe 3D-modellen** (hoofdkwartier, voorraadtruck, olietoren, gebouwen, soldatensoorten): volg `docs/ASSET_QUALITY_STANDARD.md` en eerst ontwerpoverleg; viewer in `tools/blender-vq2-viewer/`.
- **Behoud** bestaande gameplay: bouwmodus (`scripts/buildings.gd`, `build_mode.gd`), teamwiel (`team_commands.gd`), killstreaks (`streak.gd`), tactische camera, bestuurbare voertuigen en vliegtuig, sloopsysteem. Meubels hebben collision (vaste regel).
- **Prestaties:** native iPhone-app draait nu ~110 fps; meld "NIET GETEST" als geen native meting beschikbaar is.
- Taal van de gebruiker: Nederlands.

## Hoe Generals het doet (korte referentie)
Voorraad = geld (trucks tussen stapel en depot, stapels raken op); stroom door centrales; bouwer bouwt in een techboom; productie in wachtrij met verzamelpunt; steen-papier-schaar tussen eenheden; veteraanrangen; generaalsrang met krachten en afkoeltijd; garnizoen in gebouwen; teamkleuren en commandobalk onderaan; radiomeldingen.

## Huidige stand van het spel (v162, 2026-11-01)
Wel: punten per kill + start-bouwkrediet; bouwmodus (kazerne, garage, helipad, vliegveld, zandzakken, muur; verkopen/repareren); kazerne traint rekruten (3 niveaus); garage jeep/tank/truck; helipad Apache; vliegveld P-47; generator met `Game.power`; teamwiel (aanvallen/verplaatsen/verdedigen/volgen); killstreaks Versterking en Napalm; tactische camera; wachten en patrouilles; sloopsysteem; golven met 7 vaste routes (gaan eruit). Niet: voorraad-economie, bouwtijd, techboom, hoofdkwartier, vijandelijke voertuigen of basis, veteranen, krachten per rang, fog of war.
Het vliegveld op basismaat wordt in een aparte thread afgehandeld (`docs`/PR daarvan).

## Ruwe keuzes van Dennis (2026-11-01)
Opmerking bij Tegenstander: "De golven (waves) zoals we nu hebben moet eruit dit past niet bij onze game meer."
Aangevinkt: A1-A5, B1 B3 B4 B5 B6, C1-C6, D2 D3 D4, E1 E2, F2 F4, G1-G5, H1 H2 H3, volgorde "Generals-kern eerst".
Keuzepagina: https://claude.ai/artifact/VNoxTR8VvsKn44oDdD3Jq1

## Stap 2 (keuzes van Dennis, 2026-11-01)
- **Bouwrij kazerne:** rij in het gebouwpaneel (blokjes, tik = annuleren met terugbetaling) en pictogrammen boven het gebouw; maximaal 5 in de rij en nooit meer dan de limiet van het kazerneniveau; ook een rij voor de garage (later).
- **Verzamelpunt:** vlag plaatsen (nu via het bouwscherm, tik op de grond), schakelaar "Nieuwe: volgen of vlag", later een mooie vlag in de wereld (nieuw model, eerst overleg).
- **Radiomeldingen:** Dennis spreekt zelf in; de stem wordt omgebouwd tot een niet herkenbare radiostem (toonhoogte, smalle klank, ruis, klik). Meldingen: bouw voltooid, basis onder vuur, gebouw vernield, eenheid gereed (elk twee varianten).
- **Terugkomen na sneuvelen:** na 8 seconden, met de wachttijd in een commandostand (tactische kaart met bevelen en bestellen). Eerst bij de bunker, later bij het hoofdkwartier.
- **Volgorde:** eerst bouwrij + verzamelpunt, dan radiomeldingen, dan terugkomen.

## Stap 4 (keuzes van Dennis, 2026-11-02): voorraadstapels, depot en voorraadtruck (A1)
- **Stapels:** vier tegelijk op de kaart (Bosrand ±65 m, Zuid ±110 m, Stad ±130 m, Oost ±130 m), elk 2.500; eindig. Is een stapel leeg, dan komt er een nieuwe verder weg. Je ziet de stapel in drie standen (vol, half, bijna leeg) en er staat een markering met teller op de tactische kaart.
- **Bomen:** voertuigen kunnen niet door bomen rijden (die vallen om). Oplossing: elke vaste truckroute krijgt een 6 m brede strook waar bomen, struiken, varens en rotsen worden weggehaald; trucks rijden kinematisch langs wegpunten en volgen de bestaande bospad- en straatroutes.
- **Depot:** het eerste depot staat er vanaf het begin met één gratis truck; extra depots koop je (800, bouwtijd). Per depot 600 per extra truck, maximaal 3. Een kapotte truck wordt een wrak en de lading is kwijt.
- **Geld:** kills geven geen geld meer (wel score); de killstreaks blijven. Geld komt uit voorraad (een rit levert 100 tot 400 op naar afstand), plus startgeld en golfbonus zoals voorheen.
- **Geen** zwevende +150 en **geen** radiomelding bij aflevering; wel stofwolk en zacht motorgeluid.
- **Zelf meedoen** (A2) nu niet. **Modellen** volgen in stap 4b (depot minimaal 40.000 driehoeken, 2K-texturen, kranen en schuur; truck met kraan en grijper die zichtbaar kisten in de bak legt) na een goedgekeurde Asset Design Specification (`modellen/voorraad/ASSET_DESIGN_SPEC.md`).
- **Volgorde:** 4a speelbaar met blokken (logica, wegen, paneel), daarna 4b de echte modellen.

### Stap 4b: de echte modellen (stijl Intendance, 2026-11-02)
- **Stijl:** Dennis koos "Intendance": geel-zwarte gevaarbanden, witte stencilletters (Engels: INTENDANCE, DEPOT 01, SWL 3T, KEEP CLEAR), olijfgroene kisten met gele band, een gele chevron als embleem. Bron en generators: `bron/voorraad/` (`maak_depot.py`, `maak_truck.py`, `maak_truck_wrak.py`, `maak_stapel.py`, gedeeld in `vc.py`); rapport: `docs/vq2/voorraad-4b-rapport.md`.
- **Depot** (`assets/voorraaddepot.glb` + `_lod1`): voetafdruk 9 x 6,5 m (was 8 x 6), golfplaatschuur met rolpoort (clip `Poort`, gaat open als een truck van het depot binnen 14 m komt), gele portaalkraan op rails (clip `Kraan-lossen`: pakt de kist van de laadplaat en zet hem op het opslagpallet), laadplaat, weegplateau, afzetpalen, hekwerk, lichtmasten (gloeien 's nachts). Botsblok = voetafdruk.
- **Truck** (`voorraadtruck.glb`, `_lod1`, `_wrak`): 6x6 met kraan en grijper; clips `Laden` en `Lossen` (4,5 s; de laad- en loostijd in de code is daarmee gelijkgetrokken, in 4a was dat 3,0 en 2,2 s). Wielen draaien met de snelheid mee. De grijper pakt 6,64 m voor de truck en zet neer 5,64 m voor de truck: daarom staat de truck bij een stapel `STOP_BEFORE` = 9,44 m van het midden (de afhaalkist ligt 2,8 m voor de stapel) en bij het depot `DOCK_OFFSET` = 4,39 m voor de voorkant, na een puntje op de as (`PRE_DOCK` 9 m) zodat hij recht op het depot afrijdt.
- **Stapel** (`voorraadstapel.glb`, één glb met `Stapel_vol`, `Stapel_half`, `Stapel_leeg`): de stapel draait zijn voorkant naar de kant van de trucks; de afhaalkist verdwijnt als de grijper hem heeft en ligt er weer als de truck weg is.
- **Contract van 4a blijft:** botsblok van de truck (2,6 x 2,4 x 6,4), route langs wegpunten, wrak en verloren lading, poortopening alleen voor rijdende trucks, depotpaneel, tests in `tests/voorraad_test.gd`.
- **Niet getest:** iPhone/native FPS (NIET GETEST), Safari/Xogot.

## Stap D2 (keuzes van Dennis, 2026-11-02): de vijandelijke basis, golven eruit
Keuzekaart: https://claude.ai/artifact/WEMBbr3H3zrHtBYQnqxAdn (ingevuld 2026-11-02 20:13Z; opgeslagen in de kaart als `keuzes/generals-fase2-vijandbasis`). **Er is nog niets gebouwd.** Dennis wil de bestaande stad niet als vijandbasis gebruiken; de vijand krijgt een eigen basis.

| Onderdeel | Keuze van Dennis (werk) |
|---|---|
| A Plek | **Plek 3: ver in het noorden, achter de stad (L).** Basis van 64 x 56 m rond (x -32, z -243), ± 215 m van jouw basis. De kaart moet daarvoor ongeveer 60 m naar het noorden groeien (nu loopt het terrein tot z = -200; nieuw terrein tot ± z = -262). Meeste kaartwerk en zwaarder voor de iPhone (NIET gemeten). De stad ligt dan tussen jullie in. |
| B Soort basis | **Spiegelbasis (M):** zoals de jouwe in vijandkleuren: hoofdkwartier, kazerne, garage, depot, generator, met muur, poort en wachttorens. |
| C Uiterlijk | **Bestaande gebouwen in vijandkleuren, plus een nieuw hoofdkwartier en nieuwe poort (M).** Kazerne, garage en depot hergebruiken met andere kleuren; alleen hoofdkwartier en poort zijn nieuw, op bunkerkwaliteit. *Opmerking van Dennis:* "De kleuren zijn veranderd, het is groen-geel geworden. Kijk naar mijn nieuwe vijandmodel *assault* en gebruik die kleuren subtiel." (Dus niet het eerder bedachte rood/zand, maar de groen-gele kleuren van dat model, subtiel toegepast. Dennis voegt de nieuwe vijandkleuren en het vijandmodel *assault* zelf toe via Codex (3 november): neem de kleuren van daar over zodra ze in de repo staan.) |
| D Wie maakt de modellen | **Dennis maakt ze in Meshy, Claude/Codex verwerkt ze** (zoals garage en voorraadtruck). Per nieuw model eerst een Asset Design Specification ter goedkeuring (`CLAUDE.md`). |
| E Verdediging (meerdere) | **Muur met poort en wachttorens met MG (M)**, **soldaten die op hun post blijven (garnizoen) (M)** en **zwaar geschut dat jou beschiet, een mortier (L, nieuw model en geluid: als laatste onderdeel).** |
| F Aanval | **Slimme aanval: hij kiest de zwakste kant van jouw basis (L).** *Opmerking van Dennis:* "Onderzoek als we hier zijn hoe Command & Conquer Generals hiermee omgaat en hoe het daar werkt." Dus eerst onderzoek (geen assets of teksten kopiëren), dan pas bouwen. |
| G Eenheden | **Soldaten plus tank en jeep uit zijn garage (L):** tank en jeep hergebruiken in vijandkleuren, laten rijden langs een route (dezelfde soepele bochten als de voorraadtruck, `scripts/voorraad_baan.gd`); vraagt vijand-AI voor voertuigen, schade en schieten. |
| H Winnen | **Zijn hoofdkwartier slopen is winnen (S).** |
| I Golven en stad | **Golven eruit; de routes blijven voor zijn aanvalsgroepen (M):** golfteller en golf-HUD verdwijnen; de 7 routes (`AanvalRoutes`: brug, wijk, kade, industrie, moeras, jungle, zuid) blijven, maar de groepen starten bij zijn basis en gebruiken de routes die bij de gekozen plek passen. |
| J Tempo | **Rust 3 minuten, daarna elke 90 seconden een groep; een spel van ± 25 tot 30 minuten.** |
| K Groei | **Echte vijand-AI met eigen voorraad en bouwen (L, "later"; dit is D3 uit het plan).** Daarmee verschuift D3 van fase 4 naar de vijandstap; bouw dit pas na de eerste speelbare versie. |
| L Zien (meerdere) | **Een rood vlakje op de tactische kaart, niets extra op het scherm (S)** en **een knop in het teamwiel om je leger de vijandbasis aan te laten vallen (M)** (richt "Aanvallen" van het teamwiel op de basis). |
| M Volgorde | **Eerst speelbaar met eenvoudige blokken (stap 5a), daarna de mooie modellen (5b).** |

**Stand en open punten (voor Claude én Codex):**
- Niets bouwen voordat Dennis "ga door" zegt; Draft PR, niet mergen of OTA zonder apart ja. Vraag bij de start van 5a wat 5a precies omvat als dat onduidelijk is.
- Onderzoek hoe Generals de aanvallen kiest (keuze F): **gedaan op 2026-11-03**, zie [docs/GENERALS_AANVAL_ONDERZOEK.md](GENERALS_AANVAL_ONDERZOEK.md). Kort: Generals gebruikt genummerde golven langs vaste routes (Center, Flank, Backdoor) met doelprioriteit per objectsoort, geen echte "zwakste kant"; ons voorstel is een eenvoudige score per route plus leren van succes en falen. Wacht op Dennis' keuze voordat 5a begint (Dennis koos op 2026-11-03: eerst alleen onderzoek).
- **Stap 5a-1 gebouwd (v187, Draft PR #209, 2026-11-03):** de kaart groeit tot z = -285 (grondplaat tot z = -300, `Data.WORLD_Z_N`, `Data.GROUND_Z_MIN`) en de vijandbasis van blokken staat op `Data.VIJAND_POS` (`scripts/vijand_basis.gd`: muur 64 x 56 m, poort in de zuidmuur, 4 hoektorens, hoofdkwartier, kazerne, garage, depot, generator; alles massief, nog geen schade, winnen, garnizoen of schietende torens). Test: `tests/vijand_basis_test.gd`. Volgende: 5a-2 (golven eruit, groepen vanaf zijn basis, hoofdkwartier slopen = winnen). Mooie modellen (5b): zie [VIJANDBASIS_MESHY_MODELLEN.md](VIJANDBASIS_MESHY_MODELLEN.md).
- **Stap 5a-2 gebouwd (v188, Draft PR, 2026-11-04):** golven eruit, aanvalsgroepen uit de poort van de vijandbasis, hoofdkwartier slopen = winnen. **Schema:** 3 minuten rust (`Data.GROEP_RUST`), dan elke 90 s een groep (`Data.GROEP_TUSSEN`), ook als de vorige nog loopt; `Data.build_group(n)` (4 + 2,4 n vijanden, zelfde mix als een golf); alleen de stadsroutes (`AanvalRoutes.pick_group`, `path_from_base`: eerst de poort van de vijandbasis, dan de route); "prep" betekent nu "geen groep onderweg" (wapenkamer en stadseditor kunnen alleen dan; **bouwen kan altijd**, ook tijdens een groep, op Dennis' verzoek van 4 nov; het aftellen loopt dan door), "play" = een groep loopt; de golfplaat toont "EERSTE/VOLGENDE GROEP" met aftellen en de routes, tijdens een groep staat het aftellen bij de vijandenteller; geen bonuspunten meer per golf; killstreak begint opnieuw als een groep verslagen is. **Vijand-HK:** Dennis' eigen model "Enemy hk" (Meshy, 2 miljoen driehoeken) teruggebracht tot 44.891 driehoeken (minimaal 40.000 op zijn verzoek), 9 m breed zoals het oude blok, `assets/vijand_hk.glb`, bron en pijplijn in `bron/vijand_hk/`; `scripts/vijand_hk.gd`: 2.500 levenspunten, kogels van jou doen 10% (ook die van Apache en jeep), raketten, granaten, artillerie, tankgranaten en ontploffingen volle schade; rook bij 60%, vuur bij 30%, levensbalk boven het dak, instorten tot een zwart wrak, melding en eindscherm "MISSIE GESLAAGD" (`Game.win`, `Game.won`). Tests: `tests/vijand_hk_test.gd`, `tests/vijand_basis_test.gd`, `tests/hud_layout_test.gd`. Levenspunten, groepsgrootte en tempo zijn voorstellen om te testen; native iPhone NIET GETEST. Nog niet: garnizoen en schietende torens (5a-3b), rood vlakje op de tactische kaart en Aanvallen-knop (5a-3a, zie hieronder), keuzekaart voor de aanvals-AI, mortier.
- **Stap 5a-3a gebouwd (v190, Draft PR, 2026-11-04):** de vijandbasis als rood vlakje op de radar (met een stip op het HK; verdwijnt als het HK instort) en **Aanvallen** in het teamwiel op de vijandbasis. Kies Aanvallen in het wiel (de radar-vlak knippert en een melding zegt wat je kunt tikken), tik dan op het rode vlakje op de radar (ruim genomen voor een duim; het pauzeknopje in de hoek blijft pauze), of op de vijandbasis zelf in beeld (tactische camera: muur, toren, gebouw, HK of de grond erin): bevel `basis` (`TeamCommands._attack_base`, `Game.squad_order`; `Game.troop_mode` wordt "hold"). Je soldaten marcheren dan de route van de aanvalsgroepen in omgekeerde richting (`AanvalRoutes.march_path`: brug, Hoofdstraat, westelijke straat, uitgang west, dan recht naar de poort en erdoor; `march_start` laat soldaten die al in de stad staan daar beginnen) naar hun plek op het binnenplein tien meter voor het HK (`VijandBasis.attack_spot`, waaier van zeven, daarna rijen). **Ver van jou (meer dan 62 m, buiten 48 m van de bunker) lopen ze onzichtbaar en zonder botsingen, elke vierde stap** (`Ally._is_far`, zelfde regel als vijanden; alleen voor `basis` en `follow`, een soldaat die een plek verdedigt blijft gewoon echt); komt jij binnen 55 m, dan verschijnen ze met botsingen. Eenmaal binnen 16 m van het HK (`Ally._hk_target`, ook voor soldaten die gewoon met je meelopen) schieten ze erop als er geen vijand in zicht is: 16 schade per kogel x 10% = 1,6 per kogel, ruim 3 per soldaat per seconde. **Zonder jou (keuze B van Dennis, 4 nov): beleg op afstand** (`scripts/beleg.gd`). Soldaten die onzichtbaar op hun plek voor het HK staan vechten niet echt maar worden één keer per seconde uitgerekend: elke soldaat beschadigt het HK (`Ally.dmg` x `Beleg.TREFFERS` = 1 treffer per seconde, het HK laat daar 10% van door), en de basis schiet terug (`Beleg.TORENVUUR` = 1,25 schade per seconde per wachttoren van de vijandbasis, nu 4 torens = 5 per seconde) op de soldaat met de minste levenspunten, zodat ze één voor één sneuvelen (echt weg; de kazerne kan ze opnieuw opleiden). Meldingen: "LEGER BIJ DE VIJANDBASIS", "SOLDAAT GESNEUVELD" (hooguit één per 5 s), "LEGER VERSLAGEN"; de radar krijgt een oranje rand om het rode vlakje zolang het beleg loopt. Rekenvoorbeeld (voorstel om te testen): 6 soldaten niveau 3 (130 hp, 21 schade) doen ongeveer 45% van het HK voor ze allemaal gesneuveld zijn; alleen winnen kan dus niet met het huidige maximum van 6 soldaten, jij moet erbij of meerdere keren sturen. Zodra jij binnen 55 m komt zijn ze echt en rekent het beleg niet meer; de echte basis heeft nog geen schutters, dus dat gevecht is voorlopig zonder verliezen. **De verdediging is nu een vast bedrag per toren (voorlopig):** 5a-3b (garnizoen en schietende MG-torens) vervangt dat door wat er echt schiet. Volgen roept ze terug (loopt dan ook onzichtbaar als ze ver zijn). Test: `tests/aanval_basis_test.gd` (draait mee in `.github/workflows/vijand-basis.yml`; radar-tik, bevel, de hele mars van drie soldaten zonder door de rivier of de muur te gaan, beleg op afstand met verliezen en meldingen, echt schieten als jij komt, Volgen, leger verslagen). Native iPhone NIET GETEST. Nog niet: garnizoen en schietende MG-torens (5a-3b), keuzekaart voor de aanvals-AI, mortier.
- **Grote kaart en commandowiel boven je duim (v191, Draft PR, 2026-11-04, op verzoek van Dennis na zijn test van v190):** een tik op de kleine radar rechtsboven opent een **grote kaart** (`scripts/grote_kaart.gd`, kaartvlak met de verhouding van de wereld, liggend: titel en uitleg links en een legenda rechts, staand: kop boven de kaart; dezelfde tekenroutine als de radar via `HudExtra.draw_map_on`, op de grote kaart ook je soldaten als blauwe stippen). Zonder commandokeuze is het een overzicht (tik ergens of SLUIT om te sluiten). **Wacht het commandowiel op een doel (Aanvallen, Verplaatsen, Verdedigen)**, dan opent een tik op de radar de kaart in doelstand: tik op het rode vlak (Aanvallen = bevel `basis`, `TeamCommands.pick_from_map`) of op de grond (een punt in de wereld); Verplaatsen/Verdedigen in de vijandbasis kan niet (de kaart blijft open met een melding). SLUIT of een tik naast het paneel sluit de kaart; het bevel blijft dan wachten. Het spel loopt door achter de kaart, lopen en schieten staan stil (`TouchSticks` kijkt naar de groep `kaart_open`) en de kaart gaat vanzelf dicht bij pauze, bouwen of game over. De tik op het rode vlak rechtstreeks op de kleine radar is vervangen door deze kaart (`HudExtra.base_hit` is weg, `radar_hit` blijft). **Commandowiel:** bij vasthouden van BOUW / TEAM hing het wiel naast je duim, waardoor je duim op VERDEDIGEN lag en je hand over VERPLAATSEN; het middelpunt hangt nu `WheelArt.OUTER + 8` boven je duim (`TeamCommands._wheel_center`), en zolang je vinger binnen 24 punten van waar hij begon blijft, is er nog geen keuze (`TeamCommandController.move`, zoals bij loslaten). **Route-fix:** wie nog binnen de muur van de bunker staat en naar buiten moet, loopt eerst door de poort (`Route.waypoint`); daarvoor liep hij rechtstreeks naar de brug en schuurde langs de muur tot hij de poortopening vond (soldaten die naar de vijandbasis vertrokken verloren zo seconden). Tests: `tests/grote_kaart_test.gd` (aanrakingen via `push_input`: openen, overzicht, doelstand, tik op het vlak, grondpunt, SLUIT, geen sticks achter de kaart, wiel boven de duim), `tests/aanval_basis_test.gd` bijgewerkt (4x gedraaid, steeds 0 fouten), foto's in `/mnt/project-files/vijandbasis/grote-kaart/`. Native iPhone NIET GETEST (duim, tikken en schaal).
- Kaart 60 m groter naar het noorden: terrein (grondplaat 440 m), camera- en speelgrenzen, kaart/minimap, rivier en stadsroutes erbij trekken; iPhone-prestaties NIET gemeten.
- Spelfeiten die hierbij horen: jouw basis 56 x 56 m op de oorsprong (`Data.COMPOUND` 28), rivier z ≈ -92 (`Data.river_z`), brug x = 0, stad x -62..72 en z ≈ -96..-158, `ETYPES` zijn nu alleen infanterie (mes, geweer, raket, zwaar), `Voorraad.SITES` heeft 8 stapelplekken.


## Stap 5a-3b — gerichte naverbetering jeep-MG en schutterdekking (5 november 2026)

Tijdens de eerste native iPhone-test van de vier Browning M2HB-torens schoten de torens wel, maar kon de speler vanuit de bestuurbare jeep de torenschutters niet uitschakelen. Bestaande `scripts/jeep.gd` vuurde de .50-MG uitsluitend horizontaal; de aparte Assault-capsule van de schutter staat op het platform op ca. 4,4 m hoogte. De afschermende constructie stond ook als één 5 m hoge box-collider in de wereld.

**Reparatie in eigen Draft PR (geen wijziging van goedgekeurde modellen/waarden):**
- Wanneer de bestuurder met de rechterstick binnen **3,7°** op een levende, zichtbare torenschutter richt, geeft de jeep uitsluitend voor die opname een **beperkte verticale richthulp** tot 29° en binnen 39 m. Het eigenlijke vuren blijft handmatig. Kogels gebruiken een echte 3D-baan vanaf de Jeep-Monding.
- Richting/schietlijn wordt via fysiek raycast gecontroleerd op de bestaande schutter-capsule en muur-, natuur-, bunker- en fortificatie-colliders; **geen schieten door muren of schild**. Buiten de smalle richtkegel blijft het oude gedrag intact.
- De bestaande beton-/onderbouwcollider blijft. Het werkelijke bewegende metalen MG-schild krijgt een **dunne, meedraaiende** aparte fysieke collider; de bestaande Assault-schutter heeft zelfstandig 90 HP. De toren zelf behoudt 650 HP en verandert niet in uiterlijk.
- Verlies van de schutter stopt MG-vuur onmiddellijk. Alleen een van de twee bestaande reserves kan na de al gebouwde route en ladder weer bemannen. Aantallen 4/4/2/2 wijzigen niet.
- Contracttest `tests/jeep_m2_schutter_test.gd` controleert kogelcontact via de echte Bullet-physics, afscherming, blokkade door een muur, overlijden en stilvallen MG; `tests/auto_wapens_test.gd` bewaakt bestaande jeep/voertuigwapens. De basisregressie blijft vereist.
- **Status is pas geslaagd als CI/Godot en later fysieke native iPhone-OTA-test dit bevestigen.** Geen automatische merge naar `main` en geen OTA-publicatie vanuit deze Draft PR.

**Afzonderlijke vervolgstap ná de jeepreparatie:** tactische bewaking en korte patrouilles voor de vier poortbewakers, twee HK-bewakers en twee reserves binnen het kamp, als aanvulling op de reeds goedgekeurde dekking, flankeren en postbezetting. Geen extra vijanden of nieuw model zonder aparte keuze.


### Vervolg 5a-3b — bevestigde schuttertreffers en jeep-respawn (05-11-2026)

Na native iPhone-test is gekozen voor **trefferfeedback B**: bij echte schade aan een M2-schutter een korte wereldmarker, iets grotere zichtbare gezondheidsbalk en gedempte bevestigingsklik; bij overlijden tijdelijk **MG UIT**. Betonnen toren en stalen schild geven géén schutterhitmarker. Bestaande bloed, getroffen houding, sterfanimatie en torenovername blijven intact. De kleine effecten hebben geen nieuwe assets nodig.

**Vastgestelde respawnbug:** `jeep.gd` riep `_toggle()` bij overlijden aan, maar `_toggle()` retourneert voortijdig voor `p.dead`. `driven` bleef daardoor aan en overschreef de respawnpositie; camera bleef bij het voertuig. Correctie: sterfte dwingt uitstappen af, `player.respawn()` herstelt voertuig-/zichtbaarheids-/collisionstatus, en de camera springt na respawn direct naar de eigen basis. De jeep blijft achter.

**Acceptatietests**: `tests/jeep_respawn_feedback_test.gd`, bestaande `tests/respawn_test.gd` en `tests/jeep_m2_schutter_test.gd` plus vijandbasis-/voertuigregressie, iOS-export en OTA-simulatie. Nieuwe featurebranch/Draft PR; geen merge naar main of OTA-publicatie zonder afzonderlijk akkoord. Fysieke iPhone-weergave en FPS blijven pas bewezen na de native test.

## Schietsysteem 2.0 — Tactisch richten en trefferfeedback (optie B, 5 november 2026)

**Gebruikerskeuze:** optie B, met een klein richtkruis op het voorspelde **wereldpunt**, subtiele doelmarkering en HP voor één geselecteerde vijand, zichtbare bestaande kogeltracers en een **bevestigde** trefferindicator. De eerste proef is de bestuurbare jeep-M2 tegen een vijandelijke torenschutter; dezelfde presentatielaag wordt daarna uitgebreid naar de individuele spelerwapens, zonder hun schietregels te wijzigen.

**Technisch contract:** niet meer richthulp dan de huidige 0,065 rad (~3,7°), 39 m en 0,56 stijging bij de jeep; schieten blijft handmatig. Een rode hitmarker verschijnt uitsluitend bij echt vastgestelde schade, nooit op een metalen schild of een gemist schot. Doel-HUD mag bestaande markeringen, joystick, kaart of teamwiel niet blokkeren. De fix voor de zwarte bermstreep en zichtbare basismuur blijft intact.

**Uitvoerbaar bouwplan en tests:** [Schietsysteem 2.0 — optie B](SCHIETSYSTEEM_2_0_BOUWPLAN.md). **Status:** jeep-MG verticale proef in Draft PR #230 geïmplementeerd (wereldrichtpunt, doelherkenning, contextuele HP, fysiek bevestigde treffers, duidelijkere tracers); Godot/iOS-regressies nog als releasepoort, handwapens volgen na de jeep-proef. Niet mergen of OTA-publiceren zonder expliciete toestemming (op 5 nov gegeven voor merge **na groene tests**).

### Schietsysteem 2.0 — vervolg handvuurwapens (6 november 2026)

Na geslaagde native iPhone-test van de jeep-MG koos Dennis voor voortzetting van Schietsysteem 2.0 vóór de geplande patrouilles. Doel: dezelfde tactische wereldindicator en uitsluitend **echt bevestigde** schadefeedback voor M1911, Thompson, Garand, shotgun en MG42. Het bestaande schieten, herladen, richthulp, ammo en spreiding blijven ongewijzigd. Bazooka/explosies volgen pas na een afzonderlijke keuze. Bouw in een eigen Draft PR; voer gameplay, Colt-munitie en iOS/OTA-preview tests uit. **Geen merge naar main zonder apart akkoord**. Zie [SCHIETSYSTEEM_2_0_BOUWPLAN.md](SCHIETSYSTEEM_2_0_BOUWPLAN.md).

### Schietsysteem 2.0 — Fase 3A bazooka-richtpreview (6 november 2026)

Na de voltooide jeep-MG en infanterie-uitbreiding is gekozen voor de bazooka als afzonderlijke stap. Een voorspelde fysieke inslagplek met een subtiele ring van de bestaande explosiestraal (**4,8 m**) verschijnt alleen als de centrale raketbaan vóór de nominale maximale afstand een object raakt. Muren, hoge basismuur en voertuig-colliders tellen mee. Vrije banen geven geen misleidende explosiecirkel omdat de bestaande raket bij levensduureinde niet ontploft. **Geen** wijzigingen aan de bazookaschade (**240** basis), snelheid (**32 m/s**), vuurritme (**1,0 s**), ammo, raket-FX, explosielogica of granaten. Volgende aparte stap: bevestigde explosieschade (3B), daarna granaten (3C). Werk in een **Draft PR**, testen vóór merge, geen automatische OTA-publicatie. Zie [SCHIETSYSTEEM_2_0_BOUWPLAN.md](SCHIETSYSTEEM_2_0_BOUWPLAN.md).

### Granaatbesturing 2.0 — UITRUSTING apart, rechterstick richten/loslaten (6 november 2026)

De native iPhone-test toonde onbedoelde wielkeuzes doordat de knop GEBRUIK tegelijk granaatknop en uitrustingswiel was. **Gekozen optie B:** UITRUSTING als aparte keuzeknop boven/links van de wapenbalk; GRANAAT kiezen sluit het wiel zonder te gooien; een **nieuwe** rechterstick-aanraking richt met de bestaande boog en landingscirkel; rechterstick loslaten gooit **exact eenmaal**; terug naar het midden annuleert. In deze modus schiet de rechterstick nooit kogels. Bestaande granaatfysica, schietschade, range, touch-left-stick en waarschuwingen blijven intact. Zie [GRANAAT_BESTURING_2_0.md](GRANAAT_BESTURING_2_0.md). **Draft PR, nog niet mergen of OTA publiceren** totdat Godot- en iOS-testresultaten én een afzonderlijke toestemming binnen zijn.

## Stap MCV — uitklapbare bouwwagen als start van je basis (keuzes van Dennis, 7 november 2026)
**Idee:** zoals in Command & Conquer begin je met een grote bouwwagen (MCV). Je kiest een plek, klapt de wagen uit, en dat wordt je hoofdkwartier (B3) en het hart van je kamp. **Er is nog niets gebouwd.** Past bij Fase 1 (B3, B1, B4); bouw niets voordat Dennis "ga door" zegt, Draft PR, niet mergen of OTA zonder apart ja.

| Vraag | Keuze van Dennis |
|---|---|
| 1 Waar mag je uitklappen? | **Overal, behalve bij water en in de stad.** Altijd aan dezelfde kant van de rivier als de huidige basis (`Data.river_z`), links (west) of rechts (oost) maakt niet uit. **Bomen, struiken, varens en rotsen verdwijnen** op de plek waar je uitklapt (zelfde aanpak als de vrijgemaakte stroken voor de voorraadtrucks). |
| 2 Inklappen? | **Nee.** Is het spel eenmaal begonnen en is de wagen uitgeklapt, dan kun je niet meer inklappen of verhuizen. Begin je een nieuw potje, of heb je verloren, dan kies je opnieuw. |
| 3 Muur en torens | **Zelf bouwen via het bouwmenu.** **Muur:** je trekt hem met je vinger; de eerste keer kost het niets, daarna **50 per muur**. **Torens:** je krijgt er **4 gratis aan het begin**, daarna **100 per stuk**. |

**Open punten om bij de start van deze stap te bepalen (nog niet beslist):**
- Wat "per muur" is: per segment, per tik of per getrokken lijn.
- Wat de "eerste keer gratis" precies omvat: één getrokken omheining, of een vast aantal segmenten.
- Of de 4 gratis torens overal geplaatst mogen worden, of binnen een straal van het hoofdkwartier.
- Hoe ver de plek van het water, de stad en de vijandbasis moet blijven (rood/groen voetafdrukspook bij het kiezen).
- Waar de speler en het eerste depot met truck verschijnen als de basis niet meer op de oorsprong staat; wat er met het vaste kamp (`Data.COMPOUND`, 56 x 56 m, poort, vier torens) gebeurt.

**Wat mee moet verhuizen van de vaste basis naar het hoofdkwartier:** terugkomen na sneuvelen (H1), eerste depot en truck, radar en teamwiel, startplek van de speler, en de aanvalsroutes van de vijand (doel wordt het nieuwe hoofdkwartier). Eerst speelbaar met blokken (wagen en hoofdkwartier als blokken), daarna de modellen via een Asset Design Specification. Native iPhone-test: NIET GETEST.

### MCV — aanvullende keuzes van Dennis (7 november 2026, tweede ronde)
- **Muur trekken:** zoals je in de stad een weg trekt (zelfde bediening als de stadseditor). "Per muur" = zoals die bediening dat telt; vastgelegd: **een complete omheining is gratis** (de eerste keer), daarna 50 per muur.
- **Torens:** de 4 gratis torens (en latere van 100) mogen **alleen bij de basis** staan.
- **Het huidige vaste kamp vervalt.** De wagen is het nieuwe begin: muur, poort, torens, wachtposten en bijbehorende vaste props op de oorsprong (`Data.COMPOUND`-code: `gates.gd`, `base_props.gd`, `wachtpost.gd`, `patrouille.gd`, `generator.gd`, `route.gd`, `voorraad.gd`, enz.) moeten dynamisch worden of vervallen.
- **Gebouwen blijven bouwbaar** (kazerne, garage, enz.) via de bestaande bouwmodus, rond het hoofdkwartier.
- Nog te beslissen: zie de vragenlijst in het gesprek van 7 november (afstand tot water/stad/vijandbasis, startplek en eerste depot/truck, bunker, HK-gebied, radar, aanvalsdoel van de vijand, wat er met bestaande wachten gebeurt).

### MCV — derde ronde, antwoorden op de tien vragen (Dennis, 7 november 2026)
1. **Start:** je begint *in* de wagen, rijdt hem naar een plek, klapt hem uit, en dan komt de speler eruit.
2. **Hoofdkwartier:** blijft bestaan (is al vervangen); het komt uit de wagen geklapt.
3. **Terugkomen:** na 8 s bij het kamp (het HK). **Is het HK vernield, dan is het spel voorbij.**
4. **De wagen is het HK** (geen apart gebouw ernaast).
5. **Depot en eerste truck gratis**, maar je plaatst het depot zelf in je nieuwe kamp, en je kiest zelf naar welke voorraadstapel de truck rijdt.
6. **Startgeld: 2000** (ongewijzigd).
7. **Afstand tot water/stad/vijandbasis:** door Claude in te vullen (voorstel: zie PR/stap); **geen vast kader, het kamp mag zo groot worden als je zelf wilt.**
8. **Poort:** je plaatst de poort zelf in de muur.
9. **Rust voor de eerste vijandelijke groep: 10 minuten** (was 3, `Data.GROEP_RUST`). Aanname, nog te bevestigen: de klok start bij het uitklappen.
10. **Wachten/patrouilles:** je koopt ze als mannetjes bij de kazerne en zij lopen patrouille; de vaste wachtposten van het oude kamp vervallen.

**Gevolgen om rekening mee te houden:** geen vast kader betekent dat muur, poorten, patrouillelijnen, `Route`, voorraadroutes, radar en vijandige aanvalsdoelen allemaal van de wagenplek moeten uitgaan en niet van een vast vierkant; prestaties op iPhone met een groot kamp NIET GEMETEN. De bunker als doel vervalt: het HK (de wagen) is het doel.

### MCV stap 1 gebouwd (8 november 2026, Draft PR): bouwwagen, uitklappen, hoofdkwartier
Gebouwd volgens de keuzes hierboven; **alleen in de nieuwe MCV-modus** (`Data.mcv_mode`, aan via START MISSIE en de stadseditor in het hoofdmenu; uit voor het oude spel en de bestaande tests, tot het vaste kamp in stap 4 is opgeruimd).
- **Wagen** (`scripts/mcv.gd`, een blok als model): je begint erin op de kale open plek (0, 6), rijdt met de linkerstick (7 m/s, palmen en jungle-bomen vallen om), een spookbeeld van 14 x 16 m is groen (kan) of rood (kan niet), knop **UITKLAPPEN**.
- **Plekcontrole:** minstens 12 m van het water, alleen aan jouw kant van de rivier (de stad ligt aan de overkant), 14 m van de kaartrand, niets massiefs (muur, gebouw, vat) in de weg. Bomen, struiken, varens, gras en rotsen zijn geen bezwaar en verdwijnen (`Foliage.clear_for_building` met rotsen). Dit geldt ook voor alle gebouwen en muren die je later bouwt (rotsen tellen in MCV-modus ook mee).
- **Uitklappen** (na 1,4 s): de wagen verdwijnt, het hoofdkwartier (bunkerbody, HK-model, zandzakken, voorplein) staat op zijn plek met dezelfde draaiing (deur naar de achterkant van de wagen), de speler stapt eruit en `home` = 4 m voor de deur. `Game.base_pos`/`base_yaw`/`base_point()`/`base_home()`. **De klok van 10 minuten (`Data.MCV_RUST`) begint bij het uitklappen**; ervoor staat hij stil, er zijn geen vijanden en bouwen kan niet.
- **Alles volgt het hoofdkwartier:** vijanden lopen en mikken op `Game.base_pos` (afstand rekent met de draaiing van het HK mee), `Route.waypoint` kent in MCV-modus alleen nog de rivier (brug/ondiepte) en verder rechtdoor, radar (geen vaste muur, HK-stip pas na het uitklappen, radarring en zicht rond het HK), HK-radar (`HqPerks`), wachtposten van soldaten (`Ally`), bouwcamera, bouwregels (`Buildings.placement_status`: overal aan jouw kant van de rivier, geen vast kader, geen muurafstand meer). Sneuvelen: na 8 s terug bij het HK; HK vernield = spel voorbij.
- **Weg in MCV-modus:** vaste muur, poorten, torens, hut, zandzakken en kisten van het oude kamp (`BaseProps.build` wordt niet aangeroepen), wachtposten, generator, patrouilles, aangestampte kampbodem en poortpad (shader `base_ground`), het eerste depot, de eerste truck en de voorraadstapels (komen terug in stap 2).
- **Bekende beperkingen van stap 1:** geen muren trekken, torens of poort (stap 3); wagen is een blok; geen depot of inkomen (je hebt 2000 punten en 1000 bouwtegoed om kazerne en garage te bouwen); rotsen en vaten worden pas bij het uitklappen/bouwen verwijderd (vaten blokkeren het uitklappen); verdwijnen van het oude kamp-gras op (0,0) is niet nodig (daar wordt niet geplant).
- **Test:** `tests/mcv_test.gd` (rijden, water/overkant/kaartrand verboden, drukste plek met 185 planten uitklappen en wegruimen, bunker op de wagenplek, klok, bouwen na het uitklappen, terugkomen, vijand/route, HK vernield = spel voorbij), workflow `.github/workflows/mcv.yml`. **Niet getest:** native iPhone (sturen, tikken, beeld, FPS), visuele opnames (de omgeving heeft geen GPU; alleen logica draait headless).

### MCV stap 2 gebouwd (8 november 2026): gratis depot, eerste truck, vrije routes
Naar de keuzes van Dennis (derde ronde, punt 5): depot en eerste truck zijn gratis, je zet het depot zelf neer en kiest zelf naar welke stapel de truck rijdt. Alleen in MCV-modus; het oude spel met vast kamp werkt nog zoals voorheen (`tests/voorraad_test.gd`).
- **Gratis depot:** na het uitklappen is `Game.free_depot` 1. In het bouwmenu staat het depot als **GRATIS** (`Buildings.cost_of`); het heeft de gewone bouwtijd met steigers en kan overal staan waar bouwen kan. Verkopen levert niets op. Is het depot klaar, dan verschijnt de eerste truck gratis (`b.gratis_truck`, `Voorraad._physics_process`); extra depots (800) en trucks (600) zijn gewoon te koop.
- **Stapels:** de eerste vier voorraadstapels liggen er al vanaf het begin van het spel (Bosrand, Zuidveld, Stad, Oostveld), ook voor het uitklappen. Jij kiest in het depotpaneel naar welke stapel de truck rijdt (of laat het automatisch).
- **Routes zonder vast net:** de truck rijdt recht vooruit het depot uit en dan rechtdoor naar de stapel (`Voorraad._route_free`); ligt de stapel aan de overkant van de rivier (Stad), dan via de brug en de stadsstraat. Een gebouw (of het hoofdkwartier met voorplein) op die lijn **versperd de weg** (`blocked_by`): de bestemming wordt geweigerd met de melding WEG VERSPERD en de automatische keuze slaat die stapel over. Een stapel dichter dan 20 m bij het depot wordt ook geweigerd.
- **Weg vrijmaken:** zodra een truck een rit begint, verdwijnen bomen, struiken, varens, gras en rotsen langs de route (6 m breed, `prepare_trip`), en de stapel draait zijn voorkant naar de kant waar de truck vandaan komt (zodat de grijper de afhaalkist pakt).
- **Verkeer zonder poorten:** geen poortvakken; het stuk voor het depot is voor één truck tegelijk (`uitrit:`-sleutel, vrij als de truck 16 m weg is).
- **Test:** `tests/mcv_voorraad_test.gd` (stapels, nog geen depot, gratis depot en truck, geen kosten, verkoopwaarde 0, route eindigt voor de stapel, brugroute naar de stad, versperring, wegen vrij, stapel draait mee, een rit levert +120 punten), workflow `mcv.yml`. **Niet getest:** iPhone en visueel (de truck die door een rij bomen rijdt voordat die weg zijn, kranen en de grijper op een willekeurige plek).

### MCV: hoofdkwartier draaien in het bouwscherm (8 november 2026, wens van Dennis na zijn test van stap 1 en 2)
In het bouwscherm tik je op het hoofdkwartier (of zijn voorplein): er opent een paneel **HOOFDKWARTIER** met vier knoppen: **⟲ 90°, ⟲ 15°, 15° ⟳, 90° ⟳**. Het voorplein, de deur en het botsblok draaien mee (`Mcv.rotate_hq`); je komt na sneuvelen voor de nieuwe deur terug en vijanden, trucks en routes gebruiken de nieuwe draaiing (`Game.base_yaw`). Draaien lukt alleen als de nieuwe voetafdruk (14 x 16 m) vrij is van gebouwen en andere massieve dingen (anders melding GEEN RUIMTE); begroeiing en rotsen in de nieuwe voetafdruk verdwijnen. Slepen op het hoofdkwartier verschuift gewoon de kaart. Alleen in MCV-modus. Test: `tests/mcv_draai_test.gd`. **NIET GETEST:** iPhone (tikken, knoppen, beeld).

### MCV stap 3 gebouwd (8 november 2026): muren trekken, poort en wachttorens
Naar de keuzes van Dennis (muur "zoals een weg in de stad", complete omheining gratis, 4 gratis torens daarna 100, torens alleen bij de basis, poort zelf plaatsen). Alleen in MCV-modus.
- **Muur trekken** (`scripts/kampmuur.gd`): kaartje **KAMPMUUR** in het bouwscherm, daarna sleep je met één vinger over de grond (zoals de lijn in de stadseditor). Muren staan op een **rooster van 3,5 m** en lopen alleen noord-zuid of oost-west; een schuine veeg wordt een trapje; terugvegen haalt het laatste stuk weer weg. Groen voorbeeld = komt er, rood = kan daar niet (iets in de weg, rivier), oranje = te weinig punten. Elk stuk is een eigen bouwstuk (Meshy-muurmodule, 3 m hoog, 1500 sterkte): vijanden schieten het kapot, tik erop om te verkopen of te repareren; een stuk sleep je niet los (het zit vast op het rooster). **Twee vingers verschuiven de kaart** (nodig omdat één vinger muren trekt); tik weer op KAMPMUUR om te stoppen.
- **Kosten:** 50 per stuk. **De eerste complete omheining is gratis:** zolang het hoofdkwartier niet omsloten is, zijn de eerste 150 stukken gratis (`Game.free_wall`, `Kampmuur.FREE_CAP`); omsluit je het hoofdkwartier (zoeken vanuit het HK over het rooster, `Kampmuur.enclosed`), dan meldt het spel OMHEINING COMPLEET en kost elk volgend stuk 50. Gratis stukken leveren bij verkopen niets op, betaalde 25.
- **Poort zelf plaatsen:** kaartje **POORT** (100 pt, voorstel: Dennis noemde nog geen prijs), tik op een muurstuk: de poort vervangt dat stuk en zijn buur in dezelfde lijn (7 m). Hij is de bestaande schuifpoort (`Gates`, nu met `add_gate`/`remove_gate`/`gate_at`): gaat vanzelf open voor jou, je soldaten en je trucks, vijanden slaan of schieten hem kapot, repareren en verkopen (+50) via zijn paneel. Een poort telt als muur voor de omheining.
- **Wachttorens:** kaartje **WACHTTOREN**: de eerste 4 zijn gratis (`Game.free_towers`), daarna 100; alleen binnen 45 m van het hoofdkwartier (`Buildings.TOWER_RANGE`); dezelfde klimbare toren als in het oude kamp (trap aan de lokale +x-kant; loop er tegenaan om te klimmen), bouwtijd 8 s.
- **Vijanden en muren:** een muurstuk of poort recht voor een vijand op weg naar het hoofdkwartier houdt hem tegen; hij slaat of schiet erop tot het kapot is (`Enemy._wall_ahead`). Grondvuur gaat niet door een muur (`LAYER_FORTIFICATION`, `BaseWallRules`).
- **Trucks:** staat er een muur tussen depot en stapel, dan rijdt de route door de dichtstbijzijnde poort (`Voorraad._gate_detour`); zonder poort meldt het spel WEG VERSPERD ("een muur zonder poort").
- **Camera:** muurstukken staan op `nocam` (de camera loopt er dwars doorheen in plaats van naar de speler te schuiven).
- **Tests:** `tests/mcv_muur_test.gd`, `mcv_muur_ui_test.gd`, `mcv_poort_test.gd`, `mcv_toren_test.gd`; workflow `mcv.yml`. **NIET GETEST:** iPhone (slepen, tikken, beeld, FPS met veel muurstukken: elk stuk is een eigen bouwstuk met 3 detailniveaus, 150+ stukken zijn niet gemeten), visuele opnames.

**Reparatie na Dennis' eerste test van stap 3 (8 november 2026):** in het bouwmenu stond nog de oude Betonmuur (300 pt) en misten Kampmuur, Poort en Wachttoren. Oorzaak: de bouwkaartjes werden bij het laden van het scherm gemaakt, vóór START MISSIE `Data.mcv_mode` aanzet; mijn tests zetten de modus al vooraf en zagen het niet. Nu bouwt `BuildMode._enter()` de kaartjes opnieuw als de modus sindsdien veranderde. Test: `tests/mcv_kaarten_test.gd` (laadt eerst zonder MCV-modus, zet hem dan aan, zoals het hoofdmenu; faalt zonder de reparatie).

### MCV stap 3, verbeteringen na Dennis' test (8 november 2026)
- **Poort bevestigen:** tik je op POORT en daarna op een muurstuk, dan komt de poort er nog niet. Je ziet een gouden voorbeeld van de twee muurstukken die hij vervangt en een paneel **POORT HIER?** met **Plaats (100 pt)** en **Annuleer**. Tik je op een ander muurstuk, dan verschuift het voorbeeld. Zo komt de poort nooit ergens waar je hem niet wilt (`BuildMode._gate_pending`).
- **Muur trekken makkelijker:** het paneel **KAMPMUUR** heeft twee standen. **Lijn** (standaard): een rechte muur; de richting wordt vastgelegd zodra je meer dan een stuk van het begin bent en je vinger mag daarna zijwaarts afdwalen (pas als je duidelijk 3 stukken een andere kant op gaat, wisselt de richting). **Vierkant**: sleep van hoek naar hoek en je krijgt vier muren in één keer (handig voor de gratis omheining). Een nieuwe muur begint vanzelf aan het eind van een bestaande muur of poort als je er binnen 5 m van begint (`Kampmuur.snap_start`). Het paneel toont ook hoeveel stukken er nog gratis zijn.
- **Tests:** `tests/mcv_muur_ui_test.gd` uitgebreid (voorbeeld, Plaats en Annuleer, rechte lijn bij afdwalende vinger, aansluiten, vierkant). **NIET GETEST:** iPhone.

## Stap 4 (keuzes van Dennis, 8 november 2026): patrouilles bij de kazerne (4a), daarna het oude kamp opruimen (4b)
**4a nu, 4b pas na zijn test van 4a.**
1. **Route:** een wacht loopt aan de **binnenkant van de gemaakte muur** (langs de omheining rond het hoofdkwartier). Is er nog geen complete omheining, dan een cirkel van ongeveer 14 m rond het hoofdkwartier.
2. **Prijs en aantal:** **250 per wacht, maximaal 4 per kazerne.** Gekocht bij de kazerne, zonder wachtrij met rekruten; een wacht telt niet mee bij je team en volgt je niet.
3. **Bij een aanval** rennen ze naar de **dichtstbijzijnde poort waar de aanval vandaan komt** en verdedigen daar: over of door een muur kun je niet schieten, dus de poort is de plek waar het gevecht is. Zonder poort: naar de binnenkant van de muur aan de kant van de aanval.
4. **Volgorde:** eerst 4a testen; 4b (het oude vaste kamp opruimen: vaste muur, poorten, torens, wachthuisjes, generator, oude patrouilles, kampbodem, de MCV-schakelaar, en de oude tests omzetten of verwijderen) komt daarna.

### Stap 4a gebouwd (8 november 2026): wachten bij de kazerne
Naar de vier keuzes hierboven. Alleen in MCV-modus.
- **Kopen:** in het kazernepaneel de knop **Wacht** (250 pt, `n/4`), hooguit 4 per kazerne; hij komt uit de deur en begint meteen zijn ronde. Een wacht telt niet mee bij je team (niet in `Game.allies`, dus ook niet voor Volgen, Posten en het teamwiel) en volgt je niet. Verkoop je de kazerne, dan gaan zijn wachten mee. Code: `Buildings.buy_wacht`, `scripts/wachten.gd`; hergebruikt `Ally` met `guard = true` en `wacht_slot`.
- **Ronde:** langs de **binnenkant van de omheining**: de cellen van het rooster die een muur of poort raken, op volgorde, iedere derde cel (ongeveer 10 m tussen twee punten); elke wacht begint op een eigen plek van de ronde, blijft op elk punt 3 tot 6 s staan en loopt dan door. Zonder complete omheining: een cirkel van 14 m rond het hoofdkwartier. De ronde wordt opnieuw uitgerekend zodra je muren, poorten of gebouwen verandert.
- **Aanval:** bij een aanvalsgroep rennen ze naar de **poort die het dichtst bij de aanvallers ligt**, 4,5 m aan de binnenkant, naast elkaar (1,8 m ertussen). Een kapotte poort telt ook (dat is een gat in de muur). Zonder poort: aan de binnenkant van de muur aan de kant van de aanval; zonder omheining: 8 m voor het hoofdkwartier. Door een muur schieten ze niet (`Ally._nearest_enemy` kijkt al naar `BaseWallRules`).
- **Bekend:** gebouwen op de ronde (bijvoorbeeld een depot tegen de muur) blokkeren een wacht; hij loopt er met de bestaande omloop-logica omheen. Wachten zijn (zoals rekruten) niet te doden: vijanden schieten er nog niet op.
- **Test:** `tests/mcv_wacht_test.gd` (kopen, 250, maximum 4, verschillende plekken, ronde binnen en langs de muur, lopen en binnen blijven, post bij de noord- en zuidpoort, zonder poort, verkochte kazerne, knop in het paneel), workflow `mcv.yml`. **NIET GETEST:** iPhone.
