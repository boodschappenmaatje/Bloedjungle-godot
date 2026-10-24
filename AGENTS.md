# AGENTS.md — Bloedjungle (ChatGPT Codex)

## Verplichte projectafspraak voor alle 3D-assets

**BLOEDJUNGLE 3D ASSET STANDARD VQ2 is de standaard**, ook wanneer de gebruiker alleen “maak een gebouw”, “maak een voertuig” of “maak een 3D-model” vraagt.

Voor het maken, aanpassen, verbeteren, exporteren of animeren van 3D-modellen, en voor de modelviewer, lees eerst:
1. **[docs/ASSET_QUALITY_STANDARD.md](docs/ASSET_QUALITY_STANDARD.md)** — **canonieke, projectbrede** kwaliteits- en acceptatieregels.
2. [docs/vq2/README.md](docs/vq2/README.md) — daadwerkelijk gerealiseerde kwaliteitsreferenties: kazerne, wachttoren en legerjeep.
3. Relevante `bron/<model>/README.md`, bestaande Blender-generator, Godot-scène en spelcode.

### Gedrag
- Produceer daadwerkelijk herhaalbare Blender `.blend`/`.py`, echte `.glb` en PBR-kaarten; geen prompt/renders in plaats van assets.
- Zorg voor realistische militaire jungle-stijl, top-down leesbaarheid, hoogwaardige PBR en beheersbare iPhone/Xogot-prestaties.
- **Behoud de bestaande scenehiërarchie, rigs, animaties, colliders en gameplay**; statische legerjeep is niet de speelbare jeep.
- Neem elk nieuw/gewijzigd model op in `tools/blender-vq2-viewer/`; 360° draaien en zoom, voor/na bij upgrades, **echte** geanimeerde clips afspelen als aanwezig. Toon anders eerlijk dat er geen clips zijn.
- Bewijs kwaliteit via echte Blender- en Godot-gamecamera-renders, import- en regressietests; claim geen fysieke iPhone-test zonder meting.
- Werk op een featurebranch + Draft PR; **geen merge naar `main` zonder uitdrukkelijke gebruikersgoedkeuring**.
- Eén bron van waarheid: **wijzig de canonieke standaard**, niet enkel dit korte Codex-bestand. Dezelfde regels gelden voor Claude Code via `CLAUDE.md`.

Voor andere, niet-3D-gerelateerde taken blijven de normale projectinstructies gelden.
