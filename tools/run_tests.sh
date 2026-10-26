#!/bin/bash
# Draait alle Godot-tests headless en meldt per test OK of FOUT.
#   GODOT=/pad/naar/godot tools/run_tests.sh [test ...]     (zonder argumenten: alle tests)
# FOUT = exitcode niet 0 (ook een tijdslimiet), of "SCRIPT ERROR" / "Parse Error" / "SHADER ERROR" / "FAIL" in de uitvoer.
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.." || exit 2
TESTS=("$@")
[ ${#TESTS[@]} -eq 0 ] && TESTS=($(ls tests/*_test.gd | xargs -n1 basename | sed 's/\.gd$//'))
bad=0
for t in "${TESTS[@]}"; do
  fixed="--fixed-fps 60"
  [ "$t" = "kwaliteit_regel_test" -o "$t" = "diagnoserun_test" ] && fixed=""   # meet echte tijd (beeldsnelheid vastgezet op 20), dus zonder vaste stap
  out=$(timeout "${TEST_TIMEOUT:-170}" "$GODOT" --headless --path . -s "tests/$t.gd" $fixed 2>&1)
  code=$?
  if [ $code -ne 0 ] || echo "$out" | grep -qE "SCRIPT ERROR|Parse Error|SHADER ERROR|FAIL"; then
    echo "FOUT $t (exit $code)"; echo "$out" | grep -E "SCRIPT ERROR|Parse Error|SHADER ERROR|FAIL|CAMERA TEST" | head -5 | sed 's/^/     /'; bad=1
  else
    echo "OK   $t"
  fi
done
exit $bad
