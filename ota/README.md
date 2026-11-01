# Updates zonder nieuwe IPA (OTA)

`basis.txt` bevat de commit waar de IPA van gebouwd is (de "base"). Een IPA krijgt deze waarde bij het bouwen mee in
`build_info.json`; de app past alleen patches toe die dezelfde base hebben.

- **Keten:** elke patch bevat alleen wat er sinds de VORIGE patch is veranderd (de eerste vergelijkt met de IPA-commit). In het manifest
  (`schema` 2) staat de hele keten sinds de IPA onder `patches`; de app downloadt alleen de patches die hij nog niet heeft en laadt ze
  in volgorde. Een gelukte deelpatch wordt bij een nieuwe poging niet opnieuw gedownload.
- **Een nieuwe installatie** (of een toestel zonder patches) haalt de hele keten op. Wordt de keten te groot (> 400 MB, de workflow geeft
  een waarschuwing), installeer dan een nieuwe IPA: zet in `basis.txt` een recentere commit, bouw een IPA (`ios.yml` zet de base erin)
  en installeer die. Apps met een oudere base melden dan "installeer eerst de nieuwste IPA".
- `.github/workflows/ota.yml` bouwt de patch en zet `manifest.json` + de patches van de keten in de GitHub-release `updates`;
  patches die niet meer in de keten staan worden verwijderd.
