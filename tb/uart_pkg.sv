// uart_pkg.sv - UVM package for UART testbench
`ifndef UART_PKG_SV
`define UART_PKG_SV

package uart_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  parameter int CLKS_PER_BIT = 16;

  `include "uart_tx_item.sv"
  `include "uart_rx_item.sv"
  `include "uart_sequences.sv"
  `include "uart_tx_driver.sv"
  `include "uart_tx_monitor.sv"
  `include "uart_rx_driver.sv"
  `include "uart_rx_monitor.sv"
  `include "uart_agents.sv"
  `include "uart_scoreboard.sv"
  `include "uart_coverage.sv"
  `include "uart_env.sv"
  `include "uart_tests.sv"

endpackage

`endif
