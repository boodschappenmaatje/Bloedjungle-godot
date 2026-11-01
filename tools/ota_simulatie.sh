#!/usr/bin/env bash
# Bootst de app na met een IPA-basis, een licht stuk en zware stukken, en controleert dat het spel goed opstart (speler zichtbaar).
# Gebruik: tools/ota_simulatie.sh <godot> <ios-basis.pck> <licht.pck> <zwaar1.pck> [zwaar2.pck ...]
# Omgeving: OTA_BASE (commit van de IPA, verplicht), OTA_WERKMAP (standaard een tijdelijke map), OTA_PROJECTNAAM (standaard: uit project.godot).
# Exit 0 = goed, 1 = de update zou het spel breken (niets publiceren).
set -euo pipefail
GODOT="$1"; BASIS="$2"; LICHT="$3"; shift 3
ZWAAR=("$@")
: "${OTA_BASE:?OTA_BASE (commit van de IPA) ontbreekt}"
HIER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NAAM="${OTA_PROJECTNAAM:-$(sed -n 's/^config\/name="\(.*\)"/\1/p' "$HIER/project.godot" | head -1)}"
WERK="${OTA_WERKMAP:-$(mktemp -d)}"
DATA="$WERK/xdg/godot/app_userdata/$NAAM/ota"
rm -rf "$WERK/xdg"; mkdir -p "$DATA/keten"
cp "$LICHT" "$DATA/licht.pck"
i=0
for z in "${ZWAAR[@]}"; do i=$((i+1)); ln -s "$(readlink -f "$z")" "$DATA/keten/zwaar-$i.pck"; done
# precies wat de app zelf bijhoudt: actief.json (lichte patch) en keten.json (zware stukken), met hash en grootte
python3 -I - "$DATA" "$OTA_BASE" "$i" <<'PY'
import hashlib, json, os, sys
d, base, n = sys.argv[1], sys.argv[2], int(sys.argv[3])
def info(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for blok in iter(lambda: f.read(1 << 20), b''):
            h.update(blok)
    return h.hexdigest(), os.path.getsize(p)
sha, grootte = info(d + '/licht.pck')
json.dump({"versie": "simulatie", "base": base, "gebouwd": 4102444800, "bestand": "user://ota/licht.pck", "sha256": sha, "grootte": grootte, "naam": "licht.pck"}, open(d + '/actief.json', 'w'))
stukken = []
for k in range(1, n + 1):
    sha, grootte = info(d + '/keten/zwaar-%d.pck' % k)
    stukken.append({"naam": "zwaar-%d.pck" % k, "bestand": "user://ota/keten/zwaar-%d.pck" % k, "sha256": sha, "grootte": grootte})
json.dump({"basis": base, "stukken": stukken}, open(d + '/keten.json', 'w'))
json.dump({"onstabiel": 0}, open(d + '/opstart.json', 'w'))
PY
LOG="$WERK/simulatie.log"
set +e
XDG_DATA_HOME="$WERK/xdg" timeout 900 "$GODOT" --headless --main-pack "$BASIS" -s "$HIER/tools/ota_simulatie.gd" > "$LOG" 2>&1
CODE=$?
set -e
grep -E "^SIM |OTA_SIM_" "$LOG" || true
# compileerfouten in het log tellen ook, ook als het spel nog net opstart
FATAAL="$(grep -cE 'Preload file .* does not exist|Failed to load script|Failed to compile depended scripts|Failed to instantiate an autoload' "$LOG" || true)"
if [[ "$CODE" != "0" || "$FATAAL" != "0" ]]; then
  echo "OTA-simulatie MISLUKT (exit $CODE, $FATAAL compileerfouten). Eerste fouten:" >&2
  grep -E "SCRIPT ERROR|Preload file|Failed to" "$LOG" | head -12 >&2 || true
  exit 1
fi
echo "OTA-simulatie goed"
