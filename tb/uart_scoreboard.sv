// uart_scoreboard.sv - Scoreboard for TX and RX paths
`ifndef UART_SCOREBOARD_SV
`define UART_SCOREBOARD_SV

`uvm_analysis_imp_decl(_host)
`uvm_analysis_imp_decl(_line)
`uvm_analysis_imp_decl(_in)
`uvm_analysis_imp_decl(_out)

class uart_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(uart_scoreboard)

  uvm_analysis_imp_host #(uart_tx_item, uart_scoreboard) host_imp;
  uvm_analysis_imp_line #(uart_tx_item, uart_scoreboard) line_imp;
  uvm_analysis_imp_in   #(uart_rx_item, uart_scoreboard) in_imp;
  uvm_analysis_imp_out  #(uart_rx_item, uart_scoreboard) out_imp;

  uart_tx_item tx_host_q[$];
  uart_tx_item tx_line_q[$];
  uart_rx_item rx_in_q[$];
  uart_rx_item rx_out_q[$];

  int tx_checks, tx_errors;
  int rx_checks, rx_errors;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    host_imp = new("host_imp", this);
    line_imp = new("line_imp", this);
    in_imp   = new("in_imp", this);
    out_imp  = new("out_imp", this);
  endfunction

  virtual function void write_host(uart_tx_item item);
    tx_host_q.push_back(item);
    check_tx();
  endfunction

  virtual function void write_line(uart_tx_item item);
    tx_line_q.push_back(item);
    check_tx();
  endfunction

  virtual function void write_in(uart_rx_item item);
    rx_in_q.push_back(item);
    check_rx();
  endfunction

  virtual function void write_out(uart_rx_item item);
    rx_out_q.push_back(item);
    check_rx();
  endfunction

  function void check_tx();
    while (tx_host_q.size() > 0 && tx_line_q.size() > 0) begin
      uart_tx_item exp = tx_host_q.pop_front();
      uart_tx_item act = tx_line_q.pop_front();
      tx_checks++;
      if (exp.data !== act.data) begin
        tx_errors++;
        `uvm_error("SCOREBOARD_TX", $sformatf("TX data mismatch: expected 0x%02h, got 0x%02h", exp.data, act.data))
      end
    end
  endfunction

  function void check_rx();
    while (rx_in_q.size() > 0 && rx_out_q.size() > 0) begin
      uart_rx_item exp = rx_in_q.pop_front();
      uart_rx_item act = rx_out_q.pop_front();
      rx_checks++;
      if (exp.bad_stop) begin
        if (!act.bad_stop) begin
          rx_errors++;
          `uvm_error("SCOREBOARD_RX", $sformatf("Expected bad stop bit, but got good frame with data 0x%02h", act.data))
        end
      end else begin
        if (act.bad_stop) begin
          rx_errors++;
          `uvm_error("SCOREBOARD_RX", $sformatf("Expected good frame data 0x%02h, but got bad stop bit", exp.data))
        end else if (exp.data !== act.data) begin
          rx_errors++;
          `uvm_error("SCOREBOARD_RX", $sformatf("RX data mismatch: expected 0x%02h, got 0x%02h", exp.data, act.data))
        end
      end
    end
  endfunction

  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (tx_host_q.size() > 1) begin
      `uvm_error("SCOREBOARD_TX", $sformatf("TX host queue has %0d items remaining", tx_host_q.size()))
    end
    if (tx_line_q.size() > 1) begin
      `uvm_error("SCOREBOARD_TX", $sformatf("TX line queue has %0d items remaining", tx_line_q.size()))
    end
    if (rx_in_q.size() > 0) begin
      `uvm_error("SCOREBOARD_RX", $sformatf("RX in queue has %0d items remaining", rx_in_q.size()))
    end
    if (rx_out_q.size() > 0) begin
      `uvm_error("SCOREBOARD_RX", $sformatf("RX out queue has %0d items remaining", rx_out_q.size()))
    end
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCOREBOARD", $sformatf("TX checks: %0d, errors: %0d", tx_checks, tx_errors), UVM_LOW)
    `uvm_info("SCOREBOARD", $sformatf("RX checks: %0d, errors: %0d", rx_checks, rx_errors), UVM_LOW)
    if (tx_errors == 0 && rx_errors == 0) begin
      `uvm_info("SCOREBOARD", "TEST PASSED", UVM_LOW)
    end else begin
      `uvm_info("SCOREBOARD", "TEST FAILED", UVM_LOW)
    end
  endfunction
endclass

`endif
