#!/bin/bash
# Barrido de tolerancia de baudrate del receptor con Verilator 5.
# Uso: bash sim/run_baud_sweep.sh   -> imprime una linea "SWEEP skew_pm=<milesimas> ok=<0|1> ..." por desviacion
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
OUT=$HERE/sim/obj_baud_sweep
rm -rf "$OUT"
verilator --binary --timing -j 0 -O1 -Wno-fatal -Wno-lint -Wno-style -Wno-WIDTH -Wno-TIMESCALEMOD   "$HERE/rtl/uart_core.sv" "$HERE/tb/baud_sweep_tb.sv" --top-module tb_sweep -Mdir "$OUT" -o baud_sweep
"$OUT/baud_sweep" | grep -E 'SWEEP'
