# Bloedjungle Base Wall HQ 2.0 — original Meshy GLB transfer

This document is the stable handoff for the already-approved original WWII field-fortification wall. The original file was supplied by the user in ChatGPT, preserved without modification, and uploaded to the project's existing Google Drive transfer folder. **Do not replace it with a synthetic model.**

## Source

- **Name:** `Bloedjungle_Base_Wall_HQ2_Meshy_Original_b6cfee.glb`
- **Drive URL (anyone with link can read):** https://drive.google.com/file/d/12UWcvrG47u6isGydTt75_-gUZSpMKbyI/view?usp=drivesdk
- **Drive file ID:** `12UWcvrG47u6isGydTt75_-gUZSpMKbyI`
- **Drive folder:** `Bloedjungle_HQ2_Transfer`
- **Original source suffix:** `_Meshy_AI_2026-11-04_b6cfee.glb`
- **Verified size:** `15535848` bytes
- **SHA-256:** `19df1f487dc1b98f4890354340b9e4dc93aad2baa21ec900ea1fe4f46d4e9d0e`
- **Media type:** `model/gltf-binary`

## Download from a Codex workspace (no chat attachment needed)

Use a dedicated local source folder ignored from exported game resources, for example `source_assets/base_wall_hq2/`. A Google Drive direct-link handler like `gdown` works more reliably than treating a Drive HTML preview as the GLB.

```bash
mkdir -p source_assets/base_wall_hq2
python3 -m pip install --user gdown
python3 -m gdown --id 12UWcvrG47u6isGydTt75_-gUZSpMKbyI -O source_assets/base_wall_hq2/Bloedjungle_Base_Wall_HQ2_Meshy_Original_b6cfee.glb
python3 - <<'PY'
from pathlib import Path
import hashlib
p=Path("source_assets/base_wall_hq2/Bloedjungle_Base_Wall_HQ2_Meshy_Original_b6cfee.glb")
assert p.stat().st_size == 15535848, "Incorrect file size; do not continue"
assert p.read_bytes()[:4] == b"glTF", "Download is not a GLB"
assert hashlib.sha256(p.read_bytes()).hexdigest() == "19df1f487dc1b98f4890354340b9e4dc93aad2baa21ec900ea1fe4f46d4e9d0e", "SHA mismatch"
print("MESHY ORIGINAL GLB VERIFIED")
PY
```

If the Codex environment does not have `pip` or `gdown`, download the same Drive file through a browser or connected Drive app and verify the size and hash. **Never work from an HTML error page or an unverified placeholder.** Retain the original in source storage outside the exported OTA runtime.

## Work continuation

This branch is `feature/base-wall-hq-2-0-meshy`, originally based on main `e8a48d2d925b6ce74e351f95e1194ba3f4aa048a`. Continue the user's full Base Wall HQ 2.0 plan without asking for a new GLB upload:

- Rework the original Meshy segment into exactly 3.5 m length, 3.0 m height and 0.4 m depth, optimizing/baking/LOD for iPhone.
- Replace only the own-base wall along the existing `Data.COMPOUND` perimeter with seamless modules; keep the north/south gates, towers, bunker, routes and all other buildings.
- Correct colliders, projectile masks (including `Bullet.fire(... over_wall=true)`), line-of-sight and explosion blocking as required; retain appropriate gameplay exceptions and validate them.
- Preserve original visual quality and source provenance.
- Test with Godot 4.7.2 and iOS/OTA CI. Only merge and publish OTA after passing complete regression and release verification.

**The unoptimized source is a provenance file, not a game-export asset.** Do not commit the giant source GLB to the runtime assets path; commit only approved optimized deliverables.
