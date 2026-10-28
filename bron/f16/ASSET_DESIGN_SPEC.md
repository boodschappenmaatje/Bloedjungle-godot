# Asset Design Specification — F-16 Fighting Falcon

Status: GOEDGEKEURD door Dennis 2026-10-28 ("Kleur moet originele kleur worden, verder mag je nu gaan bouwen"). Kleur = echte USAF-grijstinten. Standaard: `docs/ASSET_QUALITY_STANDARD.md` (High Quality Showcase + VQ2).

## Keuzes Dennis
1A vervangt `assets/straaljager.glb` in de napalm-luchtsteun · 2 F-16 Fighting Falcon met raketten onder de vleugels · 3-5 eerste voorstel.

## Uiterlijk
- F-16C: bubbelcockpit, luchtinlaat onder de romp, enkele staart, geblendde vleugel-romp, ventrale vinnen. Lengte ~15 m, spanwijdte ~10 m (1 unit = 1 m).
- Kleur: grijs tweetone (voorstel; jungle-camo mogelijk later).
- Wapens: AIM-9 aan de vleugeltippen, 2x AIM-120 onder de vleugels, 4 napalmbussen (Bom1-4) op pylonen voor de killstreak (gameplaycontract), extra brandstoftank onder de romp.
- Weathering: beheerst (uitlaatvuil, verf-slijtage aan randen, panelen), PBR albedo/normal/ORM.

## Gameplaycontract (behouden uit huidige straaljager)
- Node-hiërarchie: `Straaljager > Body > …`; `Bom1`..`Bom4` blijven bestaan als loslaatbare Node3D (napalm_aanval.gd zoekt ze met find_child).
- Clips: `Vliegen-loop` (2 s, lus), `Bocht` (3 s), `Aanval` (3 s) blijven bestaan. Nieuw: `Rol` (2 s), `Landingsgestel` (2,4 s: uit, vast, in), vlucht = ingeklapt.
- Voorwaartse as = -Z, pivot in zwaartepunt, schaal in game 0,8 (12 m op scherm; indien nodig aanpassen).
- Blender-clips: Vliegen-loop (staartroeren/kleppen trillen, nabrander-flikker via materiaal-emissie of schaal), Bocht, Aanval, Rol, Landingsgestel.
- Godot-gestuurd: vliegpad, bochten/duik in de wereld, bom-loslaten, nabrander-gloed, condenssporen, geluid (`Sfx.jet_*`).

## Budget en oplevering
- Game-GLB ~12.000 driehoeken, 1 gedeeld hoofdmateriaal + kleine extra's, textures 1K–2K; showcase-bron apart 2K.
- Opleveren: `.blend`, reproduceerbaar `bron/f16/maak_f16.py`, game-`.glb`, `.usdz`-preview, viewer-invoer (`tools/blender-vq2-viewer/`, oud/nieuw naast elkaar), gamecamera-render oud/nieuw, Godot-import + regressietest `napalm`/killstreak, driehoeken/materialen/texturebron gerapporteerd, Draft PR (geen merge zonder go).
- NOT RUN tenzij echt gedaan: iPhone/Xogot-FPS, Quick Look op iPhone.

## Acceptatie
Zelfde napalm-aanval werkt ongewijzigd, 5 clips zichtbaar bewegend, zichtbaar beter dan huidige jet vanuit gamecamera, test slaagt.
