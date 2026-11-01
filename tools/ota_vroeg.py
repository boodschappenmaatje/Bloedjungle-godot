#!/usr/bin/env python3
"""Welke bestanden laadt Godot al VOORDAT de vervolgstukken van de OTA-keten geladen worden (scripts/ota_keten.gd)?
Dat zijn de autoload-scripts (updater.gd, game.gd, sfx.gd) en alles wat die bij het compileren ophalen: klassen uit class_name en
preload("res://...")-bestanden, recursief. Zo'n bestand kan niet via een vervolgstuk veranderen.
Gebruik: ota_vroeg.py <oude-commit> [nieuwe-commit]   -> exit 3 en een lijst als een van die bestanden is gewijzigd, anders exit 0.
         --alleen-assets: kijk alleen naar de zware assets (assets/, source_assets/, previews/) in die lijst.
         ota_vroeg.py --lijst                         -> print de bestanden."""
import re, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
START = ["scripts/updater.gd", "scripts/game.gd", "scripts/sfx.gd", "scripts/ota_keten.gd"]
EXTRA = ["project.godot"]


def klassen():
    res = {}
    for p in (ROOT / "scripts").rglob("*.gd"):
        m = re.search(r"^class_name\s+(\w+)", p.read_text(encoding="utf-8", errors="ignore"), re.M)
        if m:
            res[m.group(1)] = str(p.relative_to(ROOT))
    return res


def vroeg():
    kl = klassen()
    namen = re.compile(r"\b(" + "|".join(map(re.escape, kl)) + r")\b") if kl else None
    gezien, todo = set(), list(START)
    while todo:
        f = todo.pop()
        if f in gezien or not (ROOT / f).exists():
            continue
        gezien.add(f)
        if not f.endswith(".gd"):
            continue
        tekst = (ROOT / f).read_text(encoding="utf-8", errors="ignore")
        for m in re.finditer(r'preload\(\s*"res://([^"]+)"', tekst):
            todo.append(m.group(1))
        for m in re.finditer(r'extends\s+"res://([^"]+)"', tekst):
            todo.append(m.group(1))
        if namen:
            for m in namen.finditer(tekst):
                todo.append(kl[m.group(1)])
    return sorted(gezien | set(EXTRA))


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "--lijst":
        print("\n".join(vroeg()))
        sys.exit(0)
    alleen_assets = "--alleen-assets" in sys.argv
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    oud = args[0]
    nieuw = args[1] if len(args) > 1 else "HEAD"
    gewijzigd = set(subprocess.run(["git", "diff", "--name-only", oud, nieuw], cwd=ROOT, capture_output=True, text=True, check=True).stdout.split())
    kandidaten = set(vroeg())
    if alleen_assets:
        kandidaten = {f for f in kandidaten if f.startswith(("assets/", "source_assets/", "previews/"))}
    geraakt = sorted(kandidaten & gewijzigd)
    if geraakt:
        print("\n".join(geraakt))
        sys.exit(3)
