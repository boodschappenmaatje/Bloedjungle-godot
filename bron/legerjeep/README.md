# Legerjeep (Blender-bron)

`assets/legerjeep.glb` is een originele, in Blender gemaakte open militaire terreinwagen. De bewerkbare onderdelen staan in `jeep.blend`; `preview.png` laat het resultaat zien. Het model heeft terreinbanden met profiel, een reservewiel, voorruit, stoelen, dashboard, verlichting, een jerrycan en een schep.

`scenes/legerjeep.tscn` is een kant-en-klare Godot-scène met een eenvoudige botsingsvorm. De voorkant wijst naar -Z. Afmetingen inclusief reservewiel: ongeveer 1,86 × 3,92 × 1,82 meter. De GLB bevat één mesh, 15 materiaalvlakken en ongeveer 75.600 driehoeken. Gebruik het model bij voorkeur als opvallend voertuig en plaats niet veel exemplaren tegelijk op een mobiele telefoon.

Opnieuw bouwen met Blender 4.3 of nieuwer:

```bash
blender -b -t 4 --python maak_jeep.py
cp jeep.glb ../../assets/legerjeep.glb
```

Het script maakt `jeep.glb`, `jeep.blend` en `preview.png` in deze map opnieuw aan. De geometrie en materialen zijn procedureel opgebouwd; er zijn geen externe bronmodellen of afbeeldingen gebruikt.
