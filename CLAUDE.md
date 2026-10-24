# CLAUDE.md — Bloedjungle (Claude Code)

## Permanente standaard: BLOEDJUNGLE 3D ASSET STANDARD VQ2

**Dit is een verplicht projectcontract.** Voor **elke** taak waarbij je een Blender-model, gebouw, voertuig, decoratie, character, animatie of 3D-viewer aanmaakt of wijzigt, moet je eerst het **canonieke** document [docs/ASSET_QUALITY_STANDARD.md](docs/ASSET_QUALITY_STANDARD.md) lezen en de kwaliteits- en acceptatiecriteria uitvoeren, ook als de gebruiker de standaard niet expliciet noemt.

Lees vervolgens [docs/vq2/README.md](docs/vq2/README.md) en de relevante `bron/<asset>/`-generator/README, `assets/*.glb` en betrokken Godot-scènes/scripts. De bestaande **VQ2-kazerne, wachttoren en legerjeep** zijn de geaccepteerde visuele/productietechnische referentie. Dit project is 3D top-down, realistische militaire jungle, met Windows 11 en iPhone/Xogot als doelen.

### Verplicht uitvoeren
1. Bouw **werkelijke** Blender-assets met geloofwaardige vormen, top-down leesbaarheid, hoogwaardige PBR-brontexturen, correcte normals/UV's en gecontroleerde slijtage. Lever bewerkbare `.blend`, reproduceerbare Blender-Python-code en importeerbare `.glb` op. Gebruik voor zware taken waar mogelijk gratis headless Blender of GitHub Actions; geen betaalde provider zonder toestemming.
2. Behoud bestaande Godot-functies, assetpaden, pivots, collision, deuren, dak/klim-/slooplogica, rigs en animatiecontracten. De **statische** `legerjeep.glb` is niet `jeep.glb` met bestuurbare gameplay.
3. Voeg alle nieuwe/gewijzigde 3D-modellen toe aan de **bestaande** `tools/blender-vq2-viewer/` met 360°/zoom, gamecamera, oud/nieuw waar relevant en **zichtbaar werkende animatiebediening** voor echte GLB-clips. Voor scriptgestuurde animaties ook een Godot-demonstratie. Geen nepclips.
4. Test echte GLB-uitvoer, Godot-import en regressies; maak voor/na-opnames met identieke camera en belichting; rapporteer triangle/material/texture en performance. Noem niet-uitgevoerde iPhone/Safari/Xogot-metingen expliciet.
5. Gebruik een **aparte branch + Draft PR** bij game-/modelwijzigingen. **Niet naar main mergen** zonder expliciete gebruikersgoedkeuring.

**Voorkom stijlversplintering:** `docs/ASSET_QUALITY_STANDARD.md` is de enige inhoudelijke standaard, ook voor ChatGPT Codex via `AGENTS.md`. Wijzig deze canonieke standaard als de gebruiker een nieuwe versie goedkeurt; schrijf geen zelfstandige tegenstrijdige Claude-stijlregels.

Voor niet-3D-taken zijn deze regels niet onnodig van toepassing.
