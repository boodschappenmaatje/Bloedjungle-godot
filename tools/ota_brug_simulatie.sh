#!/usr/bin/env bash
# Bootst de app na met alleen de BRUG: een IPA-basis met het kleine updatescherm (brug.pck) als actieve patch, en controleert dat dat scherm
# laadt en zich opbouwt. Zo kan een update nooit meer een brug publiceren waarmee je niet meer in het updatemenu komt.
# Gebruik: tools/ota_brug_simulatie.sh <godot> <ios-basis.pck> <brug.pck>
# Omgeving: OTA_BASE (commit van de IPA, verplicht), OTA_WERKMAP (standaard een tijdelijke map), OTA_PROJECTNAAM (standaard: uit project.godot).
# Exit 0 = goed, 1 = de brug zou het updatemenu breken (niets publiceren).
set -euo pipefail
GODOT="$(readlink -f "$1")"; BASIS="$2"; BRUG="$3"
: "${OTA_BASE:?OTA_BASE (commit van de IPA) ontbreekt}"
HIER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAAM="${OTA_PROJECTNAAM:-$(sed -n 's/^config\/name="\(.*\)"/\1/p' "$HIER/project.godot" | head -1)}"
WERK="${OTA_WERKMAP:-$(mktemp -d)}"
DATA="$WERK/xdg/godot/app_userdata/$NAAM/ota"
rm -rf "$WERK/xdg"; mkdir -p "$DATA"
cp "$BRUG" "$DATA/brug.pck"
# precies wat de oude updater uit de IPA bijhoudt na "Download en installeer" van de brug: een actieve patch met hash en grootte
python3 -I - "$DATA" "$OTA_BASE" <<'PY'
import hashlib, json, os, sys
d, base = sys.argv[1:3]
h = hashlib.sha256()
with open(d + '/brug.pck', 'rb') as f:
    for blok in iter(lambda: f.read(1 << 20), b''):
        h.update(blok)
json.dump({"versie": "simulatie-brug", "base": base, "gebouwd": 4102444800, "bestand": "user://ota/brug.pck", "sha256": h.hexdigest(), "grootte": os.path.getsize(d + '/brug.pck'), "naam": "brug.pck"}, open(d + '/actief.json', 'w'))
json.dump({"onstabiel": 0}, open(d + '/opstart.json', 'w'))
PY
LOG="$WERK/simulatie-brug.log"
# Altijd vanuit een lege map starten (zie tools/ota_simulatie.sh): anders gebruikt Godot lokale bestanden in plaats van de pack.
BASIS="$(readlink -f "$BASIS")"
LEEG="$WERK/leeg-brug"; mkdir -p "$LEEG"
set +e
(cd "$LEEG" && XDG_DATA_HOME="$WERK/xdg" timeout 900 "$GODOT" --headless --main-pack "$BASIS" -s "$HIER/tools/ota_brug_simulatie.gd" > "$LOG" 2>&1)
CODE=$?
set -e
grep -E "^SIM |OTA_SIM_" "$LOG" || true
FATAAL="$(grep -cE 'Preload file .* does not exist|Failed to load script|Failed to compile depended scripts|Failed to instantiate an autoload|Cannot find member' "$LOG" || true)"
if [[ "$CODE" != "0" || "$FATAAL" != "0" ]]; then
  echo "Brug-simulatie MISLUKT (exit $CODE, $FATAAL compileerfouten). Eerste fouten:" >&2
  grep -E "SCRIPT ERROR|Preload file|Failed to|OTA_SIM_FOUT" "$LOG" | head -12 >&2 || true
  exit 1
fi
echo "Brug-simulatie goed"
