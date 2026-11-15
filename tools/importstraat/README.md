# Importstraat voor Meshy-modellen

Vaste, grotendeels automatische route om een Meshy-`.glb` (miljoenen driehoeken, 1 materiaal, versnipperde UV) zonder zichtbaar kwaliteitsverlies in Bloedjungle te krijgen. Afgesproken met Dennis op 15 november 2026. Volgt [docs/ASSET_QUALITY_STANDARD.md](../../docs/ASSET_QUALITY_STANDARD.md) en de Meshy-lessen (decimeren laat de Meshy-textuur schuiven, dus: nieuwe UV + hoog naar laag bakken).

## Werkwijze

1. **Aanleveren.** Dennis zet het `.glb` in de Drive-map `import/` (map gedeeld met "iedereen met de link", anders kan de cloud het niet downloaden). De bestandsnaam zegt het type en eventueel de maat:
   - `gebouw_kazerne_h8.glb`, `plant_varen_h1.2.glb`, `voertuig_pickup_l5.4.glb`, `prop_kist_b1.glb`
   - maatcode: `h` = hoogte, `b` = breedte (x), `l` = lengte (diepte); zonder code geldt de standaardmaat van het type.
   - optioneel een regelbestand `<naam>.json` ernaast (zie onder).
2. **Straat draaien** (Claude, headless Blender via `pip install bpy`):
   ```
   tools/importstraat/draai.sh <map met glb's> <uitmap>
   ```
   of per model `straat.py` + `rapport.py`.
3. **Rapport bekijken.** `RAPPORT.md` + `rapport/overzicht.jpg`: voor/na uit dezelfde hoeken (voor, achter, schuin, spelcamera, boven, dichtbij), driehoeken, texturen, geheugen (ASTC), geschatte fps en een beeldverschil (PSNR) per hoek.
4. **Mooi?** Dan `keur_goed.py <uitmap>` → `assets/bibliotheek/<type>/<naam>/` + regel in `assets/bibliotheek/bibliotheek.json` (de lijst waar de tekenmodus van de AI builder tool later uit kiest). Een opmerking? Regels aanpassen en de straat opnieuw draaien.
5. Zoals altijd: Draft PR, niet mergen of OTA zonder Dennis' go.

## Wat de straat doet (`straat.py`)

| Stap | Wat |
|---|---|
| Inlezen | alle stukken samen, transformaties toegepast, dubbele punten weg |
| Maat | draaien (`draai_z`), **zonder vervorming** schalen tot de maat in meters, midden op x/y = 0, **grond op z = 0** (`grond_ref` voor de echte voet) |
| Vereenvoudigen | eerst bijna-vlakke stukken oplossen (vlak = geen driehoeken nodig), daarna inklappen (kwadratische fout: randen en silhouet gaan als laatste) tot het budget; gewogen normalen met scherpe randen |
| Bakken | nieuwe UV (smart project + pack), van het hoge Meshy-net naar het lage: **kleur, normal map, ORM** (2K of 4K, Cycles CPU) |
| Typeregels | **gebouw**: botsingsnet `-colonly` (trimesh, binnen begaanbaar), deuren/ramen uit `deuren` als losse knopen · **plant**: windgewicht in de vertexkleur-alfa (voor `shaders/foliage.gdshader`) · **voertuig**: wielen/delen uit `delen` als losse knopen met pivot in hun midden, convex botsblok · **prop**: convex botsblok |
| LOD | Godot maakt de detailniveaus zelf bij import (`meshes/generate_lods=true`, staat aan in de `.glb.import`) |
| Uitvoer | `<naam>.glb` (game, texturen erin), `<naam>.blend` (bron), `textures/*.jpg`, `stats.json` |

### Standaardregels per type

| Type | Maat | Driehoeken | Textuur | Botsing |
|---|---|---:|---:|---|
| gebouw | h 8 m | 30.000 | 2K | trimesh (2.000 tris) |
| plant | h 2 m | 4.000 | 1K | geen |
| voertuig | l 5 m | 30.000 | 2K | convex |
| prop | h 1 m | 3.000 | 1K | convex |

### Regelbestand (`<naam>.json`, alles optioneel)

```json
{
  "naam": "kazerne_meshy",
  "tris": 40000, "tex": 4096,
  "maat": ["h", 8.0], "maat_ref": [-0.43, 0.42], "grond_ref": -0.43,
  "draai_z": 180,
  "botsing": "trimesh", "botsing_tris": 3000,
  "metaal_max": 0.0,
  "delen":  [{"naam": "Wiel_LV", "min": [-1.2, 1.4, 0], "max": [-0.7, 2.0, 0.8]}],
  "deuren": [{"naam": "Deur_1", "min": [-0.6, -4.1, 0], "max": [0.6, -3.8, 2.2]}]
}
```
`maat_ref`/`grond_ref` zijn in de maat van het Meshy-bestand (handig als er stenen of een voetstuk onder zitten). `delen`/`deuren` zijn in meters ná het schalen.

## Wat nog niet automatisch gaat (eerlijk)

- Deuren, ramen en wielen **herkennen** doet de straat niet zelf: je geeft hun blok op in `deuren`/`delen`. Een schademodel, clips en gameplay (rijden, openen) blijven per model werk in Blender/Godot.
- De fps in het rapport is een **vuistregel** vanaf de native meting (~110 fps, 27 okt), geen meting. iPhone: **NIET GETEST** tot Dennis het op zijn toestel probeert.
- Het beeldverschil vergelijkt Cycles-renders, niet de Godot-belichting.

## Eerste proef: Dennis' Meshy-dam en -sluisdeur (15 nov 2026)

- Dam: 2.403.118 → 50.000 driehoeken, 4K gebakken, PSNR 31-39 dB. Sluisdeur: 898.670 → 12.000, 2K.
- Daarna `bron/dam/meshy_dam.py` (via `DAM_MESHY=<uitmap> python3 bron/dam/maak_dam.py`): verbreed naar 60 m door het vlakke muurstuk gespiegeld te herhalen, uitsparing voor de drie deuren, 8 x 3 blokken gezaagd met dichte zaagvlakken, dezelfde knoopnamen en clips Kraken/Breken.
