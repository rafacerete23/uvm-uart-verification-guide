// Barrido de tolerancia de baudrate del receptor de uart_core (CLKS_PER_BIT=16).
// Envia 8 bytes con el periodo de bit desviado skew_pm milesimas (de -120 a +120,
// paso 5) y comprueba que el receptor los recibe todos, en orden y sin errores de trama.
// Imprime una linea "SWEEP skew_pm=... ok=..." por desviacion. Ver sim/run_baud_sweep.sh.
`timescale 1ns/1ps
module tb_sweep;
  localparam int CLKS_PER_BIT = 16;
  localparam int CLK_NS = 10;

  logic clk = 0;
  logic rst_n;
  logic [7:0] tx_data;
  logic tx_valid;
  logic tx_ready;
  logic txd;
  logic rxd;
  logic [7:0] rx_data;
  logic rx_valid;
  logic rx_frame_err;

  always #(CLK_NS/2) clk = ~clk;

  uart_core #(.CLKS_PER_BIT(CLKS_PER_BIT)) dut (
    .clk(clk), .rst_n(rst_n),
    .tx_data(tx_data), .tx_valid(tx_valid), .tx_ready(tx_ready), .txd(txd),
    .rxd(rxd), .rx_data(rx_data), .rx_valid(rx_valid), .rx_frame_err(rx_frame_err)
  );

  typedef struct { logic [7:0] data; logic err; } rx_ev_t;
  rx_ev_t got_q [$];

  // Monitor: registra rx_valid y rx_frame_err en cada posedge
  initial begin : rx_monitor
    forever begin
      @(posedge clk);
      if (rx_valid) begin
        rx_ev_t e;
        e.data = rx_data;
        e.err = 1'b0;
        got_q.push_back(e);
      end
      if (rx_frame_err) begin
        rx_ev_t e;
        e.data = 8'hxx;
        e.err = 1'b1;
        got_q.push_back(e);
      end
    end
  end

  // Driver con skew en milésimas (misma lógica que drive_frame_skew)
  task automatic drive_skew(input logic [7:0] data, input int skew_pm,
                            input int idle_clks);
    int elapsed = 0;
    int boundary;
    int num;
    for (int i = 0; i < 10; i++) begin
      if (i == 0)      rxd = 1'b0;
      else if (i == 9) rxd = 1'b1;
      else             rxd = data[i-1];
      num = (i+1) * CLKS_PER_BIT * (1000 + skew_pm);
      boundary = num / 1000;
      repeat (boundary - elapsed) @(posedge clk);
      elapsed = boundary;
    end
    rxd = 1'b1;
    repeat (idle_clks) @(posedge clk);
  endtask

  logic [7:0] pattern [8];
  int total_ok = 0;
  int total_bad = 0;
  int got_n, errs, ok;

  initial begin
    rst_n = 1'b0;
    tx_data = 8'h00;
    tx_valid = 1'b0;
    rxd = 1'b1;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);

    pattern[0] = 8'h00;
    pattern[1] = 8'hFF;
    pattern[2] = 8'h55;
    pattern[3] = 8'hAA;
    pattern[4] = 8'h80;
    pattern[5] = 8'h01;
    pattern[6] = 8'h7F;
    pattern[7] = 8'hFE;

    for (int skew = -120; skew <= 120; skew += 5) begin
      got_q.delete();
      for (int i = 0; i < 8; i++) begin
        drive_skew(pattern[i], skew, 3*CLKS_PER_BIT);
      end
      repeat (4*CLKS_PER_BIT) @(posedge clk);

      // Compara: exactamente 8 eventos, ninguno de error, datos en orden
      got_n = got_q.size();
      errs = 0;
      ok = 1;
      for (int i = 0; i < got_n; i++) if (got_q[i].err) errs++;
      if (got_n != 8) ok = 0;
      if (errs != 0) ok = 0;
      for (int i = 0; i < got_n && i < 8; i++) begin
        if (got_q[i].err) begin ok = 0; end
        else if (got_q[i].data !== pattern[i]) ok = 0;
      end

      if (ok) total_ok++; else total_bad++;
      $display("SWEEP skew_pm=%0d ok=%0d got=%0d errs=%0d", skew, ok, got_n, errs);
    end

    $display("SWEEP_DONE ok=%0d bad=%0d", total_ok, total_bad);
    $finish;
  end

  // Watchdog
  initial begin
    #500_000_000;
    $display("SWEEP TIMEOUT");
    $finish;
  end

endmodule
