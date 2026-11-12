# Cinematisch tankschot (Tiger en vijandelijke tank)

Gekozen door Dennis op 12 november 2026: **1A 2A 3A 4A 5A 6A 7A 8A 9A**. Aan/uit: Instellingen > BEELD > **Wapeneffecten**: Nieuw of Klassiek (dezelfde knop als shotgun en pistool). Klassiek geeft het oude tankschot terug.

| Keuze | Laag | Uitwerking |
|---|---|---|
| 1A | Welke tank | Beide: `TankFx.shot` wordt aangeroepen door `tank.gd` (Tiger) en `vijand_tank.gd`. |
| 2A | Flipbooks | Vier 4x4-vellen van 1024 px in `assets/tankfx/`. **Afwijking:** niet uit een Blender-simulatie maar procedureel (numpy), zie hieronder. |
| 3A | Mondingsvuur | Lange vuurtong met twee zijtongen (mondingsrem), plat op loophoogte zodat het van bovenaf te zien is, plus kern-flits, vonken en een lamp van 0,3 s. Hoog en Ultra leggen er een tweede, kleinere tong overheen. |
| 4A | Drukgolf | Ring van stof over de grond (de schokgolf-shader van de gouden explosies), 15 m, 0,45 s. |
| 5A | Rook | Wolk voor de loop die 3,8 s blijft hangen en met de wind meedrijft (Hoog en Ultra: een tweede). |
| 6A | Stof | Stofwaaier voor de loop; Hoog en Ultra ook stof rond de rupsen en opvliegende blaadjes. |
| 7A | Granaat in de lucht | Snelle lichtstreep (halo plus kern, 4,4 m) in plaats van het oranje balletje. Jouw Tiger had geen zichtbare granaat: die krijgt nu dezelfde streep (0,5 s vlucht, schade en timing ongewijzigd). |
| 8A | Inslag | De gouden explosie 1,25x groter plus een aardfontein (billboard-flipbook) en stofring; Hoog en Ultra extra aarde en stof. |
| 9A | Gevoel | Alleen Tiger waar jij in zit: camera-schok, inzoomstoot (Hoog/Ultra) en trilling (iOS/Android, schakelbaar). Bij elke tank: diep kanongeluid met echo en nu ook de Schieten-animatie (terugslag) van de Tiger, die eerder nooit werd afgespeeld. |

## Geluid
`assets/wapenfx/geluid/tankschot.wav` is **zelf gesynthetiseerd** (`bron/tankfx/maak_geluid.py`), geen echte opname. Een echte opname kan later onder dezelfde naam. Op de iPhone beluisteren is nog nodig.

## Flipbooks: eerlijk over de bron
- Meshy kan geen flipbook maken (API: alleen 3D, rigs, animaties en losse plaatjes; de app heeft een korte AI-video zonder doorzichtigheid, van opzij).
- `bron/tankfx/maak_tankfx.py` is een Mantaflow-simulatie voor Blender (vuur en rook van bovenaf). In headless Blender 5.2.4 in de zandbak werd het volume niet gerenderd (zelfde probleem als de eerdere M-47-poging), dus de gebruikte vellen komen uit `bron/tankfx/maak_flipbooks.py`: gedraaide fBm-ruis met domain warping en een tijdsverloop. Het script blijft staan voor een Blender met venster.
- Gevolg: het vuur en de rook zijn zachter dan een echte simulatie. Een echt gesimuleerd vel kan één-op-één dezelfde bestandsnaam krijgen.

## Niet gedaan (uit de kaart)
- Hittewaas (trillende lucht) en buigende struiken bij de drukgolf (alleen de stofring).
- Slow motion (keuze 9C was niet gekozen).

## Prestatiebudget
- Alles uit de voorraden van `WapenFx` (max 8 per soort), geen schaduwen, alleen binnen 45 m van de camera. Een tank schiet hooguit eens per 4 s.
- Max 1 lamp per schot (0,3 s), max 4 schokringen, vier vellen van 1024 px (samen ca. 3,5 MB op schijf, ca. 16 MB uitgepakt in het geheugen).
- Meting op de iPhone: **NIET GETEST**.

## Bronnen en tests
`scripts/tank_fx.gd`, `assets/tankfx/` (vellen + twee shaders), `bron/tankfx/`, `tests/tankschot_foto.gd` (voor/na met identieke camera: `BJ_TANKFX=nieuw|klassiek`).
