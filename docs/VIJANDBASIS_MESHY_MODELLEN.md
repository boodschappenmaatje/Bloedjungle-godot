# Vijandbasis (stap D2 / 5b): welke Meshy-modellen heeft Dennis nodig?

Opgesteld 2026-11-03 voor Dennis, Claude en Codex. Dit is de voorbereiding van de Asset Design Specification (zie `CLAUDE.md`); per model komt een eigen specificatie ter goedkeuring zodra Dennis een model aanlevert. Stap 5a bouwt de basis met blokken (`scripts/vijand_basis.gd`); 5b vervangt de blokken door deze modellen.

## Welke modellen zijn nodig (op volgorde)

| # | Model | Nodig? | Maat (m, ongeveer) | Opmerking |
|---|---|---|---|---|
| 1 | **Vijandelijk hoofdkwartier** | **GELEVERD en verwerkt (4 nov 2026, v188)**: Dennis' "Enemy hk", zie `bron/vijand_hk/README.md` | grondvlak 9 x 9, 5 tot 6 hoog, plat dak | Het doel dat je moet slopen om te winnen. Ingang aan de zuidkant (+Z, naar jouw basis). Bunkerkwaliteit zoals jouw HK. Schadefases (rook, vuur, donkerder) doet de code; een tweede model "vernield" (puinhoop 9 x 9 x 2) is mooi maar mag later. |
| 2 | **Vijandelijke poort** | Ja, 5b | totaal ca. 9 breed, opening 6,8 breed en minstens 4,4 hoog, 1,5 diep | Staat in de zuidmuur. Open poort zonder deuren (geen bewegende delen). Doorgang moet echt leeg zijn (tanks en jeeps moeten erdoor). |
| 3 | **MG-wachttoren Browning M2HB .50 cal** | **Ontwerp goedgekeurd, model nog te maken** (vier keer); zie [Asset Design Specification](asset_design/vijand_m2_toren_5a3b.md) | voet 2,6 × 2,6 m, hoogte 6 m | Half gesloten onderbouw, ladder met bordes aan binnenzijde; 650 HP, 36 m, 8 schoten van 6 schade; schutter en toren afzonderlijk uitschakelbaar. |
| 4 | **Mortierstelling** | Later (laatste onderdeel van keuze E) | 3 x 3, 1,5 hoog | Liefst twee losse delen: sokkel en buis (de buis moet kunnen richten). Eén stuk kan ook, dan fake ik het richten. |
| 5 | Muurmodule | Optioneel | 4 lang, 1,8 hoog, 0,4 dik, recht afgesneden uiteinden | Meshy is slecht in naadloos aansluitende delen. Advies: muur blijft door de code gebouwd met een mooie textuur, alleen als je een eigen muurlook wilt maken we dit. |
| 6 | Vlag met mast | Optioneel | mast 6 hoog | Mag ook in het hoofdkwartier-model zitten (op het dak). |

**Niet met Meshy nodig (hergebruik, andere kleuren):** kazerne, garage, depot, generator, tank, jeep, soldaten (model *assault* en de vijandkleuren voegt Dennis zelf toe via Codex), zandzakken, kisten, vaten.

## Zo is het model makkelijk te verwerken (Claude en Codex)

- **Eén bestand per model**, `.glb`, deellink via Drive "iedereen met de link" (zoals bij garage en voorraadtruck; ook 100+ MB en miljoenen driehoeken gaan goed, wij maken het zelf licht).
- **Rechtop, onderkant op de grond, voorkant naar +Z** (het zuiden, naar jouw basis). Zeg erbij welke kant voor is als dat niet duidelijk is.
- **Maat:** liefst zoals in de tabel, anders noteer je de hoogte in meters; wij schalen.
- **Gesloten, massieve vormen.** Geen binnenkant nodig, geen losse zwevende stukjes, geen dunne draden of antennes (worden scherven), geen glas of doorzichtig materiaal, geen grondplaat, gras of schaduw in het model.
- **Geen tekst of stencils** in de prompt (Meshy schrijft onleesbare letters die wij moeten wegpoetsen).
- **Kleuren:** subtiel groen-geel, passend bij de kleuren van het vijandmodel *assault*. Zodra die in de repo staan, passen wij ze aan in `scripts/vijand_basis.gd` (rij `KLEUR_*`).
- **Geen bewegende delen nodig.** Beweging (richten van de mortier, rook, schade, vlag) doet de code.

## Wat wij ermee doen

Zelfde pijplijn als garage en voorraadtruck (`bron/garage_meshy/`, `bron/voorraad_meshy/`): voxel-remesh, decimeren (ca. 40 tot 50 duizend driehoeken, plus een afstandsversie), Smart UV, bakken naar 2K PBR, botsvorm, viewer-invoer (`tools/blender-vq2-viewer/`), USDZ-preview, rapport en een Draft PR. Eerst een Asset Design Specification ter goedkeuring; niet mergen of OTA zonder aparte goedkeuring.
