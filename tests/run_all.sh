#!/usr/bin/env bash
# Integration checks against a live omarchy-shell (best-effort).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "== unit =="
node "$ROOT/tests/test_model.js"
python3 "$ROOT/tests/test_fetch_rates.py"
omarchy plugin validate "$ROOT"

echo "== live fetch =="
body="$("$ROOT/bin/fetch-rates" 'https://api.frankfurter.app/latest?from=USD')"
python3 -c 'import json,sys; d=json.loads(sys.argv[1]); assert d.get("base")=="USD" and "ILS" in d["rates"]; print("fetch ok", d["date"], "ILS", d["rates"]["ILS"])' "$body"

echo "== ipc =="
if ! omarchy-shell shell ping >/dev/null 2>&1; then
  echo "shell not running; skip ipc"
  exit 0
fi

omarchy bar set io.github.lekonidus.currency from USD
omarchy bar set io.github.lekonidus.currency to ILS
omarchy-shell io.github.lekonidus.currency refresh >/dev/null
sleep 1.5
before="$(omarchy-shell io.github.lekonidus.currency status)"
echo "before=$before"

omarchy-shell io.github.lekonidus.currency swap >/dev/null
sleep 0.5
after="$(omarchy-shell io.github.lekonidus.currency status)"
echo "after=$after"

python3 -c '
import json,sys
before=json.loads(sys.argv[1])
after=json.loads(sys.argv[2])
assert before.get("from")=="USD" and before.get("to")=="ILS", before
assert before.get("labelsMatch") is True, before
assert after.get("from")=="ILS" and after.get("to")=="USD", after
assert after.get("labelsMatch") is True, after
assert after.get("fromPicker")=="ILS" and after.get("toPicker")=="USD", after
print("ipc swap+labels ok")
' "$before" "$after"

echo "all ok"
