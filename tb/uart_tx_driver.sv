// uart_tx_driver.sv - Driver for UART TX agent (host side)
`ifndef UART_TX_DRIVER_SV
`define UART_TX_DRIVER_SV

class uart_tx_driver extends uvm_driver #(uart_tx_item);
  virtual uart_if vif;

  `uvm_component_utils(uart_tx_driver)

  function new(string name = "uart_tx_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual uart_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "Virtual interface not found")
  endfunction

  task run_phase(uvm_phase phase);
    uart_tx_item item;
    // Wait for reset deassertion
    wait (vif.rst_n === 1'b1);
    @(vif.tx_drv_cb);

    forever begin
      seq_item_port.get_next_item(item);
      drive_item(item);
      seq_item_port.item_done();
    end
  endtask

  task drive_item(uart_tx_item item);
    // Wait gap cycles (idle before presenting byte)
    repeat (item.gap) @(vif.tx_drv_cb);

    // Present byte
    vif.tx_drv_cb.tx_data <= item.data;
    vif.tx_drv_cb.tx_valid <= 1'b1;

    // Wait for handshake: tx_ready high at a clock edge
    do begin
      @(vif.tx_drv_cb);
    end while (vif.tx_drv_cb.tx_ready !== 1'b1);

    // Deassert tx_valid
    vif.tx_drv_cb.tx_valid <= 1'b0;
    vif.tx_drv_cb.tx_data <= 8'h00;
  endtask

endclass

`endif
