# Wachttoren (Blender-bron)

`assets/wachttoren.glb` komt uit de bestaande `maak_wachttoren.py`, uitgebreid met VQ2 PBR, echte golfplaatgeometrie en verbindingen. Gebruik de lokale Blender-installatie vanaf de repositoryroot:

    python3 tools/build_vq2.py --only wachttoren
    blender -b -t 4 --python tools/render_vq2.py -- wachttoren

Platform op 5,3 m, klimladder aan de +X zijde, dakdelen heten Toren_dak en Toren_dakrib (de game verbergt ze als je op het platform staat). Klimlogica staat in scripts/player.gd.

De bewerkbare `.blend` en bronexport staan in `uit/`, de definitieve runtime-export in `assets/`. De speler-, collider- en klimcode zijn behouden. Zie `docs/vq2/README.md`.
