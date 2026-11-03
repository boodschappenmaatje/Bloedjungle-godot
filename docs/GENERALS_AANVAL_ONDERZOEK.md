# Onderzoek: hoe kiest de Generals-AI zijn aanvallen? (stap D2, keuze F)

Opgesteld 2026-11-03 voor Claude én Codex. Dit is een eigen samenvatting van wat de modding-gemeenschap over de skirmish-AI van *C&C Generals / Zero Hour* heeft beschreven. Er is niets gekopieerd (geen teksten, bestanden of assets); we nemen alleen het idee over. Bronnen zijn handleidingen van fans, geen officiële EA-documentatie: de details hieronder zijn dus "zo beschreven", niet getest in het spel zelf.

## Wat Generals werkelijk doet

1. **Geen "zwakste kant" berekening.** In de beschreven AI zit geen slimme zoektocht naar het zwakste punt. De aanvallen zijn vooraf gemaakte scripts (SkirmishScripts) met teams die in genummerde golven komen.
2. **Genummerde golven, begrensd door moeilijkheid.** Golf 1 komt vroeg en is klein, golf 5 komt laat en is veel zwaarder. Makkelijk stopt bij golf 3, gemiddeld bij 4, moeilijk bij 5.
3. **Drie routes.** Vooraf ingestelde paden per kaart: *Center* (kortste weg), *Flank* (van de zijkant) en *Backdoor* (van achteren). Zonder paden loopt het team recht naar de vijandelijke basis. Het team krijgt dus een route, niet een zwak punt.
4. **Doelprioriteit per soort object.** Elke soort heeft een gewicht: gevaarlijke dingen (tanks, verdediging, eenheden) wegen zwaar, technologiegebouwen soms nul. Een team valt aan wat binnen zijn bereik rond de vijandelijke basis staat en dat het zwaarst weegt.
5. **Teams met min/max aantallen.** Een team is een groep eenheden met een minimum, maximum en prioriteit. Er staat een voorwaarde bij ("bouw dit team zolang...") die naar de toestand van het spel kijkt, bijvoorbeeld hoeveel eenheden de tegenstander heeft.
6. **Fasetelling.** Een hoofdtelling stijgt met het aantal verloren teams. Een hogere fase ontsluit nieuwe eenheden en tactieken: de AI wordt dus sterker naarmate hij verliest of lang speelt.
7. **Leren van succes en falen.** Een geslaagd team krijgt hogere prioriteit, een mislukt team lagere. Zo verschuiven latere aanvallen zonder dat de AI "nadenkt".
8. **Reacties.** Aangevallen teams stappen uit hun transport en jagen terug. Als jouw troepen in zijn basis een drempelwaarde (waarde in eenheden) overschrijden, trekken teams terug naar de verdediging. Is jouw leger geknakt, dan jaagt hij de rest op. Eenheden bij het midden van de kaart sluiten aan als zijn basis vol raakt.
9. **Economie en bouwen.** Basisbouw is een keten van scripts die gebouwen neerzetten zodra de voorwaarden kloppen; moeilijkere standen krijgen extra verdediging en inkomen. (Dit is het deel dat bij ons D3/"echte vijand-AI" heet: bewust later.)

## Wat dit betekent voor Bloedjungle (voorstel, nog niet gebouwd)

Dennis' wens was "hij kiest de zwakste kant van jouw basis". Dat is *meer* dan Generals doet. We kunnen het toch eenvoudig bouwen en Generals-achtig laten voelen:

- **Aanvalsgroepen met nummer** (zoals golven, maar zonder golfteller op het scherm): groep 1 klein, daarna groter en sterker. Tempo volgens Dennis: 3 minuten rust, daarna elke 90 seconden een groep.
- **Drie routetypen op de bestaande stadsroutes** (`AanvalRoutes`): *Center* = `brug` (hoofdstraat), *Flank* = `wijk` of `kade`, *Backdoor* = `industrie` (ondiepte) en later een lange route om de basis heen. De routes `moeras`, `jungle` en `zuid` passen niet bij een basis in het noorden en blijven voorlopig uit.
- **Zwakste kant = eenvoudige score per route.** Per route telt de verdediging bij het einde van die route (torentjes, mijnen, prikkeldraad, zandzakken, geschutstorens, jouw soldaten in de buurt; de speler zelf telt zwaar). De route met de laagste score wint met een dobbelsteen erbij, zodat hij niet altijd hetzelfde doet.
- **Leren zoals Generals:** een route waar een groep sneuvelt krijgt minder gewicht, een route waar een groep doordringt meer. Dit is goedkoop en voelt slim.
- **Prioriteit van doelen:** eerst wat terugschiet (soldaten, torens, voertuigen), dan het hoofdkwartier, daarna rest. Voorraadtrucks en depot als lokdoelen kunnen later.
- **Terugtrekken en verdedigen:** blijf je met een grote groep in zijn basis, dan roept hij zijn groepen terug naar het garnizoen (past bij keuze E).

## Open punt voor Dennis

Wil je de *echte* Generals-manier (vaste routes met fasetelling, geen berekening) of mijn voorstel (zwakste route met een eenvoudige score plus leren)? Aanbeveling: het voorstel, maar eenvoudig en met zichtbaar effect: na een mislukte groep komt de volgende groep van een andere kant.

## Bronnen (beschrijvingen door fans, gelezen op 2026-11-03)

- Dutchygamer, "Editing the AI" (Project Perfect Mod): genummerde golven 1 tot 5 per moeilijkheid, paden Center/Flank/Backdoor, teams met min/max. https://www.ppmforums.com/post-617226/editing-the-ai-zh
- ModDB-handleiding "Step by step guide to building an AI" (Zero Hour): scripts als voorwaarde-actie-paren, hoofdtelling per verloren teams, doelprioriteit per objectsoort, succes verhoogt en falen verlaagt de prioriteit. https://www.moddb.com/tutorials/gen-zh-step-by-step-guide-to-building-an-ai
- Project Perfect Mod, "Generals AI editing": overzicht van de bestanden (AIData.ini, SkirmishScripts.scb). https://cnc.projectperfectmod.com/genaiediting/
