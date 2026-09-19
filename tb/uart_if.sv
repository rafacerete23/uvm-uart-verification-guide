// uart_if.sv - Interface for UART core with clocking blocks and reset task
`ifndef UART_IF_SV
`define UART_IF_SV

interface uart_if(input logic clk);
  logic rst_n;
  logic tx_valid;
  logic tx_ready;
  logic txd;
  logic rxd;
  logic rx_valid;
  logic rx_frame_err;
  logic [7:0] tx_data;
  logic [7:0] rx_data;

  // Clocking block for TX driver: drives tx_data, tx_valid, rxd; samples tx_ready, txd, rx_valid, rx_data, rx_frame_err
  clocking tx_drv_cb @(posedge clk);
    default input #1step output #1;
    output tx_data;
    output tx_valid;
    output rxd;
    input tx_ready;
    input txd;
    input rx_valid;
    input rx_data;
    input rx_frame_err;
  endclocking

  // Clocking block for RX driver: drives rxd only
  clocking rx_drv_cb @(posedge clk);
    default input #1step output #1;
    output rxd;
  endclocking

  // Monitor clocking block: all inputs
  clocking mon_cb @(posedge clk);
    default input #1step;
    input rst_n;
    input tx_valid;
    input tx_ready;
    input txd;
    input rxd;
    input rx_valid;
    input rx_frame_err;
    input tx_data;
    input rx_data;
  endclocking

  // Reset task: rst_n low for 'cycles' clocks, then high; initialise outputs
  task apply_reset(int cycles);
    rst_n = 0;
    tx_valid = 0;
    tx_data = 0;
    rxd = 1;
    repeat (cycles) @(posedge clk);
    rst_n = 1;
    @(posedge clk);
  endtask

endinterface

`endif
