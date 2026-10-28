# CLAUDE.md — Bloedjungle (Claude Code)

## Permanente standaard: BLOEDJUNGLE HIGH QUALITY SHOWCASE (VQ2 als ondergrens)

**Dit is een verplicht projectcontract.** Voor **elke** 3D-model-/animatie-/viewer-taak geldt de canonieke [docs/ASSET_QUALITY_STANDARD.md](docs/ASSET_QUALITY_STANDARD.md), inclusief de High Quality Showcase-productie, interactieve ontwerpgoedkeuring en de bestaande VQ2-ondergrens. De gebruiker hoeft die standaard niet in zijn korte verzoek te herhalen.

Lees vervolgens [docs/vq2/README.md](docs/vq2/README.md) en de relevante `bron/<asset>/`-generator/README, `assets/*.glb` en betrokken Godot-scènes/scripts. De bestaande **VQ2-kazerne, wachttoren en legerjeep** zijn de geaccepteerde visuele/productietechnische referentie. Dit project is 3D top-down, realistische militaire jungle, met Windows 11 en iPhone/Xogot als doelen.

### Verplicht uitvoeren
0. **Nieuw model:** overleg eerst met de gebruiker over uiterlijk, gamefuncties, animaties (werkelijke Blender-clips versus Godot-gestuurd), effecten en prestatiebudget; leg de Asset Design Specification vast; begin geen definitieve productie vóór expliciete goedkeuring. **Bestaand model vervangen:** voer de korte opdracht uit op basis van bestaande code, behoud alle gameplaycontracten, stel geen vragen over al bekende informatie.
0. **Productieketen:** gebruik waar beschikbaar de lokale Bloedjungle 3D Production Pipeline 1.0 — High Quality Showcase op de gekoppelde iMac voor apart HQ-bronmodel en geoptimaliseerde Godot-gameversie. Meld ontbrekende lokale toegang en verzin geen render- of fysieke iPhone-testresultaten.
1. Bouw **werkelijke** Blender-assets met geloofwaardige vormen, top-down leesbaarheid, hoogwaardige PBR-brontexturen, correcte normals/UV's en gecontroleerde slijtage. Lever bewerkbare `.blend`, reproduceerbare Blender-Python-code en importeerbare `.glb` op. Gebruik voor zware taken waar mogelijk gratis headless Blender of GitHub Actions; geen betaalde provider zonder toestemming.
2. Behoud bestaande Godot-functies, assetpaden, pivots, collision, deuren, dak/klim-/slooplogica, rigs en animatiecontracten. De **statische** `legerjeep.glb` is niet `jeep.glb` met bestuurbare gameplay.
3. Voeg alle nieuwe/gewijzigde 3D-modellen toe aan de **bestaande** `tools/blender-vq2-viewer/` met 360°/zoom, gamecamera, oud/nieuw waar relevant en **zichtbaar werkende animatiebediening** voor echte GLB-clips. Voor scriptgestuurde animaties ook een Godot-demonstratie. Geen nepclips.
4. Test echte GLB-uitvoer, Godot-import en regressies; maak voor/na-opnames met identieke camera en belichting; rapporteer triangle/material/texture en performance. Noem niet-uitgevoerde iPhone/Safari/Xogot-metingen expliciet.
5. Lever bij elk model ook een **`.usdz`-iPhone-preview** (materialen, animaties waar mogelijk) met downloadlinks, naast `.blend` en Godot-`.glb`; zie de standaard, sectie "iPhone-preview als .usdz".
6. Gebruik een **aparte branch + Draft PR** bij game-/modelwijzigingen. **Niet naar main mergen of naar de gedeelde `updates`-OTA publiceren** zonder afzonderlijke expliciete gebruikersgoedkeuring.

**Voorkom stijlversplintering:** `docs/ASSET_QUALITY_STANDARD.md` is de enige inhoudelijke standaard, ook voor ChatGPT Codex via `AGENTS.md`. Wijzig deze canonieke standaard als de gebruiker een nieuwe versie goedkeurt; schrijf geen zelfstandige tegenstrijdige Claude-stijlregels.

Voor niet-3D-taken zijn deze regels niet onnodig van toepassing.
