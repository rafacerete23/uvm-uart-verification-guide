// uart_tests.sv - UVM tests for UART
`ifndef UART_TESTS_SV
`define UART_TESTS_SV

class uart_base_test extends uvm_test;
  `uvm_component_utils(uart_base_test)

  uart_env env;
  virtual uart_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = uart_env::type_id::create("env", this);
    if (!uvm_config_db#(virtual uart_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("TEST", "Could not get vif from config_db")
    end
    uvm_config_db#(virtual uart_if)::set(this, "env.*", "vif", vif);
    `uvm_info("TEST", "UART testbench topology:", UVM_LOW)
    print_topology();
  endfunction

  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    run_sequences();
    #(4 * 10 * CLKS_PER_BIT * 10ns); // drain time
    phase.drop_objection(this);
  endtask

  virtual task run_sequences();
    // Override in derived tests
  endtask

  task run_tx_seq(uvm_sequence #(uart_tx_item) seq);
    seq.start(env.tx_agent.sequencer);
  endtask

  task run_rx_seq(uvm_sequence #(uart_rx_item) seq);
    seq.start(env.rx_agent.sequencer);
  endtask
endclass

class uart_tx_test extends uart_base_test;
  `uvm_component_utils(uart_tx_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_sequences();
    uart_tx_corner_seq corner_seq;
    uart_tx_random_seq random_seq;
    uart_tx_backtoback_seq backtoback_seq;

    corner_seq = uart_tx_corner_seq::type_id::create("corner_seq");
    random_seq = uart_tx_random_seq::type_id::create("random_seq");
    backtoback_seq = uart_tx_backtoback_seq::type_id::create("backtoback_seq");

    random_seq.n = 50;
    backtoback_seq.n = 20;

    corner_seq.start(env.tx_agent.sequencer);
    random_seq.start(env.tx_agent.sequencer);
    backtoback_seq.start(env.tx_agent.sequencer);
  endtask
endclass

class uart_rx_test extends uart_base_test;
  `uvm_component_utils(uart_rx_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_sequences();
    uart_rx_good_only_seq good_seq;
    uart_rx_random_seq random_seq;

    good_seq = uart_rx_good_only_seq::type_id::create("good_seq");
    random_seq = uart_rx_random_seq::type_id::create("random_seq");

    good_seq.n = 50;
    random_seq.n = 50;

    good_seq.start(env.rx_agent.sequencer);
    random_seq.start(env.rx_agent.sequencer);
  endtask
endclass

class uart_error_test extends uart_base_test;
  `uvm_component_utils(uart_error_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_sequences();
    uart_rx_error_seq error_seq;
    uart_tx_random_seq tx_seq;

    error_seq = uart_rx_error_seq::type_id::create("error_seq");
    tx_seq = uart_tx_random_seq::type_id::create("tx_seq");

    tx_seq.n = 50;

    fork
      error_seq.start(env.rx_agent.sequencer);
      tx_seq.start(env.tx_agent.sequencer);
    join
  endtask
endclass

class uart_glitch_test extends uart_base_test;
  `uvm_component_utils(uart_glitch_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_sequences();
    uart_rx_glitch_seq glitch_seq;
    glitch_seq = uart_rx_glitch_seq::type_id::create("glitch_seq");
    glitch_seq.start(env.rx_agent.sequencer);
  endtask
endclass

class uart_full_duplex_test extends uart_base_test;
  `uvm_component_utils(uart_full_duplex_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_sequences();
    uart_tx_random_seq tx_seq;
    uart_rx_good_only_seq rx_seq;

    tx_seq = uart_tx_random_seq::type_id::create("tx_seq");
    rx_seq = uart_rx_good_only_seq::type_id::create("rx_seq");

    tx_seq.n = 100;
    rx_seq.n = 100;

    fork
      tx_seq.start(env.tx_agent.sequencer);
      rx_seq.start(env.rx_agent.sequencer);
    join
  endtask
endclass

`endif
