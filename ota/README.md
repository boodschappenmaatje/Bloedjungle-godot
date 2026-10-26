# Updates zonder nieuwe IPA (OTA)

`basis.txt` bevat de commit waar de patches van afgeleid worden (de "base"). Een IPA krijgt deze waarde bij het bouwen mee in
`build_info.json`; de app past alleen patches toe die dezelfde base hebben.

- Een patch bevat alle bestanden die sinds de base zijn gewijzigd of toegevoegd, dus hij groeit tot je een nieuwe IPA installeert.
- Nieuwe IPA geïnstalleerd en wil je weer kleine patches? Zet in `basis.txt` een recentere commit, bouw een nieuwe IPA (de workflow
  `ios.yml` zet de nieuwe base erin) en installeer die. Apps met een oudere base melden dan "installeer eerst de nieuwste IPA".
- `.github/workflows/ota.yml` bouwt de patch en zet `manifest.json` + `patch-<versie>.pck` in de GitHub-release `updates`.
