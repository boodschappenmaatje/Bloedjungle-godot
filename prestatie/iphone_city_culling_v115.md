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

1. Gebruik dezelfde build **v115-test**, hetzelfde dagdeel/weer, dezelfde grafiekstand, **60 FPS** en dezelfde plek met **0 vijanden** tijdens voorbereiden. Zet **Test: 3D-beeld klein** uit (automatische stand).
2. Prestatiemodus en FPS-teller aan. Herstart de missie en blijf stil staan; meet na 8–10 seconden. Noteer gemiddelde FPS, render-CPU, GPU indien beschikbaar, draw calls, 3D-resolutie, nodes en p95.
3. Zet **Test: stad buiten beeld niet tekenen = Uit**, herhaal op dezelfde plek en met dezelfde golffase. Herhaal vervolgens met **Aan**. Een A–B–A-volgorde verkleint de kans dat opwarming/thermiek tot een verkeerde conclusie leidt.
4. Herhaal één keer dichter bij de stad en met **8 vijanden**. Controleer op pop-in, doorschijnende gebouwen, ontbrekende schaduwen, onbereikbare voertuigen en afwijkende botsingen.
5. Laat de stadseditor actief, voeg een gebouw toe, verplaats het en verlaat de editor; controleer of de stad volledig zichtbaar blijft bij terugkeer.

**Acceptatie:** alleen als de FPS aantoonbaar verbetert, zonder zichtbaar kwaliteitsverlies of regressies, kan deze branch naar main. Als de stad nog altijd 25–35 FPS haalt, is aanvullend GPU-/renderprofielonderzoek nodig; verander niet blindelings de shader- of textuurkwaliteit.

## Geautomatiseerde controle

- godot --headless --path . -s tests/stad_culling_test.gd
- godot --headless --path . -s tests/stad_zicht_test.gd --fixed-fps 60
- godot --headless --path . -s tests/diagnose_test.gd --fixed-fps 60
- godot --headless --path . -s tests/smoke_test.gd --fixed-fps 60

Deze tests zijn toegevoegd/gespecificeerd, maar **niet lokaal uitgevoerd** vanuit ChatGPT omdat in die uitvoeromgeving geen Godot-installatie beschikbaar is.
