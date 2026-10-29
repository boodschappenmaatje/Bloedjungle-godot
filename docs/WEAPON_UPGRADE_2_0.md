# BLOEDJUNGLE — Weapon Upgrade 2.0 (goedgekeurd ontwerp)

**Status:** ontwerp door gebruiker goedgekeurd op 29 oktober 2026; implementatie gestart als aparte Draft PR.  
**Project:** `boodschappenmaatje/Bloedjungle-godot` • **Engine:** Godot 4 • **Auteur-tools:** Blender / Codex / Claude Code.  
**Verplichte kwaliteitsstandaard:** [ASSET_QUALITY_STANDARD.md](../ASSET_QUALITY_STANDARD.md). Die norm gaat voor deze specificatie. **Niet mergen naar `main` of publiceren naar `updates`/OTA zonder aparte expliciete toestemming én visuele goedkeuring.**

## Doel en non-goals

Vervang de zes huidige blokkerige/vaak te grote handwapens door natuurgetrouw geproportioneerde, licht gebruikte militaire Blender-modellen en maak **elk wapen merkbaar anders in de echte gameplay**. Lever daadwerkelijke Blender-bronnen, zes werkende Godot-gameassets, unieke mechanische bewegingen/feedback, een interactieve mobiele viewer en een Godot Weapon Test Zone.

Geen herontwerp van de HUD, geen nieuw wapenselectiesysteem, geen nieuwe spelersrig, geen ongecontroleerde wijzigingen in damage/economie/upgrades, geen extra zware realtime lichten/particlessystemen.

## Vastgestelde huidige implementatie

- `bron/wapens/maak_wapens.py` produceert `bron/wapens/uit/wapens.blend` en `assets/wapens.glb`; huidige vormen bestaan overwegend uit dozen/cilinders en eenvoudige kleurmaterialen; `bron/wapens/README.md` documenteert de clips.
- Namen **ongewijzigd houden:** `M1911`, `Thompson`, `Garand`, `Trench`, `MG42`, `Bazooka`, plus `Huls` en `Raket`. De GLB is een gedeelde resource.
- Bewegende nodes **behouden:** `M1911_Slede`, `Thompson_Repeerknop`, `Garand_Sluiting`, `Trench_Pomp`, `MG42_Repeergreep`. Clips: `M1911_schot`, `M1911_leeg`, `Thompson_schot`, `Garand_schot`, `Trench_schot`, `MG42_schot` (export en import op 60 Hz). Bazooka had geen GLB-clip.
- `scripts/soldier_model.gd` hangt de GLB aan `DEF-handR` en gebruikt `_gun_player`, `shoot_recoil`, `gun_reset`, `muzzle_position`, `casing_position`, `casing_axes`; **dit contract mag niet breken**. Speler én AI gebruiken dezelfde wapens.
- `scripts/data.gd` bevat `WEAPONS` (echte gameplaywaarden), `WEAPON_VISUALS` (VFX) en `WEAPON_SND`; `scripts/player.gd` berekent schoten; `scripts/bullet.gd` collision/explosies; `scripts/fx.gd` pooled FX; `scripts/sfx.gd` geluid.
- `scripts/weapon_strip.gd` maakt HUD-wapenfoto's uit het echte GLB; winkel/pauzemenu hebben aparte afbeeldingen. Werking en ID's behouden.
- `Data.SOLDIER_SCALE = 1.2`; `SoldierModel.GUN_SCALE = {}` op huidige main. Daarom **werkelijke in-game verhoudingen met soldaat/hand controleren**, niet slechts de Blender-metermaat of alles blind schalen. Laat speler en vijand geloofwaardig vasthouden zonder zwevende linkerhand.
- **Bestaande basiskernwaarden onveranderd totdat gameplay-afwegingen aantoonbaar nodig zijn:** M1911 26 dmg/0,19s/8, Thompson 18/0,075s/30, Garand 80/0,30s/8, Trench 9×16/0,62s/6, MG42 27/0,05s/100, Bazooka 240/1,00s/1 met 4,8m explosieradius. Upgrades blijven compatibel.

## Zes visuele en mechanische identiteiten

| Wapen | Vorm en natuurlijke verhoudingen | Gameplaygevoel, geluid en effect |
|---|---|---|
| **M1911** | Compact historisch pistool, ronde sledehoeken, subtiele kartels, slanke frame-/greepverhouding, echt hout of gripmateriaal. Doellengte ~216mm. | Duidelijke enkelvoudige droge knal; snel weer gericht; slede/lege-slede bewegen; bescheiden handterugslag. |
| **Thompson M1928** | Slankere receiver, juiste magazijnvorm, vloeiende houten kolf/pistool- en voorgreep, proportionele loop. Doellengte ~860–890mm (variant controleren). | Herkenbare regelmatige SMG-ratel, repeterende flits/hulzen; oplopende spreiding in lange bursts die herstelt bij rust. |
| **M1 Garand** | Grootste bestaande proportiefout: huidige scriptgeometrie lijkt ruim langer dan historisch. Realistische 1105mm inclusief doorlopende taps gevormde kolf, subtiel metaal en vizieren. | Zware, precieze afzonderlijke knallen en sterke schouderreactie; penetratie blijft; op laatste schot herkenbare clip-'ping' en zichtbare sluitstand, pas op hoorbaarheid in vuurgevecht. |
| **Winchester M1897** | ~1000mm (historische trenchvariant verifiëren), vloeiende houten kolf, minder dikke ontvanger, echt geperforeerd hitteschild en natuurlijke pomp. | Breed gespreide hagel op korte afstand, zware knal/rook/inslagpatroon; duidelijk afzonderlijke pompslag + mechanische klik. Geen hagel-tracers op alle pellets. |
| **MG42** | ~1220mm, herkenbare slanke loopmantel met echte gaten in plaats van opgezette blokken; munitieband en bipod geloofwaardig. | Snelle zware ratel, gecentreerde maar gestapelde terugslag, oplopende spreiding, trager lopen (bestaande `slow`), voelbare suppressie-reactie bij vijanden indien meetbaar/betaalbaar. |
| **M1 Bazooka** | ~1400mm lanceerbuis (exact model/variant verifiëren), proportionele diameter, montage, vizier, grips; geen onterecht voortdurend uitstekende raket in vuurstand. | Expliciete zichtbare raket + beperkt rookspoor en uitlaatwolk; zware impact/explosie/druk; geen pistoolflits, grote rookwolk of oncontroleerbaar camerageschud. |

Afmetingen zijn ontwerprichtlijnen; verifieer type en exacte variant, grip, barrel tip, en verhouding op echte soldaat bij standaardcamera. Historische realistische lengte ≠ schuiven van wapenpivot of veranderen van gamedata.

## Verplichte uitvoering

### Fase A — Blender HQ, echte productie
1. Lees canonieke standaard + `AGENTS.md` / `CLAUDE.md`; inventariseer op **actuele main** en andere open PR's de wijzigingen, respecteer bestaande bron en gebruik dezelfde **featurebranch + Draft PR** gedurende de hele cyclus.
2. Bouw de zes modellen met **echte vloeiende contouren** (geen lange kubuskolf of opgelegde platte gaten), bevels/weighted normals, bruikbare UV's en geloofwaardige schaal. Hero/showcase-bron gedetailleerd, **afzonderlijke mobiele export** met zo min mogelijk meshes/drawcalls, gedeelde 512–1K game-atlassen waar bruikbaar, hogere resolutie alleen aantoonbaar zinvol.
3. Materialen: licht geparkeriseerd staal, geblauwd staal, walnoot/houtnerf, bakeliet/grip en subtiele slijtage. **Hergebruik bij voorkeur bestaande goede CC0/PBR-bibliotheek**; toon maximaal 2–4 echte materiaalreferenties en vraag keuze vóór een nieuwe Poly Haven-download zoals de canon voorschrijft. Geen fake 2K-upscale. Geen plastic look, vlakke materiaalvlakken of random roest.
4. Export: bewerkbare `.blend`, generator `.py`, geoptimaliseerde `.glb`, texture/licentieherkomst en waar haalbaar `.usdz` voor iOS Quick Look. Aparte hi-res bron nooit overschrijven met low-res gameasset.
5. Retain GUID/resourcepad waar mogelijk, knopen, pivots, grip-oorsprong, GLB animation track paths en 60Hz clipimport. Verifieer echte slede-, knop-, pomp-, en bolt-motion. Kleine nette aanvullende clips alleen met werkende Godot-trigger, geen dummy. Zorg dat een vizier/raketpunt niet per ongeluk de uiterste `muzzle_position()` wordt. Gebruik zo nodig expliciete muzzle-socket plus compatibele fallback.

### Fase B — merkbare gameplay-identiteit
1. Maak per wapen **verschillende zichtbare schietposes** in bovenlichaam/schouder/handen, en gedoseerde cameraimpulsen. Richting, bewegingsbesturing, aim assist, sprint, animatieblending en tegenstanders intact.
2. Toon mechaniek: M1911 lege slede; Thompson repeteren; Garand afsluitstand + laatste clip-ping; Trench pompen; MG42 snelle repetitie, band; Bazooka raket/rook. Opnieuw herladen en wapenwissel moeten poses resetten.
3. Op automatische wapens **tijdelijke en begrensde spread-bloom** alleen tijdens aanhoudend schieten, herstel bij stoppen, reset bij wissel; geen permanente accuracy-nerf en behoud upgrades en schade.
4. Audio: onderscheidbare lagen (shot/transient, mechaniek, afstand/uitsterven), zachte maar hoorbare clip-/pomp-/magazijnaccenten, met eigen beluisterbare voorbeelden. Alleen originele/licentievrije/licentiegecontroleerde bronnen. Niet zomaar een enorm aantal stemmen per schot; bestaande `Sfx`-pool bewaken.
5. Impactfeedback: M1911 lichte impact, Garand doordringing, Trench meerdere lokale impacts, MG42 ritmische impact/suppressie zonder AI-opstopping, Bazooka explosies + gebouwwisselwerkingen; houd bestaande bullet/damage/collisions/voertuigschade. Pooled/gelimiteerde FX; geen GPU-partikelstorm.
6. Geen overmatige camera shake of nieuwe HUD-knoppen; effect werkt ook op de bestaande iPhone-gamecamera. Elke upgrade moet in gevecht **onmiddellijk herkenbaar** zijn zonder iconen.

### Fase C — weergave, QA en goedkeuring
1. **Vereiste `scenes/weapon_test_zone.tscn` of gelijkwaardig**: 6 wapens wisselen, vaste + bewegende vijanden op verschillende afstanden, harde/lichte doelen en voertuigen, schieten/herladen/geluid/VFX/animaties in de **echte Godot-3D-gamecamera**. Laat elke wapenidentiteit tijdens gameplay vergelijken, geen losse niet-speelbare mock-up.
2. Breid **bestaande** `tools/blender-vq2-viewer` uit: V1/V2 naast elkaar, identieke belichting/gamecamera, echte GLB's; 360° pinch-zoom en echte animaties, telefoonvriendelijke bediening. Toon per wapen ook de houding in de handen van een bestaande soldaat. Geen nieuw los viewersysteem.
3. Inspecteer `tests/wapen_clips_test.gd`, `tests/combat_visuals_test.gd`, `tests/loadout_test.gd`, `tests/auto_raken_test.gd` en relevante andere regressies. Voeg tests toe voor echt bewegende knopen, niet-gewijzigde munitie/damage/upgrades, custom spread-bloom, Garand last-shot audio, juiste muzzle/casing positie en geen missende scenes.
4. Reproduceer Blender-build + GLB-import, doe Godot headless/gameplaytests en browser-cliptests. **Meet op een echte iPhone 18 Pro Max in Xogot** vóór een claim van 60 FPS; elders labelen `NOT RUN`. Neem alle zes tegelijk mee in worst-case gunfire en stel budgetten bij op de meting.
5. Lever voor/na met **exact dezelfde camera, pose, belichting en beeldgrootte**, triangle/mesh/material/texture/drawcall rapport, teststatus `PASS/FAIL/NOT RUN`, screenshots/video en een geverifieerde telefoon-viewerlink. Behoud oude versies bereikbaar voor vergelijking en roll-back.
6. Gebruiker beoordeelt resultaat; **geen merge/OTA** zonder afzonderlijke expliciete instructie. Geen ongecontroleerde wijzigingen in andere features/HUD/renderer.

## Controlepunten voor modelkwaliteit en gameplay

- [ ] Alle zes wapens visueel realistisch, proportioneel en correct vastgehouden; geen blokkerige grepen/kolven, geen enorme Garand/MG42.
- [ ] Alle oude namen, mounting, werkende clips, recoil en ammo-/reload-flow behouden.
- [ ] Elk wapen op gehoor én tijdens schieten identificeerbaar, met afzonderlijke mechanische feedback.
- [ ] Thompson en MG42 merkbaar ander sustained-fire-gedrag; andere wapens blijven correct.
- [ ] Godot Test Zone op iPhone speelbaar, oude versus nieuwe weapon viewer 360°/animaties werkend.
- [ ] Bestaande damagewaarden, unlocks, upgrades, vijandelijke varianten en impact op voertuigen werken.
- [ ] Complete exportbron, licenties, meetbare rapporten en tests in **dezelfde Draft PR**.
- [ ] Geen onbedoelde publicatie naar `main` of `updates`.

> **Environment/status bij start (29 oktober 2026):** actuele `main` head `2a0cd3b5994860ec125f9e52c2ba36a59a3c60a9`. Op de hier beschikbare uitvoeromgeving zijn GitHub API-reads/writes beschikbaar, maar Blender en Godot niet. Er is nog geen nieuwe Blender-uitvoer, Game Test Zone of iPhone/Xogot-verificatie geproduceerd. Een Draft PR met deze specificatie is **niet** hetzelfde als de voltooide Weapon Upgrade 2.0.
