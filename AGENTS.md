# AGENTS.md — Bloedjungle (ChatGPT Codex)

## Verplichte projectafspraak voor alle 3D-assets

**BLOEDJUNGLE HIGH QUALITY SHOWCASE is de standaard**, met VQ2 als minimale kwaliteitsreferentie. Dit geldt ook bij korte opdrachten zoals “maak een gebouw” of “vervang de bunker”. De volledige regels staan in het canonieke document hieronder.

Voor het maken, aanpassen, verbeteren, exporteren of animeren van 3D-modellen, en voor de modelviewer, lees eerst:
1. **[docs/ASSET_QUALITY_STANDARD.md](docs/ASSET_QUALITY_STANDARD.md)** — **canonieke, projectbrede** ontwerp-, overleg-, productie-, kwaliteits- en acceptatieregels.
2. [docs/vq2/README.md](docs/vq2/README.md) — daadwerkelijk gerealiseerde kwaliteitsreferenties: kazerne, wachttoren en legerjeep.
3. Relevante `bron/<model>/README.md`, bestaande Blender-generator, Godot-scène en spelcode.

### Gedrag
- **VERPLICHTE ONTWERPSTOP:** bij **elk nieuw model én ingrijpend visueel herontwerp** (bijvoorbeeld de bestaande speler veranderen in een Rambo-achtige militair) mag je vóór expliciete goedkeuring alleen bestaande bestanden onderzoeken en een ontwerp met keuzes voor uiterlijk, kleding, Poly Haven-materialen, gameplay en animaties voorstellen. **Niet modelleren, texturen baken/downloaden of game-assets aanpassen vóór de gebruiker ná de specificatie zegt: ‘Ontwerp goedgekeurd, bouwen’.** Alleen een reeds goedgekeurd model technisch in de game vervangen is uitgezonderd. Zie de canonieke paragraaf ‘Verplichte ONTWERPSTOP’.
- **Bestaande assets vervangen:** korte opdracht volstaat; inspecteer bestaande code en behoud gameplayfuncties, animaties, ingangen, colliders, slooplogica en interacties. Maak tests en Draft PR zonder overbodige nieuwe vragen.
- Gebruik indien beschikbaar de lokale **Bloedjungle 3D Production Pipeline 1.0 High Quality Showcase** op de iMac voor een HQ-bronmodel en aparte geoptimaliseerde Godot-gameversie; beweer niet dat lokaal is uitgevoerd als die toegang ontbreekt.
- Produceer daadwerkelijk herhaalbare Blender `.blend`/`.py`, echte `.glb` en PBR-kaarten; geen prompt/renders in plaats van assets.
- Zorg voor realistische militaire jungle-stijl, top-down leesbaarheid, hoogwaardige PBR en beheersbare iPhone/Xogot-prestaties.
- **Behoud de bestaande scenehiërarchie, rigs, animaties, colliders en gameplay**; statische legerjeep is niet de speelbare jeep.
- Neem elk nieuw/gewijzigd model op in `tools/blender-vq2-viewer/`; 360° draaien en zoom, voor/na bij upgrades, **echte** geanimeerde clips afspelen als aanwezig. Toon anders eerlijk dat er geen clips zijn.
- Bewijs kwaliteit via echte Blender- en Godot-gamecamera-renders, import- en regressietests; claim geen fysieke iPhone-test zonder meting.
- Werk op een featurebranch + Draft PR; **geen merge naar `main` en geen publicatie naar gedeelde `updates`-OTA zonder afzonderlijke uitdrukkelijke gebruikersgoedkeuring**.
- Eén bron van waarheid: **wijzig de canonieke standaard**, niet enkel dit korte Codex-bestand. Dezelfde regels gelden voor Claude Code via `CLAUDE.md`.

Voor andere, niet-3D-gerelateerde taken blijven de normale projectinstructies gelden.
