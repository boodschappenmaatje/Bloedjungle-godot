# AAA aanvalscommando voor Bloedjungle — ontwerp

Datum: 11 november 2026. Status: ter goedkeuring door Dennis. Dit document beschrijft het gewenste resultaat; het is nog geen opdracht om betaalde Meshy-taken te starten of de game te publiceren.

## Bedoeling

De speelbare soldaat moet eruitzien en bewegen als de hoofdfiguur van een hoogwaardige militaire junglegame. In Dennis' iPhone-opname van 11 november beweegt de huidige Meshy-speler tijdens het rennen, maar na het stoppen en schieten blijven de benen in een renpas staan. Lopen en rennen ogen ook niet consequent geloofwaardig. De upgrade moet juist vanuit de bestaande schuine gamecamera overtuigen.

## Gekozen aanpak en alternatieven

1. **Gekozen: huidige Meshy-speler met zijn 28-bots Mixamo-rig behouden.** Verfijn de player-only mesh en materialen, herstel de stilstand en vervang of verbeter de zwakke bewegingen op dezelfde rig. Dit houdt bestaande gameplay, wapenankers en de al aanwezige 13 plus 62 Meshy-clips bruikbaar.
2. Helemaal nieuw Meshy-personage met nieuwe rig: meer vrijheid in lichaamsvorm, maar alle wapens, clips, IK, houdingen en gameplaykoppelingen moeten opnieuw worden ingepast. Niet gekozen.
3. Terug naar de VQ2-speler met 53-bots DEF-rig: behoudt diens bestaande uiterlijk en clips, maar vraagt retargeting van Meshy-bewegingen en lost de gekozen Meshy-speler niet direct op. Niet gekozen.

## Uiterlijk en materialen

- Origineel aanvalscommando, zonder een herkenbaar film- of gamepersonage te kopiëren.
- Gezicht zichtbaar: geen masker of gesloten vizier. Compacte helm met headset aan één oor; helm, hoofd en schouders vormen op gameplayafstand een herkenbaar silhouet.
- Tiger Stripe-uniform en een rustig olijfgroen, goed passend vest. Bestaande `bron/soldaat_vq2/jungle_commando/tiger_stripe_albedo_2048.png` en `olive_nylon_albedo_512.png` zijn de gekozen kleur- en materiaalreferenties. Bestaande donkere webbing, gematteerd staal, leer en rubber zijn de startset voor riemen, sluitingen en laarzen.
- Radio op de rug, geloofwaardig geplaatste magazijnen en EHBO-set; uitrusting blijft uit de armen, schouderrotatie en wapenruimte. Stofnaden, vouwen, modder en gebruikssporen zijn zichtbaar op korte afstand, zonder ruis in het beeld van boven.
- Realistische PBR zonder glimmende kunststoflook. Eerst bestaande materiaalbibliotheek benutten; alleen nieuwe texturen toevoegen als de bekeken gamecamera laat zien dat de lokale set tekortschiet. Bij zo'n nieuwe bron vooraf de materiaalopties met echte voorbeelden voorleggen.

## Animatie en gedrag

- **Fout eerst vaststellen en herstellen:** de huidige `Idle` die in `scripts/soldier_model.gd` wordt gemaakt, heeft alleen tracks voor rug, nek en hoofd. Test of de ontbrekende been- en heuptracks de laatste renpose laten staan bij rennen → stoppen → schieten. Herstel de volledige stilstandspose en controleer dezelfde overgang ook na lopen en sprinten, met en zonder ingedrukte schietknop.
- Vergelijk de bestaande clips uit `resources/animations/meshy_player_animation_library.res` en `_api.res` met de iPhone-opname. Selecteer alleen bewegingen die in de gamecamera overtuigen. Nieuwe API-clips worden gericht gekozen na een gratis cataloguscontrole en kostenraming; Meshy-uitvoer wordt in Blender/Godot gecorrigeerd waar hand-, voet- of wapencontact tekortschiet.
- Kernreeks: stil, tactisch lopen vooruit/achteruit/zijwaarts, rennen, sprinten, starten, afremmen/stoppen, draaien, richten, schieten tijdens bewegen en in stilstand, herladen en trefferreactie. Houdingen die de speler nu kan gebruiken (hurken/liggen/rollen/klimmen/zitten) blijven werken; zwakke of bevroren pose-overgangen worden afzonderlijk beoordeeld en niet als nieuwe animatie gepresenteerd.
- Benen en voeten moeten zichtbaar landen zonder langdurig glijden of een vastgehouden pas bij stilstand. Romp en wapen mogen blijven richten terwijl de benen naar de looprichting bewegen. Beide handen blijven aan het actieve wapen; terugslag en herladen passen bij de wapenstand. De besturing en schietwaarden veranderen niet door cosmetische animatieverbetering.
- Houd de 28-bots Mixamo-hiërarchie en bestaande `SoldierModel`-spelinterface intact. Horizontale root motion uit nieuwe clips wordt verwijderd of expliciet afgehandeld zodat de animatie het `CharacterBody3D` niet verplaatst; verticale beweging blijft alleen waar de actie die nodig heeft. Clipnamen, loopgedrag, overgangen en triggers worden in de asset-specificatie vastgelegd voordat definitieve clips worden geproduceerd.

## Doelen, grenzen en te vermijden uitkomsten

- Doel: overtuigend silhouet en beweging op de native iPhone-gamecamera, plus hoogwaardige close-up en 360° beoordeling.
- Doel: geen vastlopende renpose na stoppen en schieten; geen zichtbaar handcontactverlies of vervorming tijdens de kernreeks.
- Buiten scope: nieuwe wapens, andere schade, snelheid, stamina, collider, vijandelijke modellen of gameplayvoordelen door de nieuwe uitrusting.
- Onacceptabel: een mooie losse Meshy-preview die in de echte game niet werkt, een statische pose vermomd als idle, voetglijden, wapen door het vest, of een zware asset die de native iPhone merkbaar schaadt.
- Betaalde Meshy-generatie is niet automatisch inbegrepen. Hergebruik eerst de bestaande 62 API-clips; vóór nieuwe taken worden de exacte acties en credits voorgelegd.

## Productie en beoordeling

- Lever een reproduceerbare bewerkbare Blender-bron, geoptimaliseerde Godot-GLB met echte clips of een gekoppelde animatiebibliotheek, PBR-kaarten en een USDZ-preview voor de iPhone. Gebruik de bestaande VQ2-viewer voor 360° en afspelen van werkelijke clips, met de huidige Meshy-speler naast de nieuwe versie.
- Vergelijk voor/na in identieke belichting en echte gamecamera, inclusief een korte reeks: lopen → rennen → stoppen → stilstaand schieten → herladen; ook schieten tijdens bewegen en bewegen na schieten. Test botnamen, cliptracks, wapen-IK, uitrusting, import en gameplayregressie.
- De native iPhone-app is de prestatie- en touch-acceptatietest. Tot een fysieke meting is iPhone-FPS **NIET GETEST**. Werk op een featurebranch met Draft PR; geen merge naar `main` of OTA zonder Dennis' afzonderlijke toestemming.

## Open keuze voor Dennis

- Geldt de volledige AAA-animatieafwerking bij de eerste oplevering voor alle speelbare wapens, of eerst alleen voor het M1911-pistool uit de opname? De huidige spelcode heeft verschillende handgrepen en herlaadbewegingen per wapentype; deze keuze bepaalt de productie- en testomvang.

## Nog aan de bouwer

De maker kiest na visuele vergelijking de precieze helmconstructie, stofplooien, clipbronnen, retarget- en blendinstellingen en een passend mobiel driehoek-, materiaal- en textuurbudget. De keuzes moeten de afgesproken silhouette, animatiereeks en iPhone-prestaties dienen; geen willekeurige hogere polycount als kwaliteitsmaatstaf.
