# Asset Design Specification: Voorraaddepot, voorraadtruck met kraan en voorraadstapel

Status: **VOORSTEL. Stijl gekozen door Dennis (2026-11-02 12:46Z): Intendance (geel-zwart, stencil). De rest van de specificatie (voetafdruk 9 × 6,5 m, budgetten, clips) wacht nog op zijn expliciete ja; geen definitieve productie voor dat ja.** (docs/ASSET_QUALITY_STANDARD.md, "Nieuwe modellen: ontwerp vóór productie"). Plan: docs/GENERALS_PLAN.md, stap 4 (A1). De werking met blokken (4a) staat in een eigen Draft PR; deze modellen vervangen de blokken in 4b en behouden het gameplaycontract van 4a.

## Keuzes van Dennis (2026-11-02)
Depot: nieuw model met laadperron, pallets, kranen en schuur, **2K-texturen, minimaal 40.000 driehoeken, kwaliteit zoals het nieuwe hoofdkwartier, met een eigen kenmerkende stijl**. Truck: nieuw model **met een kraan en grijper die de kisten pakt en in de laadbak legt, zichtbaar geanimeerd**. Stapel: wordt zichtbaar kleiner in drie standen. Kwaliteitsniveau voor alle drie: zoals het hoofdkwartier.

## Eigen stijl (voorstel, ter goedkeuring): "Intendance"
Het logistieke korps van het leger heeft een herkenbaar uiterlijk dat nergens anders in de basis voorkomt:
- **Geel-zwarte waarschuwingsbanden** op kraanpoten, perronrand en bumpers (in de stijl van de gele bumper van de 4a-truck).
- **Witte stencilletters** op kisten, schuur en truck ("INTENDANCE", "DEPOT 01", batchnummers), in een kale militaire blokletter. Engels, net als de radio.
- **Olijfgroene kisten met gele stencil**, camonet over de lading, ruwe houten pallets, kettingen en haken aan de kraan.
- Een **gestileerde gele pijlpunt (chevron)** als embleem op deur, bak en stapel; ook het pictogram op de tactische kaart.
Alternatief als je liever iets anders wilt: A) alles in roest-oranje containerlook, B) sober zand en olijf zonder geel. Zeg het als je een van die twee wilt.

## Rol in de game (gameplaycontract van 4a, blijft gelijk)
- **Depot**: gebouw via de bouwmodus (`Buildings.DEFS.depot`), voorkant is +Z (daar komen de trucks), voetafdruk nu 8 × 6 m. Voor het 40.000-driehoeken model stel ik **9 × 6,5 m** voor (de basis is 56 × 56 m, kazerne 5,8 × 4,5 m, garage 5,8 × 6,2 m). Collisionblok = voetafdruk; schade en wrak via de bestaande gebouwcode.
- **Truck**: rijdt over vaste wegpunten (`VoorraadTruck`, StaticBody3D met botsblok 2,6 × 2,4 × 6,4 m). Lengte ca. 7 m, voorkant +Z. Wrakmodel apart (verbrand, kraan scheef). Kogels en explosies raken hem; hp 400.
- **Stapel**: pallet met kisten, voetafdruk ca. 5 × 4 m, 3 aparte modellen (vol, half, bijna leeg) in dezelfde stijl; de teller en de gouden ruit zijn Godot.

## Onderdelen
| Model | Onderdelen |
|---|---|
| Depot | Betonnen laadperron met rolpoort-schuur (openstaande deur), portaalkraan met rails en loopkat, stalen kettingtakel, pallets en gestapelde kisten, brandblusser en lamp bij de deur, hekwerk, bord met stencil, weegbrug aan de voorkant. Nachtlampen als emissieve onderdelen. |
| Truck | Zware legertruck 6x6: cabine met ruitwissers en spiegels, chassis met assen en bladveren, laadbak met kettingen en camonet, **kraan achter de cabine**: draaikolom, giek met hydraulische cilinder, **grijper met vier klauwen** aan kettingen. Wielen als losse onderdelen. |
| Stapel | Houten pallet, 14 kisten in drie lagen met stencil en gele banden, camonet half erover (vol); 7 kisten met een los net (half); 3 kisten en wat afval (bijna leeg). Gedeelde kistenset. |

## Animatie (echte Blender-clips; geen nepclips)
| Model | Clip | Duur | Loop | Trigger (Godot) |
|---|---|---|---|---|
| Truck | `Laden` | 3,0 s | nee | begint als de truck bij de stapel stopt (`VoorraadTruck.S.LADEN`): kraan draait uit, grijper zakt, klauwen sluiten om een kist, kist omhoog, kraan draait terug, kist zakt in de bak, klauwen open, rust. Eindpose = beginpose. |
| Truck | `Lossen` | 2,2 s | nee | idem bij het depot: kist uit de bak op de perronpallet. |
| Depot | `Kraan-lossen` | 2,5 s | nee | als de truck levert: de portaalkraan pakt de pallet en zet hem in de schuur (alleen als deze clip betrouwbaar speelt; anders Godot-beweging). |
| Depot | `Poort` (open/dicht) | 2,0 s | nee | als er een truck binnen 12 m komt. |
Godot-gestuurd: wielrotatie en vering van de truck, stof, motorgeluid, nachtlampen (gloed, geen echte lichtbron), teller en markering op de stapel, stand van de stapel (wisselt tussen de drie modellen).
De laadduur (3,0 s) en loosduur (2,2 s) in de code worden gelijk getrokken met de clips.

## Pivots, assen en namen
Oorsprong = midden van de voet op de grond, Y omhoog, voorkant +Z. Depot: `Voorraaddepot > Perron, Schuur, Poort, Portaalkraan (armature), Kisten, Lampen`. Truck: `Voorraadtruck > Chassis, Cabine, Bak, Lading (verbergbaar), Kraan (armature: Kolom, Giek, Grijper), Wiel_FL..Wiel_RR`; clips op de AnimationPlayer: `Laden`, `Lossen`. Stapel: `Stapel_vol`, `Stapel_half`, `Stapel_leeg` (elk een eigen GLB).

## Materialen en textuur
Hergebruik van de goedgekeurde VQ2- en HK-families in `assets/textures/vq2/` en de gebakken sets van het hoofdkwartier (beton, olijfverf, staal, hout, canvas), plus een eigen stencil- en bandenset. Bronnen en provenance staan in assets/textures/vq2/provenance.json. Geen nieuwe downloads zonder melding.

## Kwaliteit en budgetten (richtwaarden, worden gemeten en gerapporteerd)
| | HQ-bronmodel | Godot-gameversie |
|---|---|---|
| Depot | minimaal 40.000 driehoeken, 2K PBR | LOD0 maximaal ca. 45.000 (zoals de HK-gameversie: 51.927), LOD1 ca. 6.000 |
| Truck | minimaal 40.000 driehoeken, 2K PBR | LOD0 maximaal ca. 16.000 (er rijden er tot 9 tegelijk), LOD1 ca. 2.500 |
| Stapel | ca. 20.000 per stand, 2K | ca. 5.000 per stand |
Op de iPhone telt vooral het aantal trucks in beeld: de truck krijgt daarom een lichtere gameversie dan de bron. Alles wordt per model gemeten; iPhone-FPS blijft NIET GETEST tot Dennis het zelf test.

## Oplevering
`.blend` (bewerkbaar), reproduceerbaar Blender-Python-script per model (`bron/voorraaddepot/`, `bron/voorraadtruck/`, `bron/voorraadstapel/`), geoptimaliseerde `.glb` met LOD1, `.usdz`-preview voor iPhone Bestanden/Quick Look, viewer-invoer in `tools/blender-vq2-viewer/` met zichtbaar werkende knoppen voor `Laden`, `Lossen`, `Kraan-lossen` en `Poort`, Godot-tests (laden, namen, clips spelen, botsblok klopt, gameplaycontract van 4a blijft werken), voor/na-opnames met dezelfde camera, en een rapport met triangles, materialen en texturen. Alles in een Draft PR.

## Productieketen en beperkingen
De iMac-pipeline is vanuit deze cloudomgeving niet bereikbaar; de modellen worden met headless Blender (`bpy`) gemaakt, zoals het hoofdkwartier. Geen lokale iMac-render en geen iPhone-meting geclaimd.

## Acceptatie
1. Depot, truck en stapel zijn herkenbaar vanaf de gamecamera en uitgezoomd, en hebben samen een eigen stijl. 2. De truck laadt zichtbaar met kraan en grijper en de kist komt in de bak. 3. De stapel is in drie standen te onderscheiden. 4. Gameplaycontract van 4a werkt ongewijzigd (botsblok, route, wrak, poortopening). 5. Triangle-, texture- en materiaalrapport binnen de budgetten of gemotiveerd. 6. Dennis keurt het resultaat in de viewer en in de native app goed vóór merge.
