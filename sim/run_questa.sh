#!/bin/bash
# Corre el testbench UVM con Questa/ModelSim (UVM 1.2 incluido en el simulador).
# NO VERIFICADO en la maquina del autor (no hay simulador UVM comercial disponible allí).
# Uso: bash sim/run_questa.sh <nombre_del_test>   (ver tb/*_tests.sv)
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
TEST=${1:?Indica el test, por ejemplo: uart_full_duplex_test}
cd "$HERE/sim"
vlib work
vlog -sv +incdir+"$HERE/tb" "$HERE/rtl/uart_core.sv" "$HERE/tb/uart_if.sv" "$HERE/tb/uart_pkg.sv" "$HERE/tb/tb_top.sv"
vsim -c tb_top +UVM_TESTNAME="$TEST" -do "run -all; quit -f"
