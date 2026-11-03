#!/usr/bin/env bash
# Corre una prueba de flujo de Patrol y devuelve solo el reporte.
#
# Uso: run_flow.sh <archivo_test|all> [flavor] [device_id] [timeout_s]
#   archivo_test  patrol_test/flows/<flujo>_test.dart, o "all" para la suite
#   flavor        dev (default) | qa — se combina con el prefijo del proyecto
#   device_id     opcional; si falta, Patrol elige el dispositivo conectado
#   timeout_s     tope de la corrida (default 600)
#
# Patrol en iOS puede quedarse colgado después de una prueba fallida: el script
# lo detiene en cuanto aparece el resumen final o al llegar al tope.
# Salida: 0 todo verde, 1 alguna falla, 2 tope de tiempo, 3 error de uso.
# Se corre desde la raíz del proyecto Flutter.

set -uo pipefail

target="${1:-}"
flavor="${2:-dev}"
device="${3:-}"
limit="${4:-600}"

[[ -z "$target" ]] && { echo "Uso: run_flow.sh <archivo_test|all> [flavor] [device_id] [timeout_s]"; exit 3; }
[[ "$flavor" == "prod" ]] && { echo "No se corren pruebas contra prod."; exit 3; }
[[ -f patrol_test/test_env.json ]] || { echo "Falta patrol_test/test_env.json (copia test_env.example.json y pon el usuario de prueba)."; exit 3; }

entry=$(ls lib/main_*_"$flavor".dart 2>/dev/null | head -1)
[[ -z "$entry" ]] && { echo "No hay entrypoint lib/main_*_$flavor.dart"; exit 3; }
project=$(basename "$entry" .dart | sed -E "s/^main_(.*)_$flavor$/\1/")
flavor_id="${project}$(tr '[:lower:]' '[:upper:]' <<<"${flavor:0:1}")${flavor:1}"

patrol_bin=$(command -v patrol || echo "$HOME/.pub-cache/bin/patrol")
[[ -x "$patrol_bin" ]] || { echo "Falta patrol_cli: dart pub global activate patrol_cli"; exit 3; }

if [[ -d "${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools" ]]; then
  export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
  export PATH="$ANDROID_HOME/platform-tools:$PATH"
fi

args=(test --flavor "$flavor_id" --dart-define-from-file=patrol_test/test_env.json --show-flutter-logs)
[[ "$target" != "all" ]] && args+=(-t "$target")
[[ -n "$device" ]] && args+=(-d "$device")

log=$(mktemp -t patrol_flow).log
echo "Corriendo: patrol ${args[*]}"
echo "Log completo: $log"

"$patrol_bin" "${args[@]}" >"$log" 2>&1 &
pid=$!

status=2
for ((elapsed = 0; elapsed < limit; elapsed += 5)); do
  sleep 5
  if ! kill -0 "$pid" 2>/dev/null; then
    wait "$pid"; [[ $? -eq 0 ]] && status=0 || status=1
    break
  fi
  if grep -qE "Some tests failed|Test summary" "$log"; then
    sleep 10
    grep -q "Some tests failed" "$log" && status=1 || status=0
    grep -qE "❌ Failed: [1-9]" "$log" && status=1
    break
  fi
done
pkill -P "$pid" 2>/dev/null
kill "$pid" 2>/dev/null
wait "$pid" 2>/dev/null

sed 's/\x1b\[[0-9;]*[A-Za-z]//g' "$log" \
  | grep -E "\[FLOW |\[APP_ERROR\]|^[[:space:]]*(✅|❌) [^ 0-9]|Total:|Successful:|Failed:|^Error:" \
  | sed 's/^flutter: //' | cut -c1-400

case $status in
  0) echo "RESULTADO: OK" ;;
  1) echo "RESULTADO: FALLAS (ver líneas de arriba y el log completo)" ;;
  2) echo "RESULTADO: TOPE DE TIEMPO (${limit}s) — revisa el log completo" ;;
esac
exit $status
