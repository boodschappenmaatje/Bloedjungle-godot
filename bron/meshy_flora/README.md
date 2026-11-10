# Meshy-begroeiing (Graphics 2.0 stap C)

Dennis' Meshy-modellen (palm, jungleboom, varen, heliconia, twee mosrotsen, twee gevallen stammen) als spelmodellen.

1. **Meester maken** (6 tot 8 miljoen driehoeken naar 10.000 tot 50.000, texturen scherp houden):
   - heliconia, rotsen, stammen: `gltfpack -i in.glb -o uit.glb -si 0.01 -se 0.03 -noq` (geen `-sa`: de UV's blijven heel);
   - palm en varen: `stap1_verklein.py` (Blender, remove_doubles + stapsgewijs collapse);
   - boom: `gltfpack -sa` (Blender loopt vast op haar UV-randen en geeft een kegel). De bladeren van de boom blijven daardoor wat hoekig.
2. **Spelversie** met `stap2_spel.py <meesters> <uit>`: voet op de grond, echte maat, windgewicht in de alfa van de vertexkleur,
   nabij- en ver-model, texturen 2K/1K (planten) of 1K/512 (keien, stammen). Uitvoer wordt `assets/meshy_flora.glb`.
3. Meesters staan in `/mnt/project-files/godot/graphics2/meshy-meesters/` (niet in de repo, te groot).

Driehoeken in het spel: palm 5.000 / 1.800, boom 27.700 / 1.000, varen 2.500, heliconia 6.000, rots 2.500, stam 3.500.
