// uart_coverage.sv - Functional coverage for UART
`ifndef UART_COVERAGE_SV
`define UART_COVERAGE_SV

`uvm_analysis_imp_decl(_tx)
`uvm_analysis_imp_decl(_rx)

class uart_coverage extends uvm_component;
  `uvm_component_utils(uart_coverage)

  uvm_analysis_imp_tx #(uart_tx_item, uart_coverage) tx_imp;
  uvm_analysis_imp_rx #(uart_rx_item, uart_coverage) rx_imp;

  covergroup tx_data_cg;
    cp_data: coverpoint tx_data {
      bins zero = {0};
      bins ff = {8'hFF};
      bins aa = {8'hAA};
      bins _55 = {8'h55};
      bins walking[] = {8'h01, 8'h02, 8'h04, 8'h08, 8'h10, 8'h20, 8'h40, 8'h80};
      bins others = default;
    }
  endgroup

  covergroup tx_gap_cg;
    cp_gap: coverpoint tx_gap {
      bins zero = {0};
      bins short = {[1:10]};
      bins long = {[11:40]};
    }
  endgroup

  covergroup rx_data_cg;
    cp_data: coverpoint rx_data {
      bins zero = {0};
      bins ff = {8'hFF};
      bins aa = {8'hAA};
      bins _55 = {8'h55};
      bins walking[] = {8'h01, 8'h02, 8'h04, 8'h08, 8'h10, 8'h20, 8'h40, 8'h80};
      bins others = default;
    }
  endgroup

  covergroup rx_bad_stop_cg;
    cp_bad_stop: coverpoint rx_bad_stop;
  endgroup

  covergroup rx_glitch_cg;
    cp_glitch: coverpoint rx_glitch;
  endgroup

  covergroup tx_backtoback_cg;
    cp_backtoback: coverpoint tx_gap {
      bins backtoback = {0};
    }
  endgroup

  bit [7:0] tx_data;
  int unsigned tx_gap;
  bit [7:0] rx_data;
  bit rx_bad_stop;
  bit rx_glitch;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    tx_imp = new("tx_imp", this);
    rx_imp = new("rx_imp", this);
    tx_data_cg = new();
    tx_gap_cg = new();
    rx_data_cg = new();
    rx_bad_stop_cg = new();
    rx_glitch_cg = new();
    tx_backtoback_cg = new();
  endfunction

  virtual function void write_tx(uart_tx_item item);
    tx_data = item.data;
    tx_gap = item.gap;
    tx_data_cg.sample();
    tx_gap_cg.sample();
    tx_backtoback_cg.sample();
  endfunction

  virtual function void write_rx(uart_rx_item item);
    rx_data = item.data;
    rx_bad_stop = item.bad_stop;
    rx_glitch = item.glitch;
    rx_data_cg.sample();
    rx_bad_stop_cg.sample();
    rx_glitch_cg.sample();
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("COVERAGE", $sformatf("TX data coverage: %.2f%%", tx_data_cg.get_coverage()), UVM_LOW)
    `uvm_info("COVERAGE", $sformatf("TX gap coverage: %.2f%%", tx_gap_cg.get_coverage()), UVM_LOW)
    `uvm_info("COVERAGE", $sformatf("RX data coverage: %.2f%%", rx_data_cg.get_coverage()), UVM_LOW)
    `uvm_info("COVERAGE", $sformatf("RX bad_stop coverage: %.2f%%", rx_bad_stop_cg.get_coverage()), UVM_LOW)
    `uvm_info("COVERAGE", $sformatf("RX glitch coverage: %.2f%%", rx_glitch_cg.get_coverage()), UVM_LOW)
    `uvm_info("COVERAGE", $sformatf("TX back-to-back coverage: %.2f%%", tx_backtoback_cg.get_coverage()), UVM_LOW)
  endfunction
endclass

`endif
