// uart_sequences.sv - Sequences for UART TX and RX agents
`ifndef UART_SEQUENCES_SV
`define UART_SEQUENCES_SV

// TX sequences
class uart_tx_random_seq extends uvm_sequence #(uart_tx_item);
  rand int unsigned n;

  `uvm_object_utils(uart_tx_random_seq)

  function new(string name = "uart_tx_random_seq");
    super.new(name);
  endfunction

  task body();
    uart_tx_item item;
    repeat (n) begin
      item = uart_tx_item::type_id::create("item");
      start_item(item);
      if (!item.randomize()) `uvm_error(get_type_name(), "Randomization failed")
      finish_item(item);
    end
  endtask
endclass

class uart_tx_backtoback_seq extends uvm_sequence #(uart_tx_item);
  rand int unsigned n;

  `uvm_object_utils(uart_tx_backtoback_seq)

  function new(string name = "uart_tx_backtoback_seq");
    super.new(name);
  endfunction

  task body();
    uart_tx_item item;
    repeat (n) begin
      item = uart_tx_item::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { gap == 0; }) `uvm_error(get_type_name(), "Randomization failed")
      finish_item(item);
    end
  endtask
endclass

class uart_tx_corner_seq extends uvm_sequence #(uart_tx_item);
  `uvm_object_utils(uart_tx_corner_seq)

  function new(string name = "uart_tx_corner_seq");
    super.new(name);
  endfunction

  task body();
    uart_tx_item item;
    bit [7:0] corner_data[] = '{8'h00, 8'hFF, 8'h55, 8'hAA, 8'h01, 8'h02, 8'h04, 8'h08, 8'h10, 8'h20, 8'h40, 8'h80};
    foreach (corner_data[i]) begin
      item = uart_tx_item::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { data == corner_data[i]; }) `uvm_error(get_type_name(), "Randomization failed")
      finish_item(item);
    end
  endtask
endclass

// RX sequences
class uart_rx_random_seq extends uvm_sequence #(uart_rx_item);
  rand int unsigned n;

  `uvm_object_utils(uart_rx_random_seq)

  function new(string name = "uart_rx_random_seq");
    super.new(name);
  endfunction

  task body();
    uart_rx_item item;
    repeat (n) begin
      item = uart_rx_item::type_id::create("item");
      start_item(item);
      if (!item.randomize()) `uvm_error(get_type_name(), "Randomization failed")
      finish_item(item);
    end
  endtask
endclass

class uart_rx_good_only_seq extends uvm_sequence #(uart_rx_item);
  rand int unsigned n;

  `uvm_object_utils(uart_rx_good_only_seq)

  function new(string name = "uart_rx_good_only_seq");
    super.new(name);
  endfunction

  task body();
    uart_rx_item item;
    repeat (n) begin
      item = uart_rx_item::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { bad_stop == 0; glitch == 0; }) `uvm_error(get_type_name(), "Randomization failed")
      finish_item(item);
    end
  endtask
endclass

class uart_rx_error_seq extends uvm_sequence #(uart_rx_item);
  rand int unsigned n;

  `uvm_object_utils(uart_rx_error_seq)

  function new(string name = "uart_rx_error_seq");
    super.new(name);
  endfunction

  task body();
    uart_rx_item item;
    repeat (n) begin
      item = uart_rx_item::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { bad_stop dist { 1 := 50, 0 := 50 }; glitch == 0; }) `uvm_error(get_type_name(), "Randomization failed")
      finish_item(item);
    end
  endtask
endclass

class uart_rx_glitch_seq extends uvm_sequence #(uart_rx_item);
  rand int unsigned n;

  `uvm_object_utils(uart_rx_glitch_seq)

  function new(string name = "uart_rx_glitch_seq");
    super.new(name);
  endfunction

  task body();
    uart_rx_item item;
    repeat (n) begin
      item = uart_rx_item::type_id::create("item");
      start_item(item);
      if (!item.randomize() with { glitch == 1; bad_stop == 0; }) `uvm_error(get_type_name(), "Randomization failed")
      finish_item(item);
    end
  endtask
endclass

`endif
