// uart_rx_monitor.sv - Monitor for UART RX agent
`ifndef UART_RX_MONITOR_SV
`define UART_RX_MONITOR_SV

class uart_rx_monitor extends uvm_monitor;
  virtual uart_if vif;
  uvm_analysis_port #(uart_rx_item) in_ap;
  uvm_analysis_port #(uart_rx_item) out_ap;

  `uvm_component_utils(uart_rx_monitor)

  function new(string name = "uart_rx_monitor", uvm_component parent = null);
    super.new(name, parent);
    in_ap = new("in_ap", this);
    out_ap = new("out_ap", this);
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
      monitor_in();
      monitor_out();
    join
  endtask

  // Monitor rxd line to reconstruct driven items
  task monitor_in();
    uart_rx_item item;
    bit [7:0] data;
    bit start_bit, stop_bit;
    int glitch_cnt;

    forever begin
      // Wait for falling edge of rxd
      @(vif.mon_cb);
      if (vif.mon_cb.rxd === 1'b0) begin
        // Check for glitch: sample after half bit
        repeat (CLKS_PER_BIT/2) @(vif.mon_cb);
        if (vif.mon_cb.rxd === 1'b1) begin
          // Glitch detected, ignore
          continue;
        end

        // Valid start bit, sample at mid-bit
        start_bit = vif.mon_cb.rxd;
        if (start_bit !== 1'b0) begin
          `uvm_error(get_type_name(), $sformatf("Start bit not 0 at mid-bit, got %0b", start_bit))
          continue;
        end

        // Sample 8 data bits LSB first
        data = 8'h00;
        for (int i = 0; i < 8; i++) begin
          repeat (CLKS_PER_BIT) @(vif.mon_cb);
          data[i] = vif.mon_cb.rxd;
        end

        // Sample stop bit
        repeat (CLKS_PER_BIT) @(vif.mon_cb);
        stop_bit = vif.mon_cb.rxd;

        // Create item
        item = uart_rx_item::type_id::create("in_item");
        item.data = data;
        item.bad_stop = (stop_bit === 1'b0) ? 1'b1 : 1'b0;
        item.idle = 0; // not reconstructed
        item.glitch = 0; // not reconstructed
        in_ap.write(item);
      end
    end
  endtask

  // Monitor DUT outputs
  task monitor_out();
    uart_rx_item item;
    forever begin
      @(vif.mon_cb);
      if (vif.mon_cb.rx_valid === 1'b1) begin
        item = uart_rx_item::type_id::create("out_item");
        item.data = vif.mon_cb.rx_data;
        item.bad_stop = 1'b0;
        item.idle = 0;
        item.glitch = 0;
        out_ap.write(item);
      end
      else if (vif.mon_cb.rx_frame_err === 1'b1) begin
        item = uart_rx_item::type_id::create("out_item");
        item.data = 8'h00; // data not valid
        item.bad_stop = 1'b1;
        item.idle = 0;
        item.glitch = 0;
        out_ap.write(item);
      end
    end
  endtask

endclass

`endif
