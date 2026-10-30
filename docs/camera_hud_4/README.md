# Camera + HUD 4.0 — Tactical Hybrid

## Spelen in Godot of Xogot

Open `tests/tactical_hybrid_4.tscn` op deze featurebranch en start **Run Current Scene**. De scène start een missie met de Meshy-speler, een volledig model van de Tiger, twee teamleden en drie vijanden verderop. De normale besturing, wapenkamer en HUD blijven actief. Open op iPhone in Xogot hetzelfde project en start deze scène; de iPhone 18 Pro Max is vanuit deze omgeving niet fysiek gemeten.

## Camera en bediening

- De spelcamera kijkt 53° boven de horizontaal. Afstand: 24 m tactisch, 19 m gevecht. Handmatige pinch en muiswiel blijven actief.
- Een nabije tank of minstens twee teamleden vragen meer beeldruimte. De camera scant elke 0,3 seconde, houdt de ruimere uitsnede 1,4 seconde vast en beweegt met een gedempte overgang.
- Tijdens richten verschuift het kijkpunt 5–6 m naar voren. De speler houdt zijn normale modelschaal.
- De speler heeft een subtiele gouden selectiering, richtingstreep en iets sterker silhouetlicht. Het Meshy-pistool wordt als echt model in de wapenbalk gerenderd; de munitie is groter.
- Op aanraakschermen: tik op **Sprint** om sprint te wisselen, houd de knop langer dan 0,42 s vast voor een ontwijkrol. Herladen, joystick en de bestaande radiaalmenu's blijven beschikbaar.

## Bewijs en grenzen

`game_120.png` en `game_150.png` zijn directe Godot-opnames van de testscène met OpenGL Compatibility op een Linux Xorg display met Mesa llvmpipe. Het is een software renderer, geen iPhone GPU. De schermafbeelding bewijst compositie en zichtbaarheid van de onderdelen in die opstelling. `tests/tactical_hybrid_4_capture.gd` maakt de opnames en print de gemiddelde `Performance.TIME_PROCESS` over 91 frames: **264,133 ms** in deze run. Dat cijfer omvat Godot scriptverwerking in deze Linux omgeving; het voorspelt geen 60 FPS op Xogot of iPhone. Een echte iPhone meting blijft nodig.

De gerichte controles op deze branch zijn geslaagd: `tests/camera_test.gd`, `tests/hud_layout_test.gd`, `tests/combat_visuals_test.gd`, `tests/tank_mik_test.gd` en `tests/meshy_player_integration_test.tscn`. De laatste controle draait als scène, niet als `-s`-script. Bij het afsluiten van Godot 4.6.3 meldt de lokale headless runner nog een bestaande melding over 11 resources; er waren geen scriptfouten in de uiteindelijke spelopname.
