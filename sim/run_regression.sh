#!/bin/bash
# Regresion: autoverificable (Verilator) + tests UVM con varias semillas (solo si hay vsim).
# Uso: bash sim/run_regression.sh [n_semillas]     -> exit 0 solo si TODO pasa
set -uo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
NSEEDS=${1:-3}
TESTS="uart_tx_test uart_rx_test uart_error_test uart_glitch_test uart_full_duplex_test"
fail=0
bash "$HERE/run_selfcheck.sh" >/dev/null && echo "PASS selfcheck" || { echo "FAIL selfcheck"; fail=1; }
if command -v vsim >/dev/null 2>&1; then
  for t in $TESTS; do
    for s in $(seq 1 "$NSEEDS"); do
      if bash "$HERE/run_questa.sh" "$t" "$s" >/dev/null 2>&1; then echo "PASS $t seed=$s"; else echo "FAIL $t seed=$s"; fail=1; fi
    done
  done
else
  echo "SKIP tests UVM: vsim no encontrado"
fi
exit $fail
