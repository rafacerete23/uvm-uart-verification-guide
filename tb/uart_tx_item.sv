// uart_tx_item.sv - Transaction item for UART TX path
`ifndef UART_TX_ITEM_SV
`define UART_TX_ITEM_SV

class uart_tx_item extends uvm_sequence_item;
  rand bit [7:0] data;
  rand int unsigned gap;

  constraint c_gap {
    gap inside {[0:40]};
    gap dist { 0 := 60, [1:5] := 20, [6:40] := 20 };
  }

  `uvm_object_utils_begin(uart_tx_item)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_int(gap, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "uart_tx_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("data=0x%02h gap=%0d", data, gap);
  endfunction

endclass

`endif
