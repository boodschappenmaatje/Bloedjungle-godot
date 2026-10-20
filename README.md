# Bloedjungle in Godot (proef)

Eerste stap van de overstap van de web-versie (JavaScript + Three.js) naar Godot 4 met GDScript.
De web-versie in `src/` blijft zoals hij is; dit is een losse map.

## Wat zit erin

- Speler met twee sticks: linker helft van het scherm lopen, rechter helft richten. Half duwen richt, tot de rand duwen schiet (net als nu). Op een computer: WASD lopen, muis richten, klikken schieten.
- M1911-pistool met dezelfde waarden als de web-versie, automatisch herladen, een beetje richthulp.
- De basis: betonnen borstwering van 28 × 28 m met een opening in het noorden en zuiden, en de bunker in het midden. Tegen de muur aan schiet jij eroverheen, de vijand niet.
- Golven met messen, geweren en (vanaf golf 4) zware MG's, met dezelfde levens, snelheid, schade en punten als nu. Vijanden lopen via de poorten naar jou of de bunker.
- Het soldaatmodel met de Mixamo-geweeranimaties (stil, lopen, rennen, achteruit, schieten, herladen, steken, sterven).

## Stijl

De bedoelde richting staat in `referentie-stijl.png`: een schuine militaire speelwereld, donkere tropische jungle, verweerde zandwegen, een herkenbare basis en warme zon met duidelijke schaduwen. De huidige wereld wordt volledig in Godot opgebouwd; er zijn geen externe foliage- of basisprops-texturen nodig.

Visual upgrade 1 houdt de bestaande mobiele renderer en gameplay aan. De grond gebruikt meerdere kleurschalen voor gras, aarde en zand, rafelige randen rond de poortwegen en subtiele wielsporen. Palm-, struik- en varen-silhouetten hebben varianten en gedempte kleuren; herhaalde planten blijven per variant ge-instanced. De bunker kreeg kleine deur-, ventilatie- en camouflagedetails. SSAO en glow staan uit voor de lichte Mobile/GL Compatibility-route; zon, schaduwen en zachte mist blijven aan.

De scene is nog steeds een compacte, gestileerde prototypewereld. De referentie bevat onder meer fotorealistische gebouwen, voertuigen, bruggen, gevechten en een grotere kaart; die onderdelen zitten niet in deze gameplayfase.

Nog niet: winkel, andere wapens kopen, granaten, gebouwen, jeep, gore, geluid. Dat komt stap voor stap.

## Indeling

| Map | Inhoud |
|---|---|
| `scenes/` | `main.tscn` (alles samen), `player.tscn`, `enemy.tscn`, `hud.tscn` |
| `scripts/data.gd` | Alle vaste waarden (wapens, vijandtypes, maten) uit `src/js/01-data.js` |
| `scripts/game.gd` | Spelstatus (autoload `Game`): golf, punten, bunker |
| `scripts/main.gd` | Golven en de pauze ertussen |
| `scripts/player.gd`, `enemy.gd` | Speler en vijanden |
| `scripts/route.gd` | Hoe vijanden om de muur en de bunker heen lopen |
| `scripts/level.gd` | Bouwt grond, muur, bunker en bomen (ook zichtbaar in de editor) |
| `scripts/touch_sticks.gd`, `hud.gd` | Besturing en schermteksten |
| `assets/tank.glb`, `scripts/tank.gd` | Eigen tank die buiten de oostmuur patrouilleert; de koepel volgt vijanden. Blender-bron in `bron/tank/` |
| `assets/soldaat.glb` | Het mannetje met animaties; gemaakt met `tools/godot-soldaat.mjs` in de privé-repo bloedjungle |
| `tests/smoke_test.gd` | Automatische test die golf 1 en 2 speelt |

Scènes en scripts samen zijn ongeveer 40 KB, ruim onder de 200 KB van Xogot gratis.

## Testen op je iPhone met Xogot

1. Open Xogot en tik op het download-icoon (pijl omlaag) bovenaan.
2. Vul in: `https://github.com/boodschappenmaatje/bloedjungle-godot` en tik op **Download**.
3. Open het project en druk op Afspelen.

Een nieuwe versie haal je op door het project weg te halen en opnieuw te downloaden.

### Visual upgrade 1 testen vanaf de PR-branch

De normale GitHub-download hierboven pakt `main`. Voor deze visuele versie:

1. Download de branch als ZIP: <https://github.com/boodschappenmaatje/Bloedjungle-godot/archive/refs/heads/visual/generals-style-phase-1.zip>.
2. Pak de ZIP uit in Bestanden en kopieer de map `Bloedjungle-godot-visual-generals-style-phase-1` naar **Op mijn iPhone/iPad → Xogot**.
3. Herstart Xogot als het project nog niet in de projectlijst verschijnt, open het en tik op **Afspelen**.
4. Controleer de twee sticks, de bewegende vijanden, de poortopeningen, muur en bunker. Vergelijk het beeld met `referentie-stijl.png`.

Met Working Copy kun je ook de repository clonen en daar de branch `visual/generals-style-phase-1` uitchecken. De gecheckte projectmap moet in de Xogot-projectmap staan.

## Openen op je Windows-laptop

1. Download Godot 4.4 of nieuwer (de gewone versie, niet .NET) van https://godotengine.org/download/windows en pak het uit.
2. Haal de code op met GitHub Desktop (Clone repository) of `git clone https://github.com/boodschappenmaatje/bloedjungle-godot`.
3. Start Godot, klik op **Importeren** en kies `project.godot` in die map.
4. Druk op F5 om te spelen. Met WASD en de muis kun je het daar ook testen.

Voor visual upgrade 1 haal je de PR-branch op in plaats van `main`:

```bash
git clone https://github.com/boodschappenmaatje/Bloedjungle-godot.git
cd Bloedjungle-godot
git switch --track origin/visual/generals-style-phase-1
```

Open daarna `project.godot` in Godot 4.4 of nieuwer, open `scenes/main.tscn` en druk op F6 (of F5 voor de projectstartscene). Controleer vijandbeweging, de poortpaden, muur en bunker; vergelijk de grond- en junglerand met `referentie-stijl.png`.

## Webversie maken (optioneel)

1. In Godot: **Editor → Exportsjablonen beheren → Downloaden en installeren** (één keer).
2. **Project → Exporteren**: de voorinstelling **Web** staat er al. Klik **Project exporteren** en kies `export/web/index.html`.
3. Snel proberen op de laptop: het knopje met het HTML5-logo rechtsboven in de editor start het spel in je browser.

## Automatische test

Speelt golf 1 en 2 met een bot die naar de dichtstbijzijnde vijand richt en schiet, en print elke 5 seconden de stand.

```bash
godot --headless --path . -s tests/smoke_test.gd --fixed-fps 60
```

De test doorloopt golven 1 en 2 met een bot en controleert zo de bestaande vijandbeweging, basisroutes en schietbare bunker. Voor een visuele vergelijking: open `scenes/main.tscn`, start de scene en vergelijk de basis, de poortwegen en de junglezoom met `referentie-stijl.png`. De automatische smoketest is geen beeld- of FPS-meting.
