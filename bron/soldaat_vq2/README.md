# Soldaat VQ2 (Blender-bron)

`assets/soldaat_vq2.glb` vervangt in het spel de oude Quaternius-pop (`assets/soldaat.glb`) door een realistisch mannetje
met kleding en uitrusting per rol. Hetzelfde DEF-skelet en dezelfde clips, dus alle bestaande animaties, het wapen in
de hand en de schiet-/trefferhouding werken ongewijzigd.

```bash
pip install bpy                                    # Blender 5.2 als Python-module (headless)
git clone https://github.com/makehumancommunity/mpfb2 /tmp/mpfb2   # getest op commit 6ff1eb3 (24-10-2026)
python3 bron/soldaat_vq2/maak_soldaat_vq2.py /tmp/sv2 --mpfb /tmp/mpfb2/src/mpfb/data [--render]
cp /tmp/sv2/soldaat_vq2.glb assets/ && cp /tmp/sv2/soldaat_vq2.blend bron/soldaat_vq2/
godot --headless --path . --import && python3 tools/textuur_import.py && godot --headless --path . --import
```
`--render` maakt Cycles-renders (`SAMPLES=16` voor snel) in `UIT/renders/`. Duur zonder renders ongeveer 70 s.

## Hoe het gemaakt wordt
- `mens.py`: MakeHuman-basismens uit MPFB2 (`base.obj`, macro-targets man/jong/gespierd, game_engine-skelet en
  huidgewichten). Elk MakeHuman-bot wordt met een eigen affiene afbeelding op het overeenkomstige DEF-bot gelegd
  (romp/hoofd staan al goed; armen en benen draaien van A- naar T-houding en rekken langs het bot), zodat ellebogen en
  knieen op de DEF-gewrichten liggen. De gewichten worden hernoemd naar de DEF-botten.
- `lagen.py`: vier lichaamsvarianten met kleding als verdikking langs de normaal (broek over de laars, kraag,
  mouwboord, opgerolde mouwen bij de vijand) en procedurele PBR-lagen per texel uit de 3D-rustpositie
  (`textuur.py`): woodland-camouflage met zakken, naden, knopen, plooien, vuil en zweet; vijandkleding met
  reparatielappen; mouwloos shirt; handschoenen; huid met haar, wenkbrauwen, lippen, stoppels/baard en camouflageverf.
- Elke variant: fijn lichaam (26k driehoeken) -> vereenvoudigd tot 7.650 driehoeken (hoofd en handen beschermd),
  normal map gebakken van fijn naar grof (Cycles), AO gebakken op het fijne lichaam, plus detailnormaal uit de hoogte.
  Lichaam onder de laars weggelaten.
- `uitrusting.py`: delen gevormd op het echte lichaamsoppervlak (schalen langs de normaal, randen, tassen, metaball-
  laarzen), eigen UV's in een gedeelde 1K-atlas (4x4 tegels), gewichten van het dichtstbijzijnde lichaamspunt
  (hoofddeksels volledig aan `DEF-head`).

## Knopen en materialen (contract met `scripts/soldier_model.gd`)
- `Scene > Rig` (Skeleton3D, 53 DEF-botten, ongewijzigd uit `soldaat.glb`), clips `stil lopen rennen achteruit
  schieten geraakt dood1 dood2 steken herladen`; klimmen, zitten en acties blijven uit hun eigen glb komen.
- Lichamen: `Lijf_Uniform`, `Lijf_Bloot`, `Lijf_Mouwloos`, `Lijf_Vijand`; elk 2 materialen: `<Variant>_Huid` (niet
  getint) en `<Variant>_Kleding` (Godot zet `albedo_color = SoldierModel.uniform_tint(uniformkleur)`).
- Uitrusting (materiaal `Uitrusting`, `Hoofdband` getint met de bandkleur): `Helm Vest Koppel Rugzak Hoofdband Bandana
  Boonie Pet Staalhelm Borsttuig Patroongordels Raketzak Laarzen Laarzen_V`.
- Looks (`SoldierModel.LOOKS`): `eigen` (bondgenoten, wachten), `speler:bloot|mouwloos|uniform|vest` (volgt
  Uitrusting > Bovenlijf), `vijand:knife|rifle|rocket|heavy`. Instelling *Mannetjes* = *Oud model* zet v1 terug.

## Cijfers
| deel | driehoeken |
|---|---|
| elk lichaam | 7.650 |
| eigen soldaat (lichaam + helm, vest, koppel, rugzak, laarzen) | 11.594 |
| speler bloot (+ hoofdband, koppel, laarzen) | 9.506 |
| vijand mes / geweer / raket / zwaar | 8.966 / 9.970 / 9.346 / 9.968 |
| oud model (pop zonder uitrusting) | 13.744 (+ uitrusting uit `uitrusting.glb`) |

Texturen: per lichaam 1024x1024 albedo, normal en ORM (4 sets) en een 1024x1024 uitrustingsatlas; geen 2K.
In Godot ASTC met mipmaps (`tools/textuur_import.py`). Materiaalsurfaces per mannetje: 2 (lichaam) + 1 per uitrustingsdeel.

## Licenties en herkomst
- Menselijk basismodel, targets, skelet en huidgewichten: MakeHuman/MPFB2-assets, **CC0 1.0** (zie `LICENSE.ASSETS.md`
  in MPFB2). Er is geen MPFB-code gekopieerd; `mens.py` leest alleen de data.
- Clips en skelet: ongewijzigd uit het bestaande `assets/soldaat.glb` (Mixamo-geweeranimaties, al in dit project).
- Alle texturen procedureel uit dit script; geen foto's of betaalde bronnen.

## Tests en beelden
- `tests/soldaat_vq2_test.gd`: elke look toont precies zijn delen, alle 17 clips aanwezig en het been beweegt bij
  lopen, tint/hoofdband/flits, wapen in de hand, bovenlijf wisselen, terugval op v1.
- `tests/soldaat_foto.gd`: voor/na met de echte spelcamera (bovenste rij v1, onderste VQ2), ingezoomd, lopend, schietend.
- Viewer: `tools/blender-vq2-viewer/` (model *Soldaat*, keuzelijst *Rol / uitrusting*), test `node test-soldaat.mjs`.
- Beelden in `docs/vq2/renders/soldaat-*.png`. Geen iPhone-FPS gemeten.
