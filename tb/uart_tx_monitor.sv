// uart_tx_monitor.sv - Monitor for UART TX agent
`ifndef UART_TX_MONITOR_SV
`define UART_TX_MONITOR_SV

class uart_tx_monitor extends uvm_monitor;
  virtual uart_if vif;
  uvm_analysis_port #(uart_tx_item) host_ap;
  uvm_analysis_port #(uart_tx_item) line_ap;

  `uvm_component_utils(uart_tx_monitor)

  function new(string name = "uart_tx_monitor", uvm_component parent = null);
    super.new(name, parent);
    host_ap = new("host_ap", this);
    line_ap = new("line_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual uart_if)::get(this, "", "vif", vif))
      `uvm_fatal(get_type_name(), "Virtual interface not found")
  endfunction

  task run_phase(uvm_phase phase);
    // Wait for reset deassertion
    wait (vif.rst_n === 1'b1);
    @(vif.mon_cb);

    fork
      monitor_host();
      monitor_line();
    join
  endtask

  // Monitor accepted bytes on host side
  task monitor_host();
    uart_tx_item item;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.tx_valid === 1'b1 && vif.mon_cb.tx_ready === 1'b1) begin
        item = uart_tx_item::type_id::create("host_item");
        item.data = vif.mon_cb.tx_data;
        item.gap = 0; // gap not relevant for host monitor
        host_ap.write(item);
      end
    end
  endtask

  // Monitor frames on txd line
  task monitor_line();
    uart_tx_item item;
    bit [7:0] data;
    bit start_bit, stop_bit;
    int bit_cnt;

    forever begin
      // Wait for falling edge of txd (start bit)
      @(vif.mon_cb);
      if (vif.mon_cb.txd === 1'b0) begin
        // Start bit detected, sample at mid-bit
        repeat (CLKS_PER_BIT/2) @(vif.mon_cb);
        start_bit = vif.mon_cb.txd;
        if (start_bit !== 1'b0) begin
          `uvm_error(get_type_name(), $sformatf("Start bit not 0 at mid-bit, got %0b", start_bit))
          continue;
        end

        // Sample 8 data bits LSB first
        data = 8'h00;
        for (int i = 0; i < 8; i++) begin
          repeat (CLKS_PER_BIT) @(vif.mon_cb);
          data[i] = vif.mon_cb.txd;
        end

        // Sample stop bit
        repeat (CLKS_PER_BIT) @(vif.mon_cb);
        stop_bit = vif.mon_cb.txd;
        if (stop_bit !== 1'b1) begin
          `uvm_error(get_type_name(), $sformatf("Stop bit not 1 at mid-bit, got %0b", stop_bit))
        end

        // Create item and send to line_ap
        item = uart_tx_item::type_id::create("line_item");
        item.data = data;
        item.gap = 0;
        line_ap.write(item);
      end
    end
  endtask

endclass

`endif
