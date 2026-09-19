// uart_rx_driver.sv - Driver for UART RX agent (line side)
`ifndef UART_RX_DRIVER_SV
`define UART_RX_DRIVER_SV

class uart_rx_driver extends uvm_driver #(uart_rx_item);
  virtual uart_if vif;

  `uvm_component_utils(uart_rx_driver)

  function new(string name = "uart_rx_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual uart_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "Virtual interface not found")
  endfunction

  task run_phase(uvm_phase phase);
    uart_rx_item item;
    // Wait for reset deassertion
    wait (vif.rst_n === 1'b1);
    @(vif.rx_drv_cb);

    forever begin
      seq_item_port.get_next_item(item);
      drive_item(item);
      seq_item_port.item_done();
    end
  endtask

  task drive_item(uart_rx_item item);
    // Optional glitch: short low pulse before frame
    if (item.glitch) begin
      vif.rx_drv_cb.rxd <= 1'b0;
      repeat (CLKS_PER_BIT/4) @(vif.rx_drv_cb);
      vif.rx_drv_cb.rxd <= 1'b1;
      repeat (CLKS_PER_BIT/4) @(vif.rx_drv_cb);
    end

    // Start bit
    vif.rx_drv_cb.rxd <= 1'b0;
    repeat (CLKS_PER_BIT) @(vif.rx_drv_cb);

    // Data bits LSB first
    for (int i = 0; i < 8; i++) begin
      vif.rx_drv_cb.rxd <= item.data[i];
      repeat (CLKS_PER_BIT) @(vif.rx_drv_cb);
    end

    // Stop bit: 1 if good, 0 if bad_stop
    vif.rx_drv_cb.rxd <= item.bad_stop ? 1'b0 : 1'b1;
    repeat (CLKS_PER_BIT) @(vif.rx_drv_cb);

    // Idle time with rxd high
    vif.rx_drv_cb.rxd <= 1'b1;
    repeat (item.idle) @(vif.rx_drv_cb);
  endtask

endclass

`endif
