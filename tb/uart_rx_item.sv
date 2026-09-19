// uart_rx_item.sv - Transaction item for UART RX path
`ifndef UART_RX_ITEM_SV
`define UART_RX_ITEM_SV

class uart_rx_item extends uvm_sequence_item;
  rand bit [7:0] data;
  rand bit bad_stop;
  rand int unsigned idle;
  rand bit glitch;

  constraint c_bad_stop {
    bad_stop dist { 0 := 90, 1 := 10 };
  }

  constraint c_idle {
    idle inside {[CLKS_PER_BIT/2 : 3*CLKS_PER_BIT]};
  }

  constraint c_glitch {
    glitch dist { 0 := 95, 1 := 5 };
  }

  `uvm_object_utils_begin(uart_rx_item)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_int(bad_stop, UVM_ALL_ON)
    `uvm_field_int(idle, UVM_ALL_ON)
    `uvm_field_int(glitch, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "uart_rx_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("data=0x%02h bad_stop=%0b idle=%0d glitch=%0b", data, bad_stop, idle, glitch);
  endfunction

endclass

`endif
