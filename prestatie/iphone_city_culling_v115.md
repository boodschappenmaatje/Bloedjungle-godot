# Bloedjungle — iPhone FPS experiment v115-test

## Waarom deze branch

Op 22 oktober 2026 haalde de iPhone 18 Pro Max (iPhone19,7) 60 FPS in de jungle, gemiddeld 492–572 draw calls, 1.608–1.691 nodes en 764 MB gerapporteerd videogeheugen. Op 26 oktober liet v114 in drie snapshots circa 23–40 FPS zien met 4.513–4.745 nodes en 922–941 MB gerapporteerd videogeheugen. De snapshots hebben **verschillende locaties, vijandaantallen en resoluties** en zijn dus niet zonder meer vergelijkbaar. GPU-tijd is op Xogot niet beschikbaar.

De nieuwe stad is aanwezig in de scene tree, ook buiten beeld. Bestaande zichtafstandslimieten beperken losse meshes, maar niet noodzakelijk al het renderwerk van de stad als geheel. Deze PR probeert aanvullend een **render-only** uitschakeling van de volledige stad wanneer zelfs een ruime marge rond haar wereldgrond-voetafdruk niet in het camerabeeld komt.

## Wat wel/niet gebeurt

- Stad controleert hoogstens om de 0,3 seconde of de camera (op de wereldgrond geprojecteerd) het stadsgebied plus 40 meter marge raakt.
- Alleen de **zichtbaarheid van de stadroot** wordt aan/uit gezet. Objecten worden niet verwijderd, opnieuw geladen of verplaatst. Gameplay, scripts, fysica, collision en opslag van editorwijzigingen blijven aanwezig.
- Tijdens stadbewerking, bouwmodus, menu's en bij een ongeldige cameraprojectie blijft de stad zichtbaar. De bestaande instelling **Test: stad zien** blijft leidend.
- De nieuwe instelling **Test: stad buiten beeld niet tekenen** kan de functie aan of uit zetten (standaard **aan** op deze testbranch).
- De complete stad blijft op de achtergrond in het geheugen, dus dit is **geen geheugenoptimalisatie**. De FPS-winst is onzeker en mag pas worden geclaimd na echte A/B-metingen op iPhone/Xogot.
- Het doel is **zonder wijziging van modelkwaliteit, materialen, schaduwkwaliteit, resolutie of gameplay** minder renderwerk buiten het camerabeeld.

## A/B-test op dezelfde iPhone

**Belangrijke correctie (screenshots van 26 oktober):** bij de twee eerdere v115-test-screenshots stond zowel bij culling Aan als bij culling Uit de schakelaar **Test: stad zien = Uit**. De stad was dus in beide gevallen al gedwongen verborgen. Deze screenshots zijn **geen geldige A/B-vergelijking**; de 35 versus 31 FPS is niet aan city culling toe te schrijven.

1. Haal de nieuwe branchversie **v115b-test** op in Xogot. Zet eerst verplicht **Test: stad zien = Aan**. Zet **Test: 3D-beeld klein (30%) = Uit**. Houd zon/jungle/nabewerking constant (bij voorkeur alle drie Aan), dag/helder/Hoog/60 FPS.
2. Zet Prestatiemodus en FPS-teller Aan. Kies dezelfde positie met **0 vijanden** tijdens voorbereiden; laat de speler stilstaan en meet na minstens 10 seconden. De overlay toont nu expliciet **stad: AUTO VERBORGEN**, **AUTO ZICHTBAAR**, **CULLING UIT** of **HANDMATIG UIT (test ongeldig)**.
3. Zet **Test: stad buiten beeld niet tekenen = Aan**, meet. Zet alleen deze instelling **Uit**, meet op dezelfde plek; daarna nogmaals **Aan** (A–B–A). Doe het liefst na een nieuwe missie waarbij dezelfde golffase wordt gebruikt; noteer FPS, frametijd, p95, draw calls, nodes, 3D-resolutie, status en screenshot.
4. Als de overlay **AUTO ZICHTBAAR** meldt, zal de culling op die plek **geen verschil** maken: de stad ligt binnen de veiligheidsmarge. Test dan ook een plek verder van de stad waarop de overlay **AUTO VERBORGEN** toont; beweeg niet tijdens de metingen.
5. Doe apart een tweede reeks met **8 vijanden**, weer met dezelfde golffase/positie. Controleer bij het benaderen van de stad op pop-in, ontbrekende schaduwen, zichtbare gebouwen en correcte botsingen.
6. Open de stadseditor, voeg een gebouw toe, verplaats het en verlaat de editor; controleer ook bij terugkeer de zichtbaarheid.

De v115b-overlay toont de echte **zichtbaarheidsstatus**, niet de FPS-oorzaak. Ook als de stad automatisch verborgen wordt, kunnen andere bottlenecks zoals jungle, shadows, GPU of iOS-framepresentatie overheersen.

**Acceptatie:** alleen als de FPS aantoonbaar verbetert, zonder zichtbaar kwaliteitsverlies of regressies, kan deze branch naar main. Als de stad nog altijd 25–35 FPS haalt, is aanvullend GPU-/renderprofielonderzoek nodig; verander niet blindelings de shader- of textuurkwaliteit.

## Geautomatiseerde controle

- godot --headless --path . -s tests/stad_culling_test.gd
- godot --headless --path . -s tests/stad_zicht_test.gd --fixed-fps 60
- godot --headless --path . -s tests/diagnose_test.gd --fixed-fps 60
- godot --headless --path . -s tests/smoke_test.gd --fixed-fps 60

Deze tests zijn toegevoegd/gespecificeerd, maar **niet lokaal uitgevoerd** vanuit ChatGPT omdat in die uitvoeromgeving geen Godot-installatie beschikbaar is.
