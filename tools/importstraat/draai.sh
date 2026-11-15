#!/usr/bin/env bash
# Importstraat: alle .glb's in een map door de straat + rapport.
#   tools/importstraat/draai.sh <map met .glb's> <uitmap>
# Een regelbestand met dezelfde naam (<naam>.json naast de .glb) overschrijft de standaardregels van het type.
set -euo pipefail
IN="$(cd "$1" && pwd)"; OUT="$(mkdir -p "$2" && cd "$2" && pwd)"
HERE="$(cd "$(dirname "$0")" && pwd)"
for glb in "$IN"/*.glb; do
  base="$(basename "$glb" .glb)"
  dst="$OUT/$base"
  regels=()
  [ -f "$IN/$base.json" ] && regels=(--regels "$IN/$base.json")
  echo "== $base"
  python3 -I "$HERE/straat.py" "$glb" "$dst" "${regels[@]}" 2>&1 | grep '^\[straat' || true
  python3 -I "$HERE/rapport.py" "$glb" "$dst" > "$dst/rapport.log" 2>&1 || { echo "rapport mislukt, zie $dst/rapport.log"; continue; }
  grep -E "Eis 60 fps|Beeldverschil" "$dst/RAPPORT.md" || true
done
