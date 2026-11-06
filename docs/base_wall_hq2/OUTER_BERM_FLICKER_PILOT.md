# Bloedjungle — buitenmuur berm-flikkering (reparatiekandidaat)

**Status:** Draft PR / alleen kandidaat; niets mergen of OTA-publiceren zonder expliciete toestemming.

## Reproductie en oorzaak

Op iPhone is de flikkering aan de buitenzijde van de eigen basismuur zichtbaar. Met **Instellingen → Test: muuronderdelen → Berm uit** verdwijnt deze. Dat is een sterke aanwijzing dat de aarden berm betrokken is; een definitieve fysieke oorzaak is nog niet met een iPhone-GPU-capture bewezen.

In `scripts/base_props.gd` lagen de vlakke 22cm-hoge bovenzijden van de bermstroken bij de vier hoeken op exact dezelfde diepte als de hoekkap. De bermbasis lag bovendien op y=0, precies op het wereldgrondvlak. De oude corner-check herkende ook poorteindpunten ten onrechte als echte hoeken, waardoor de berm richting de poorten uitstak.

## Reparatiekandidaat

- Bermstroken sluiten op de **toprand** van de hoekkap aan zonder coplanaire overlap; geen overlappende topvlakken meer op de vier hoeken.
- Alleen echte buitenhoeken krijgen een korte verlenging; de twee doorgangen blijven vrij.
- De onderzijde van stroken en hoekstukken ligt 3 cm onder het grondvlak, zodat geen bermvoet exact op y=0 ligt. De zichtbare bovenkant blijft op 22 cm.
- Materialen, Meshy-muur, schaduwen, LOD-keuzes, botsingen, wapens en terreinshader zijn ongewijzigd. **Berm blijft zichtbaar** in de normale instelling.

## Acceptatie

1. `tests/base_wall_hq2_test.gd`: geometrische controle op acht topvlak-aansluitingen, geen coplanaire overlap met hoekstukken, vrije doorgangen en ondergrondse bermvoeten; bestaande muur-, AI-, botsing- en schiettests blijven slagen.
2. CI: Godot-import + iOS unsigned export, OTA-preview met publicatie overgeslagen.
3. **Nog fysiek op iPhone testen:** zet beide muurdiagnoses terug op `Normaal`/`Auto`, loop langs de buitenmuur en de vier hoeken onder dezelfde camerahoek; vergelijk bij daglicht en regen en met FPS-meter aan. Bevestig dat flikkering weg is terwijl berm en muurdetail behouden zijn.

**Releasepoort:** geen merge en geen OTA-publicatie totdat de kandidaat visueel is geaccepteerd.