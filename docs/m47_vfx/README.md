# M-47 Muurbreker VFX (Godot, realtime)

Keuzekaart Dennis (8 nov 2026): **1A 2B 3A 4B 5A 6A**.

- **1A** Effect in Godot, gamecamera, op het goedgekeurde model en de breukmuur uit PR #238/#240.
- **2B** Glow aan op alle grafiekstanden in het proefveld (`M47Proefveld.apply_glow`); de kwaliteitstrap van het spel kan hem nog uitzetten.
- **3A** Honingraat-schokgolf: `shaders/m47_honingraat.gdshader`, één vlak op de muur en één op de grond.
- **4B** Rook/stof (v2: dichter, blauw aangelicht spoor dat achterblijft): 4x4 flipbook-atlassen `assets/m47/rook_sliert.png` en `rook_stof.png`, gemaakt door `bron/m47/maak_rook.py`.
  De Blender/Mantaflow-simulatie bleek te traag en gaf een statische bol; daarom procedurele wolken (ruis + zijlicht). Geen echte simulatie.
- **5A** Breach-clip met 42 brokken (grotere stukken) plus 16 extra procedurele kantige betonbrokken die in een boog uit het gat vliegen en blijven liggen; blijvend gat, botsing weg na de breuk, blauwe nagloed.
- **6A** Proefveld: hoofdmenu > **M-47** (`scenes/m47_proefveld.tscn`): SCHIET, MUUR HERSTELLEN, TERUG, fps-teller.

Opnames (software-render, Vulkan/lavapipe, 1280x720): `1_laden_flits.jpg` .. `5_doorbraak.jpg`, `doel_nu_nieuw.jpg` (doelbeeld, Blender 5.2, nieuw).
Test: `godot --headless --path . -s tests/m47_vfx_test.gd --fixed-fps 60`.
Niet gemeten: fps op iPhone (NIET GETEST).
