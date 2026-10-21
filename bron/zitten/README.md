# Zit-animatie (Blender-bron)

`assets/zitten.glb` komt uit `maak_zitten.py` (`pip install bpy`): het skelet van `assets/soldaat.glb` met alleen de lus "zitten" (60 frames, 30 fps). Het bovenlijf is de houding van "stil" (geweer in de handen), de benen zijn geknikt en het lijf deint wat mee met de rit.

    python3 maak_zitten.py uit/
    python3 render.py uit/zitten.blend uit/

De heup blijft op staande hoogte, dus de zitting ligt 0,85 m (mannetjesmaat) boven de oorsprong van het mannetje en de voeten 0,40 m. `scripts/soldier_model.gd` hangt de clip aan elk mannetje; de vrachtwagen zet de soldaten in de laadbak zo neer.
