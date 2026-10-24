# M1911 — schieteffecten op basis van de referentievideo (24 oktober 2026)

## Referentie en doel

Bron: door de gebruiker aangeleverde schermopname, 4,3 seconden, 512×1112, 30 fps. Hierin is top-down jungle-combat te zien met felgele schietsporen, korte warme flitsen en zichtbaar groene zombie-treffers.

**Dit is een gameplay-integratie, geen video-overlay.** Alle effecten reageren per schot op de bestaande speler, collision-detectie, munitie, projectielen en camerahoek.

## In deze Draft PR

- M1911-glow: langer en breder geel/wit tracer met oranje uitlopende staart, via bestaande `Bullet._weapon_glow`. Elk M1911-schot gebruikt dezelfde bestaande gameprojectiel-logica.
- M1911-muzzle: meer zichtbare warme mondingsflits, korte tijdelijke belichting en een beperkt aantal bestaande pooled particles.
- Zombies: bij echte raakdetectie met een M1911-projectiel een extra felgroene hit-flits plus kort groen splashburst; normale damage, knockback, death, blood en SFX blijven bestaan.
- Geluid: drie *originele* procedurale M1911-schietgeluiden, gegenereerd bij opstarten met 22.050 Hz mono PCM; korte crack, lage body, zachte tail, mechanische klik. De bestaande `Sfx.play("pistol")`-aanroep triggert ze **tegelijkertijd** met het schot. Dit bevat geen audio van de Facebook-referentie.
- Geen veranderingen aan schietsnelheid, schade, munitie, camera-instellingen of andere wapens. Geen nieuwe externe licenties of binaire assets.

## Acceptatietest in Godot / Xogot

1. Open deze **featurebranch**, niet `main`, in Working Copy of Git. Importeer de branch in Xogot of Godot 4.
2. Start de bestaande `scenes/main.tscn`. Kies het M1911-pistool en schiet in open ruimte: per schot een warmgele muzzle flash, fel zichtbare kogelstreep en droog `pop/crack`-geluid.
3. Schiet een zombie: groene korte oplichtende impact, terwijl bestaande schade en death werken.
4. Schiet tegen grond/muur: bestaande stof/vonken, geen groene zombie-hit.
5. Controleer op iPhone: meerdere schoten achter elkaar, geluid bij elk schot, geen crashes of opvallende framerate-inzakking. Test ook ander wapen om te bevestigen dat het onveranderd is.
6. Herhaal met geluid uit / aan en met build-camera op afstand.

## Grenzen / nog te controleren

- De referentie is gebruikt als visuele **inspiratie**, niet als gekopieerde game-asset.
- Er is **geen** exacte reproductie van de soundtrack of bestaande third-party-video gemaakt.
- De Godot-runtime en Xogot zijn niet beschikbaar in de gebruikte werkruimte. Er is een broncodecontrole uitgevoerd, maar geen echte runtime-/iPhone-acceptatie; deze PR blijft daarom Draft.
- Niet samenvoegen naar `main` vóór de iPhone-test.

## Belangrijkste bestanden

`scripts/data.gd`, `scripts/fx.gd`, `scripts/bullet.gd`, `scripts/sfx.gd`.

## Optioneel later

Voor nog dichter bij het filmpje: aparte instelbare "cinematic"-kwaliteit met light streak glow/impact decalsex, echte opnames van geluid met passende rechten en Godot-profiler-metingen. Eerst deze branch in Xogot testen.
