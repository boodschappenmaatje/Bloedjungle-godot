# Actie-animaties (Blender-bron)

`assets/acties.glb` komt uit `maak_acties.py` (`pip install bpy`): het skelet van `assets/soldaat.glb` met drie animaties.

| Animatie | Duur | Gebruik |
|---|---|---|
| `rollen` | 0,5 s | ontwijkrol (`player.gd`): hurken, koprol met opgetrokken knieën, landing en opstaan |
| `sprinten` | 0,53 s (lus) | sprint (`player.gd`): voorovergebogen, grote stappen, geweer laag |
| `herladen` | 1,2 s | herladen: geweer zakt, linkerhand pakt een magazijn van het koppel, klikt hem erin, trekt het grendel, geweer omhoog |

Alle houdingen zijn opgebouwd op de bestaande houdingen van het mannetje (`stil` en `rennen`), zodat de stijl past. De rechterhand houdt het geweer in alle houdingen vast, want het wapen hangt in het spel aan die hand (`soldier_model.gd`). `herladen` vervangt de oude, trage herlaadlus uit `soldaat.glb`.

    python3 maak_acties.py uit/                              # maakt uit/acties.blend en uit/acties.glb
    python3 render.py uit/acties.blend rollen 0,2,4,6,8,10,12,14 uit/ zij   # contactblad met een voorbeeldgeweer

`scripts/soldier_model.gd` haalt de animaties uit dit bestand en hangt ze aan elk mannetje.
