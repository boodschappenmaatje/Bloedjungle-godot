# NVIDIA MotionBricks-bewegingen voor de VQ2-soldaat (v244)

`assets/nv_bewegingen.glb` bevat zes extra clips voor het 53-botten DEF-skelet van `soldaat_vq2.glb` en
`soldaat_jungle_commando.glb`. Ze zijn gemaakt met NVIDIA **MotionBricks** (SIGGRAPH 2026,
github.com/NVlabs/motionbricks): een AI-model dat beweging invult tussen vier contexthoudingen en één tot vier
doelhoudingen. In het spel zijn het gewone clips; het model zelf gaat niet mee in de app (geen fps-kosten).

| Clip | Frames (30 fps) | Lus | Snelheid bij speed 1 | Gebruik in Godot |
|---|---|---|---|---|
| `zij_links` | 45 | ja | 2,85 m/s | `SoldierModel.play_nv_move`, looprichting 55-105 graden links van het gezicht |
| `zij_rechts` | 45 | ja | 2,85 m/s | idem rechts (gespiegeld uit `zij_links`, romp in de richthouding) |
| `terug` | 45 | ja | 2,33 m/s | achteruit lopen (meer dan 105 graden van het gezicht) |
| `draai_links` / `draai_rechts` | 50 | nee | op de plek | stilstaan en snel draaien (> 2,2 rad/s): stapjes zetten |
| `stoppen` | 38 | nee | 2,4 m/s -> 0 | van `lopen`/`rennen` naar `stil` |

Resterende hoeken worden met de bestaande beendraaiing (`SoldierPose.leg_yaw`) bijgewerkt. Instelling
**Bewegingen** (menu Soldaten, `nv_anim`) = Oud zet alles terug naar de oude manier.

## Licentie

- MotionBricks-code: Apache-2.0. Model (ONNX): NVIDIA Open Model Agreement, commercieel gebruik toegestaan.
- **Niet gebruikt:** de voorbeeldbewegingen in `assets/motions` van MotionBricks (Bones-BVH's, NVIDIA Sample Data
  *Evaluation* License, alleen voor intern testen). Alle context- en doelhoudingen hier komen uit onze eigen clips
  (`stil` en `lopen` van `soldaat_vq2.glb`).

## Opnieuw maken

`bouw_glb.py` maakt de GLB uit `clips.npz` en heeft het NVIDIA-model niet nodig:

    python3 -I bron/soldaat_vq2/nvidia/bouw_glb.py              # -> assets/nv_bewegingen.glb
    python3 -I bron/soldaat_vq2/nvidia/bouw_glb.py /tmp/v.glb   # ook een volledige soldaat met de clips (viewer/controle)

De clips zelf opnieuw genereren (CPU volstaat, geen NVIDIA-videokaart nodig; ca. 1 minuut):

    git clone --depth 1 https://github.com/NVlabs/motionbricks /pad/motionbricks
    # Git LFS werkt in sommige omgevingen niet; haal dan deze twee bestanden via media.githubusercontent.com:
    #   motionbricks/assets/onnx/soma/mmm_v6_soma_fp32.onnx (758 MB)
    #   motionbricks/assets/human/soma_base_skel_minimal_no_root.usd
    python3 -m venv venv && . venv/bin/activate
    pip install numpy==2.4.3 warp-lang scipy usd-core onnxruntime
    cd bron/soldaat_vq2/nvidia
    PYTHONPATH=/pad/motionbricks:. python maak_clips.py   # ruwe beweging -> ruw.pkl (niet in git)
    PYTHONPATH=/pad/motionbricks:. python lussen.py       # lussen knippen, op de plek, naad -> clips.npz
    python bouw_glb.py

- `cpu_shim.py`: vervangt TensorRT door ONNX Runtime en zet Warp op de CPU (MotionBricks vraagt anders een
  NVIDIA-GPU).
- `retarget.py`: omzetten tussen SOMA (NVIDIA, 77 gewrichten) en ons DEF-skelet. Beide Y omhoog, gezicht +Z,
  links +X, T-houding; per bot een wereldrotatie-delta t.o.v. de rusthouding plus uitlijning van de botrichting.
- `maak_clips.py`: vanuit `stil` lang doorlopen (opzij, achteruit) met bewegende doelhoudingen, draaien 90 graden,
  en afremmen vanuit onze `lopen`-cyclus. De generatie is deterministisch.
- `lussen.py`: zoekt in het rustige middendeel twee gelijke houdingen (lus), haalt de heupverplaatsing eruit
  (clips op de plek, het spel beweegt het lichaam), maakt de naad glad en zet de armen in de `stil`-geweerhouding
  (het spel legt de handen met IK op het wapen). `zij_rechts` sprong bij generatie steeds over de kop; daarom is
  hij gespiegeld uit `zij_links` met het bekken half meegedraaid en de romp in de richthouding.

## Tests en opnames

- `tests/nv_bewegingen_test.gd` (headless): clips aanwezig en zichtbaar bewegend, juiste keuze per richting,
  afremmen, stapjes bij draaien, instelling Oud.
- `tests/nv_bewegingen_foto.gd` (xvfb + opengl3): voor/na met dezelfde camera en belichting (opzij, draaien,
  afremmen).
- Viewer `tools/blender-vq2-viewer/` model Soldaat toont alle 23 clips (`node test-soldaat.mjs`).
- Native iPhone-fps: NIET GETEST. Kosten in het spel: zes extra clips (GLB 325 kB), geen extra rekenwerk.
