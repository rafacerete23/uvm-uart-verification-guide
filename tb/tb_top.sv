// tb_top.sv - Top-level testbench module
`timescale 1ns/1ps

module tb_top;
  import uvm_pkg::*;
  import uart_pkg::*;

  logic clk;

  // 100 MHz clock
  initial clk = 0;
  always #5 clk = ~clk;

  uart_if vif(clk);

  uart_core #(.CLKS_PER_BIT(CLKS_PER_BIT)) dut (
    .clk(clk),
    .rst_n(vif.rst_n),
    .tx_data(vif.tx_data),
    .tx_valid(vif.tx_valid),
    .tx_ready(vif.tx_ready),
    .txd(vif.txd),
    .rxd(vif.rxd),
    .rx_data(vif.rx_data),
    .rx_valid(vif.rx_valid),
    .rx_frame_err(vif.rx_frame_err)
  );

  initial begin
    uvm_config_db#(virtual uart_if)::set(null, "*", "vif", vif);
    fork
      vif.apply_reset(4);
      run_test();
    join_none
  end

`ifdef WAVES
  initial begin
    $dumpfile("uart_waves.vcd");
    $dumpvars(0, tb_top);
  end
`endif
endmodule
