// uart_env.sv - UVM environment for UART testbench
`ifndef UART_ENV_SV
`define UART_ENV_SV

class uart_env extends uvm_env;
  `uvm_component_utils(uart_env)

  uart_tx_agent    tx_agent;
  uart_rx_agent    rx_agent;
  uart_scoreboard  scoreboard;
  uart_coverage    coverage;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tx_agent   = uart_tx_agent::type_id::create("tx_agent", this);
    rx_agent   = uart_rx_agent::type_id::create("rx_agent", this);
    scoreboard = uart_scoreboard::type_id::create("scoreboard", this);
    coverage   = uart_coverage::type_id::create("coverage", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    // TX path
    tx_agent.monitor.host_ap.connect(scoreboard.host_imp);
    tx_agent.monitor.line_ap.connect(scoreboard.line_imp);
    tx_agent.monitor.host_ap.connect(coverage.tx_imp);
    // RX path
    rx_agent.monitor.in_ap.connect(scoreboard.in_imp);
    rx_agent.monitor.out_ap.connect(scoreboard.out_imp);
    rx_agent.monitor.in_ap.connect(coverage.rx_imp);
  endfunction
endclass

`endif
