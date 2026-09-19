#!/bin/bash
# Compila y corre el testbench autoverificable (SystemVerilog plano) con Verilator 5.
# Uso: bash sim/run_selfcheck.sh      -> imprime "RESULT: PASS" o "RESULT: FAIL (n errors)"
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
OUT=$HERE/sim/obj_selfcheck
rm -rf "$OUT"
verilator --binary --timing -j 0 -O1 -Wno-fatal -Wno-lint -Wno-style -Wno-WIDTH -Wno-TIMESCALEMOD   "$HERE/rtl/uart_core.sv" "$HERE/tb/selfcheck_tb.sv" --top-module tb_selfcheck -Mdir "$OUT" -o selfcheck
"$OUT/selfcheck"
