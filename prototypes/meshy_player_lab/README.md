# Bloedjungle Meshy Player Lab

Een zelfstandige Godot 4.7.2-proef voor de gerigde Meshy Jungle Commando. De proef staat in `prototypes/meshy_player_lab` en is niet gekoppeld aan de hoofdscene of de bestaande speler.

## Starten

Open deze map als Godot-project. Besturing:

- WASD of pijltjes: bewegen en draaien
- Ctrl: lopen; geen modifier: rennen; Shift: RunFast
- 1–4: Idle, Walking, Running en RunFast als preview kiezen
- Linkermuisknop of spatie: schietproef
- R: herlaadproef
- Rechtermuisknop of C: gevechtscamera
- Muiswiel: camera zoomen

De camera gebruikt Bloedjungle's FOV van 45°, kijkhoeken van 58° en 48°, en afstands-/zoomgrenzen uit `scripts/camera_rig.gd`.

## Herbruikbare afspraken — Character Pipeline 2.0

- Houd de Meshy/Mixamo-armature als runtime-skelet: de geleverde speler heeft 28 botten. Pas de 53-botten-DEF-rig niet rechtstreeks toe op deze mesh.
- De hoofdbewegingen hebben semantische tegenhangers (`Hips`, `Spine`, `Neck`, `Head`, `Left/RightArm`, `ForeArm`, `Hand`, `UpLeg`, `Leg`, `Foot`), maar DEF bevat meer tussenbotten en vingerketens. De Meshy-rig heeft alleen `HandMiddle4` als vingeruiteinde per hand. Behandel de overeenkomst als een naam-/functiekaart, niet als bewijs van uitwisselbare restposes of skin weights.
- Laat de bronclips `Walking`, `Running` en `RunFast` op dezelfde armature. Geef locomotieclips een loopmodus en laat states met een korte crossfade wisselen.
- Maak een rustige `Idle`-clip als die ontbreekt; animeer alleen kleine romp-/hoofdademhaling en laat de schaal van botten ongemoeid.
- Gebruik de bestaande Meshy-handbotten als handankers en IK-doelen voor de tweehandige greep. Controleer beide polsdoelen en de wapenloop in de echte gameplaycamera.
- Voeg ontbrekende acties als afzonderlijke clips toe op dezelfde rig. Test de eindpose, overgang terug naar locomotie, handbereik en zichtbare vervorming.
- Vergelijk vóór opname: 28 botnamen, restpose/orientatie, PBR-texturen, collidermaat en modelmaat. Bewaar de oude speler als fallback tot alle tests in een geïsoleerde gameproef slagen.
- Noteer per clip de herkomst: Meshy-bronclip of lokaal geanimeerde aanvulling. Gebruik geen betaalde Meshy-clip voordat de kosten zichtbaar zijn en goedgekeurd.

## Huidige proefstatus

- Godot 4.7.2 importeert de GLB met 28 botten, 3 bronclips en de drie PBR-texturen.
- `Walking`, `Running` en `RunFast` bewegen elk 28/28 botten; geen bot heeft een zichtbare niet-uniforme schaalafwijking.
- De runtime `Idle` beweegt 15/28 botten.
- Rechter- en linkerpols volgen hun huidige IK-doelen binnen 8 mm in de locomotietest.
- De Garand komt uit het bestaande Bloedjungle-wapenpakket. De schietproef heeft een keyframed terugslag en zichtbare loopmondingsflits. De herlaadproef beweegt de linkerhand 0,29 m naar het magazijn en terug, met de rechterhand op het wapen.
- Schieten en herladen zijn lokaal gemaakte Godot-proefclips, geen Meshy-clips; er is geen gameplaykogel, munitie-/reloadlogica, volledige wapenanimatie of combat-integratie in deze scène.
- Crouch en prone zijn nog niet gebouwd of getest. Geschikte Meshy-clips die zijn gecontroleerd zijn Pro-abonnementclips; er zijn geen credits gebruikt.
- De proef draait op de iMac met Godot Compatibility/OpenGL. iPhone-import, thermiek, geheugen en framerate zijn niet gemeten.

## Validatie en captures

Importeer de testmap met Godot en voer daarna `-- --meshy-check` uit om botten, animatiebeweging, IK-bereik, schietflits en herlaadbeweging te controleren. Gebruik `-- --meshy-check --meshy-capture` om PNG-captures en filmframes in `previews/` te maken. Zet de frames om naar MP4 met:

```sh
swift tools/encode_preview.swift previews/movie_frames previews/meshy_player_animation_preview.mp4 12
```

`-- --meshy-benchmark` draait dezelfde validatie en meet 600 Godot-framecallbacks op de desktop. Dat is geen iPhone-prestatiemeting.
