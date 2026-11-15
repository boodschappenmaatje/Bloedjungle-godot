"""Importstraat, laatste stap: na Dennis' "mooi" gaat een model de bibliotheek in.

    python3 tools/importstraat/keur_goed.py <uitmap van straat.py> [--naam andere_naam]

Kopieert <naam>.glb + texturen naar assets/bibliotheek/<type>/<naam>/ en zet een regel in assets/bibliotheek/bibliotheek.json
(type, maat in meters, driehoeken, texturen, botsing, delen, bron, datum). De bibliotheek is de lijst waaruit later de
tekenmodus van de AI builder tool kiest. Zonder Dennis' goedkeuring dit script niet draaien.
"""
import json, os, shutil, sys, datetime

ARGS = sys.argv[1:]
SRC = os.path.abspath(ARGS[0])
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
st = json.load(open(os.path.join(SRC, "stats.json")))
naam = ARGS[ARGS.index("--naam") + 1] if "--naam" in ARGS else st["naam"]
dst = os.path.join(ROOT, "assets", "bibliotheek", st["type"], naam)
os.makedirs(dst, exist_ok=True)
shutil.copy2(os.path.join(SRC, st["naam"] + ".glb"), os.path.join(dst, naam + ".glb"))
rap = {}
if os.path.exists(os.path.join(SRC, "rapport.json")):
    rap = json.load(open(os.path.join(SRC, "rapport.json")))
lib_path = os.path.join(ROOT, "assets", "bibliotheek", "bibliotheek.json")
lib = json.load(open(lib_path)) if os.path.exists(lib_path) else {"versie": 1, "modellen": []}
lib["modellen"] = [m for m in lib["modellen"] if m["naam"] != naam]
lib["modellen"].append(dict(
    naam=naam, type=st["type"], pad=f"res://assets/bibliotheek/{st['type']}/{naam}/{naam}.glb",
    maat_m=st["afmeting_m"], driehoeken=st["na"]["tris"], texturen=st["na"]["texturen"],
    botsing=st["extra"].get("botsing"), delen=st["extra"].get("delen", []), wind=st["extra"].get("wind"),
    bron=st["bron"], bron_driehoeken=st["voor"]["tris"], fps_schatting=rap.get("fps_schatting", {}).get("na"),
    goedgekeurd=datetime.date.today().isoformat()))
lib["modellen"].sort(key=lambda m: (m["type"], m["naam"]))
json.dump(lib, open(lib_path, "w"), indent=1, ensure_ascii=False)
print("in de bibliotheek:", os.path.relpath(dst, ROOT), "-", len(lib["modellen"]), "modellen")
