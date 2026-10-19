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

De bedoelde look staat in `referentie-stijl.png` (donkere, dichte jungle, schuine camera, echte 3D-gebouwen, zon met lange schaduwen). Alles wat we bouwen houdt dat als richting aan. Dit is nu gedaan: de zwaardere (mobiele) renderer met schaduwen, mist, gloed en filmkleuren, een bodem met gras, modder en paden, zelfgemaakte palmen, struiken en varens die in de wind bewegen, en een basis met muur, poortposten, bunker met zandzakken en antenne, vier wachttorens, hutten en kratten. De webversie gebruikt automatisch de lichtere renderer.

Nog niet: winkel, andere wapens kopen, granaten, gebouwen, speelbare jeep, gore, geluid. Het jeepmodel en een plaatsbare scène zijn inmiddels wel aanwezig.

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
| `assets/jeep.glb`, `scenes/jeep.tscn` | Gedetailleerde legerjeep met botsing, klaar om in een level te plaatsen. Blender-bron in `bron/jeep/` |
| `assets/soldaat.glb` | Het mannetje met animaties; gemaakt met `tools/godot-soldaat.mjs` in de privé-repo bloedjungle |
| `tests/smoke_test.gd` | Automatische test die golf 1 en 2 speelt |

Scènes en scripts samen zijn ongeveer 40 KB, ruim onder de 200 KB van Xogot gratis.

## Testen op je iPhone met Xogot

1. Open Xogot en tik op het download-icoon (pijl omlaag) bovenaan.
2. Vul in: `https://github.com/boodschappenmaatje/bloedjungle-godot` en tik op **Download**.
3. Open het project en druk op Afspelen.

Een nieuwe versie haal je op door het project weg te halen en opnieuw te downloaden.

## Openen op je Windows-laptop

1. Download Godot 4.4 of nieuwer (de gewone versie, niet .NET) van https://godotengine.org/download/windows en pak het uit.
2. Haal de code op met GitHub Desktop (Clone repository) of `git clone https://github.com/boodschappenmaatje/bloedjungle-godot`.
3. Start Godot, klik op **Importeren** en kies `project.godot` in die map.
4. Druk op F5 om te spelen. Met WASD en de muis kun je het daar ook testen.

## Webversie maken (optioneel)

1. In Godot: **Editor → Exportsjablonen beheren → Downloaden en installeren** (één keer).
2. **Project → Exporteren**: de voorinstelling **Web** staat er al. Klik **Project exporteren** en kies `export/web/index.html`.
3. Snel proberen op de laptop: het knopje met het HTML5-logo rechtsboven in de editor start het spel in je browser.

## Automatische test

```bash
godot --headless --path . -s tests/smoke_test.gd --fixed-fps 60
```

Speelt golf 1 en 2 met een bot die naar de dichtstbijzijnde vijand richt en schiet, en print elke 5 seconden de stand.
