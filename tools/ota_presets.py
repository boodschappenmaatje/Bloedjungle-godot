#!/usr/bin/env python3
"""Voegt aan een export_presets.cfg twee presets toe voor de OTA-splitsing (zie ota/README.md):
  iOSlicht  = alles behalve de zware assets (scripts, scènes, kleine bestanden): klein, de app vervangt dit stuk bij elke update;
  iOSzwaar  = alleen de zware assets (modellen, texturen, geluid): een keten van stukken, elk stuk alleen wat er sinds het vorige veranderde.
Beide zijn afgeleid van preset "iOS", zodat de exportinstellingen gelijk blijven.
Gebruik: ota_presets.py <export_presets.cfg>"""
import re, sys
from pathlib import Path

ZWARE_EXT = ["glb", "gltf", "png", "jpg", "jpeg", "webp", "wav", "mp3", "ogg", "exr", "hdr", "tga", "blend"]
ZWARE_MAPPEN = ["source_assets", "previews"]  # ook 'zwaar': alles daarin
LICHT_IN_ASSETS = ["tres", "tscn", "res", "gd", "gdshader", "json", "cfg", "txt", "md", "ttf", "woff2", "otf", "svg"]  # blijft in het lichte stuk


def sectie(tekst, naam):
    """Zoekt preset <naam>: geeft (nummer, tekst van [preset.N] t/m en met [preset.N.options])."""
    for m in re.finditer(r"^\[preset\.(\d+)\]$", tekst, re.M):
        nr = m.group(1)
        eind = tekst.find("\n[preset.", m.end())
        blok = tekst[m.start():(eind if eind > 0 else len(tekst))]
        # het blok loopt tot de volgende [preset.N] (de options horen erbij)
        if re.search(r'^name="%s"$' % re.escape(naam), blok, re.M):
            volgende = re.search(r"^\[preset\.\d+\]$", tekst[m.end():], re.M)
            eind = m.end() + volgende.start() if volgende else len(tekst)
            return nr, tekst[m.start():eind]
    raise SystemExit("preset %s niet gevonden" % naam)


def hoogste(tekst):
    return max(int(n) for n in re.findall(r"^\[preset\.(\d+)\]", tekst, re.M))


def maak(tekst, bron_nr, bron, nieuw_nr, naam, exclude_extra, include_filter=None):
    s = bron.replace("[preset.%s]" % bron_nr, "[preset.%d]" % nieuw_nr).replace("[preset.%s.options]" % bron_nr, "[preset.%d.options]" % nieuw_nr)
    s = re.sub(r'^name="[^"]*"', 'name="%s"' % naam, s, count=1, flags=re.M)
    s = re.sub(r'^exclude_filter="([^"]*)"', lambda m: 'exclude_filter="%s"' % ",".join([x for x in [m.group(1), exclude_extra] if x]), s, count=1, flags=re.M)
    if include_filter is not None:
        s = re.sub(r'^include_filter="[^"]*"', 'include_filter="%s"' % include_filter, s, count=1, flags=re.M)
    return s


def main(pad):
    p = Path(pad)
    tekst = p.read_text()
    nr, ios = sectie(tekst, "iOS")
    n = hoogste(tekst)
    zwaar_patronen = ["assets/*.%s" % e for e in ZWARE_EXT] + ["%s/*" % d for d in ZWARE_MAPPEN]
    licht = maak(tekst, nr, ios, n + 1, "iOSlicht", ",".join(zwaar_patronen))
    # zwaar: alles uitsluiten wat niet in assets/, source_assets/ of previews/ staat, plus de lichte bestanden in assets/
    root = p.parent
    top = sorted(x.name for x in root.iterdir() if x.name not in (".git", ".godot", ".github", "assets", *ZWARE_MAPPEN))
    uit = []
    for t in top:
        uit.append(t if (root / t).is_file() else t + "/*")
    uit += ["assets/*.%s" % e for e in LICHT_IN_ASSETS]
    zwaar = maak(tekst, nr, ios, n + 2, "iOSzwaar", ",".join(uit), include_filter="")
    p.write_text(tekst.rstrip() + "\n\n" + licht.rstrip() + "\n\n" + zwaar.rstrip() + "\n")
    print("presets iOSlicht (%d) en iOSzwaar (%d) toegevoegd" % (n + 1, n + 2))


if __name__ == "__main__":
    main(sys.argv[1])
