// uart_agents.sv - TX and RX agents
`ifndef UART_AGENTS_SV
`define UART_AGENTS_SV

class uart_tx_agent extends uvm_agent;
  `uvm_component_utils(uart_tx_agent)

  uart_tx_driver    driver;
  uart_tx_monitor   monitor;
  uvm_sequencer #(uart_tx_item) sequencer;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = uart_tx_monitor::type_id::create("monitor", this);
    if (get_is_active() == UVM_ACTIVE) begin
      driver = uart_tx_driver::type_id::create("driver", this);
      sequencer = uvm_sequencer#(uart_tx_item)::type_id::create("sequencer", this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction
endclass

class uart_rx_agent extends uvm_agent;
  `uvm_component_utils(uart_rx_agent)

  uart_rx_driver    driver;
  uart_rx_monitor   monitor;
  uvm_sequencer #(uart_rx_item) sequencer;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    monitor = uart_rx_monitor::type_id::create("monitor", this);
    if (get_is_active() == UVM_ACTIVE) begin
      driver = uart_rx_driver::type_id::create("driver", this);
      sequencer = uvm_sequencer#(uart_rx_item)::type_id::create("sequencer", this);
    end
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction
endclass

`endif
