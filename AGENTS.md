# AGENTS.md — Bloedjungle (ChatGPT Codex)

## Verplichte projectafspraak voor alle 3D-assets

**BLOEDJUNGLE HIGH QUALITY SHOWCASE is de standaard**, met VQ2 als minimale kwaliteitsreferentie. Dit geldt ook bij korte opdrachten zoals “maak een gebouw” of “vervang de bunker”. De volledige regels staan in het canonieke document hieronder.

Voor het maken, aanpassen, verbeteren, exporteren of animeren van 3D-modellen, en voor de modelviewer, lees eerst:
1. **[docs/ASSET_QUALITY_STANDARD.md](docs/ASSET_QUALITY_STANDARD.md)** — **canonieke, projectbrede** ontwerp-, overleg-, productie-, kwaliteits- en acceptatieregels.
2. [docs/vq2/README.md](docs/vq2/README.md) — daadwerkelijk gerealiseerde kwaliteitsreferenties: kazerne, wachttoren en legerjeep.
3. Relevante `bron/<model>/README.md`, bestaande Blender-generator, Godot-scène en spelcode.

### Gedrag
- **Nieuwe assets:** eerst beknopt overleg met gebruiker over uiterlijk, functies, bewegende onderdelen, benodigde Blender-clips en Godot-gedrag; leg de specificatie vast; **geen definitieve productie vóór expliciete ontwerpgoedkeuring**.
- **Bestaande assets vervangen:** korte opdracht volstaat; inspecteer bestaande code en behoud gameplayfuncties, animaties, ingangen, colliders, slooplogica en interacties. Maak tests en Draft PR zonder overbodige nieuwe vragen.
- Gebruik indien beschikbaar de lokale **Bloedjungle 3D Production Pipeline 1.0 High Quality Showcase** op de iMac voor een HQ-bronmodel en aparte geoptimaliseerde Godot-gameversie; beweer niet dat lokaal is uitgevoerd als die toegang ontbreekt.
- Produceer daadwerkelijk herhaalbare Blender `.blend`/`.py`, echte `.glb` en PBR-kaarten; geen prompt/renders in plaats van assets.
- Lever naast `.blend` en Godot-`.glb` bij ieder model een `.usdz`-iPhonepreview voor de Bestanden-app/Quick Look; gebruik de iCloud Drive-map `Bloedjungle Previews` wanneer die beschikbaar is. Volg de canonieke werkwijze in `docs/ASSET_QUALITY_STANDARD.md`.
- Zorg voor realistische militaire jungle-stijl, top-down leesbaarheid, hoogwaardige PBR en beheersbare iPhone/Xogot-prestaties.
- **Behoud de bestaande scenehiërarchie, rigs, animaties, colliders en gameplay**; statische legerjeep is niet de speelbare jeep.
- Neem elk nieuw/gewijzigd model op in `tools/blender-vq2-viewer/`; 360° draaien en zoom, voor/na bij upgrades, **echte** geanimeerde clips afspelen als aanwezig. Toon anders eerlijk dat er geen clips zijn.
- Bewijs kwaliteit via echte Blender- en Godot-gamecamera-renders, import- en regressietests; claim geen fysieke iPhone-test zonder meting.
- Werk op een featurebranch + Draft PR; **geen merge naar `main` en geen publicatie naar gedeelde `updates`-OTA zonder afzonderlijke uitdrukkelijke gebruikersgoedkeuring**.
- Eén bron van waarheid: **wijzig de canonieke standaard**, niet enkel dit korte Codex-bestand. Dezelfde regels gelden voor Claude Code via `CLAUDE.md`.

Voor andere, niet-3D-gerelateerde taken blijven de normale projectinstructies gelden.

## Primaire game-testomgeving (vaste gebruikersafspraak, 30 oktober 2026)
- **Test Bloedjungle primair op de native iPhone-app via de bestaande OTA-updateprocedure.** De gebruiker geeft expliciete toestemming per gewenste merge/publicatie; merge of OTA nooit stilzwijgend voor andere wijzigingen.
- **Xogot haalt op de iPhone te lage FPS** en is daarom geen betrouwbare maatstaf voor native prestaties. Gebruik Xogot hooguit voor snelle import-/editorproeven en noem Xogot-FPS nooit gelijk aan native-app-FPS.
- Voor beeldsnelheid, touchgedrag, camera en grote gevechten is de **native iPhone-app** de doorslaggevende acceptatietest. Meld "NIET GETEST" wanneer geen echte native meting beschikbaar is. Indien expliciet om OTA-test wordt gevraagd: controleer de bestaande `.github/workflows/ota.yml`, publiceer alleen na toestemming en verifieer de release-workflow.
