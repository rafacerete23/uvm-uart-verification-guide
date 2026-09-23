`timescale 1ns/1ps
module tb_selfcheck;
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

  // Sample DUT outputs at posedge (before NBA updates).
  // Drive DUT inputs with blocking assignments 1 ns after posedge.

  typedef struct { logic [7:0] data; logic err; } rx_ev_t;

  logic [7:0] sent_q [$];
  logic [7:0] line_q [$];
  rx_ev_t exp_q [$];
  rx_ev_t got_q [$];

  int err_count = 0;
  int err_lines = 0;
  int tx_bytes = 0;
  int rx_frames = 0;
  int rx_errs = 0;
  int glitches = 0;
  int skew_frames = 0;

  task automatic report_err(string msg);
    err_count++;
    if (err_lines < 20) begin
      $display("ERROR @%0t: %s", $time, msg);
      err_lines++;
    end
  endtask

  // ---- TX monitor: decode txd ----
  // Wait for falling edge, then sample at mid-bit every CLKS_PER_BIT clocks.
  // Frame duration check: from falling edge to return-to-idle sample = 10*CLKS_PER_BIT.
  int tx_frame_count = 0;
  int tx_frame_dur_last = 0;
  int tx_frame_dur_bad = 0;

  initial begin : tx_monitor
    logic [7:0] b;
    int cyc;
    forever begin
      // wait for falling edge (start bit)
      @(posedge clk);
      while (txd !== 1'b0) @(posedge clk);
      // now at posedge where txd==0 (start bit just appeared)
      // sample start at mid-bit: wait CLKS_PER_BIT/2 clocks
      cyc = 0;
      repeat (CLKS_PER_BIT/2) begin @(posedge clk); cyc++; end
      if (txd !== 1'b0) report_err($sformatf("TX start bit not 0 at mid (got %b)", txd));
      // sample 8 data bits LSB first
      for (int i = 0; i < 8; i++) begin
        repeat (CLKS_PER_BIT) begin @(posedge clk); cyc++; end
        b[i] = txd;
      end
      // stop bit
      repeat (CLKS_PER_BIT) begin @(posedge clk); cyc++; end
      if (txd !== 1'b1) report_err($sformatf("TX stop bit not 1 (got %b)", txd));
      line_q.push_back(b);
      tx_frame_count++;
      tx_frame_dur_last = cyc;
      // Falling edge -> mid-stop-bit sample is CLKS_PER_BIT/2 + 9*CLKS_PER_BIT clocks
      // (half a start bit, 8 data bits and 1 stop bit); any deviation means a wrong bit period.
      if (cyc != CLKS_PER_BIT/2 + 9*CLKS_PER_BIT) begin
        tx_frame_dur_bad++;
        report_err($sformatf("TX frame timing %0d != %0d", cyc, CLKS_PER_BIT/2 + 9*CLKS_PER_BIT));
      end
    end
  end

  // ---- TX accepted-byte recorder ----
  initial begin : tx_accepted
    forever begin
      @(posedge clk);
      if (tx_valid && tx_ready) begin
        sent_q.push_back(tx_data);
      end
    end
  end

  // ---- RX monitor ----
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

  // ---- TX driver ----
  task automatic send_byte(input logic [7:0] b);
    // wait until tx_ready high at posedge
    @(posedge clk);
    while (!tx_ready) @(posedge clk);
    // drive 1ns after posedge
    #1;
    tx_data = b;
    tx_valid = 1'b1;
    // hold for one accepting edge
    @(posedge clk);
    #1;
    tx_valid = 1'b0;
    tx_bytes++;
  endtask

  // ---- RX driver ----
  task automatic drive_frame(input logic [7:0] data, input bit bad_stop,
                             input int idle_clks, input bit glitch);
    // optional glitch: low for CLKS_PER_BIT/4 clocks, then idle high >= CLKS_PER_BIT
    if (glitch) begin
      glitches++;
      rxd = 1'b0;
      repeat (CLKS_PER_BIT/4) @(posedge clk);
      rxd = 1'b1;
      repeat (CLKS_PER_BIT) @(posedge clk);
    end
    // start bit
    rxd = 1'b0;
    repeat (CLKS_PER_BIT) @(posedge clk);
    // data bits LSB first
    for (int i = 0; i < 8; i++) begin
      rxd = data[i];
      repeat (CLKS_PER_BIT) @(posedge clk);
    end
    // stop bit
    rxd = bad_stop ? 1'b0 : 1'b1;
    repeat (CLKS_PER_BIT) @(posedge clk);
    // idle
    rxd = 1'b1;
    repeat (idle_clks) @(posedge clk);

    // push expected event
    if (bad_stop) begin
      rx_ev_t e;
      e.data = 8'hxx;
      e.err = 1'b1;
      exp_q.push_back(e);
      rx_errs++;
    end else begin
      rx_ev_t e;
      e.data = data;
      e.err = 1'b0;
      exp_q.push_back(e);
      rx_frames++;
    end
  endtask

  // ---- RX driver con desviacion de baudrate ----
  // Genera una trama 8N1 con periodo de bit = CLKS_PER_BIT*(1000+skew_pm)/1000.
  // skew_pm en milésimas: +30 => bit 3% más largo (emisor más lento), -30 => más corto.
  // Las fronteras de bit se calculan en ciclos enteros desde el inicio de la trama
  // para no acumular error de redondeo.
  task automatic drive_frame_skew(input logic [7:0] data, input int skew_pm,
                                  input int idle_clks);
    int elapsed = 0;
    int boundary;
    int num;
    // bit 0 = start, 1..8 = datos LSB primero, 9 = stop
    for (int i = 0; i < 10; i++) begin
      if (i == 0)      rxd = 1'b0;          // start
      else if (i == 9) rxd = 1'b1;          // stop
      else             rxd = data[i-1];     // datos LSB primero
      // frontera del bit i (fin del bit i) en ciclos desde el inicio de la trama
      num = (i+1) * CLKS_PER_BIT * (1000 + skew_pm);
      boundary = num / 1000;
      repeat (boundary - elapsed) @(posedge clk);
      elapsed = boundary;
    end
    // idle tras el stop
    rxd = 1'b1;
    repeat (idle_clks) @(posedge clk);

    // evento esperado: trama buena
    begin
      rx_ev_t e;
      e.data = data;
      e.err = 1'b0;
      exp_q.push_back(e);
      rx_frames++;
    end
  endtask

  // ---- Scoreboard ----
  task automatic check_queues();
    if (sent_q.size() != line_q.size()) begin
      report_err($sformatf("TX queue size mismatch: sent=%0d line=%0d",
                           sent_q.size(), line_q.size()));
    end
    for (int i = 0; i < sent_q.size() && i < line_q.size(); i++) begin
      if (sent_q[i] !== line_q[i]) begin
        report_err($sformatf("TX mismatch idx %0d: sent=%02h line=%02h",
                             i, sent_q[i], line_q[i]));
      end
    end
    if (exp_q.size() != got_q.size()) begin
      report_err($sformatf("RX queue size mismatch: exp=%0d got=%0d",
                           exp_q.size(), got_q.size()));
    end
    for (int i = 0; i < exp_q.size() && i < got_q.size(); i++) begin
      if (exp_q[i].err !== got_q[i].err) begin
        report_err($sformatf("RX err mismatch idx %0d: exp=%0d got=%0d",
                             i, exp_q[i].err, got_q[i].err));
      end else if (!exp_q[i].err) begin
        if (exp_q[i].data !== got_q[i].data) begin
          report_err($sformatf("RX data mismatch idx %0d: exp=%02h got=%02h",
                               i, exp_q[i].data, got_q[i].data));
        end
      end
    end
  endtask

  // ---- Main test ----
  logic [7:0] corner_bytes [12];
  logic [7:0] rand_bytes [200];
  logic [7:0] fd_tx [100];
  logic [7:0] fd_rx [100];
  int skew_list [5];

  initial begin
    void'($urandom(2024));

    rst_n = 1'b0;
    tx_data = 8'h00;
    tx_valid = 1'b0;
    rxd = 1'b1;

    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);

    // Corner bytes
    corner_bytes[0] = 8'h00;
    corner_bytes[1] = 8'hFF;
    corner_bytes[2] = 8'h55;
    corner_bytes[3] = 8'hAA;
    for (int i = 0; i < 8; i++) corner_bytes[4+i] = 8'h01 << i;

    // TX corner bytes back-to-back
    for (int i = 0; i < 12; i++) send_byte(corner_bytes[i]);
    // wait for TX to finish
    repeat (12 * 10 * CLKS_PER_BIT + 20) @(posedge clk);

    // TX corner bytes with gaps
    for (int i = 0; i < 12; i++) begin
      send_byte(corner_bytes[i]);
      repeat (5 + (i % 7)) @(posedge clk);
    end
    repeat (12 * 10 * CLKS_PER_BIT + 20) @(posedge clk);

    // RX corner bytes
    for (int i = 0; i < 12; i++) begin
      drive_frame(corner_bytes[i], 1'b0, 2*CLKS_PER_BIT, 1'b0);
    end
    repeat (4) @(posedge clk);

    // 200 random TX bytes with random gaps
    for (int i = 0; i < 200; i++) rand_bytes[i] = 8'($urandom);
    for (int i = 0; i < 200; i++) begin
      send_byte(rand_bytes[i]);
      repeat ($urandom % 31) @(posedge clk);
    end
    repeat (200 * 10 * CLKS_PER_BIT + 40) @(posedge clk);

    // 200 random RX frames, ~10% bad stop, ~5% glitch
    for (int i = 0; i < 200; i++) begin
      logic [7:0] d;
      bit bad;
      bit gl;
      int idle;
      d = 8'($urandom);
      bad = (($urandom % 100) < 10);
      gl = (($urandom % 100) < 5);
      idle = 2*CLKS_PER_BIT + ($urandom % (2*CLKS_PER_BIT));
      drive_frame(d, bad, idle, gl);
    end
    repeat (4) @(posedge clk);

    // Full duplex: 100 random TX bytes and 100 good RX frames concurrently
    for (int i = 0; i < 100; i++) begin
      fd_tx[i] = 8'($urandom);
      fd_rx[i] = 8'($urandom);
    end
    fork
      begin
        for (int i = 0; i < 100; i++) begin
          send_byte(fd_tx[i]);
          repeat ($urandom % 5) @(posedge clk);
        end
      end
      begin
        for (int i = 0; i < 100; i++) begin
          drive_frame(fd_rx[i], 1'b0, 2*CLKS_PER_BIT, 1'b0);
        end
      end
    join
    repeat (100 * 10 * CLKS_PER_BIT + 40) @(posedge clk);

    // Bad stop then good frame recovery
    drive_frame(8'hA5, 1'b1, 2*CLKS_PER_BIT, 1'b0);
    repeat (2) @(posedge clk);
    drive_frame(8'h5A, 1'b0, 2*CLKS_PER_BIT, 1'b0);
    repeat (4) @(posedge clk);

    // Tolerancia de baudrate: tramas con periodo de bit desviado (skew_pm en milesimas).
    // Los valores estan dentro de la ventana medida (aprox. -4.5% .. +6.0%) para CLKS_PER_BIT=16.
    skew_list[0] = -40; skew_list[1] = -25; skew_list[2] = 25; skew_list[3] = 40; skew_list[4] = 55;
    for (int s = 0; s < 5; s++) begin
      for (int i = 0; i < 14; i++) begin
        logic [7:0] d;
        case (i)
          0: d = 8'h00;
          1: d = 8'hFF;
          2: d = 8'h80;
          3: d = 8'h01;
          default: d = 8'($urandom);
        endcase
        drive_frame_skew(d, skew_list[s], 2*CLKS_PER_BIT);
        skew_frames++;
      end
    end
    repeat (4) @(posedge clk);

    // Clase 2: inyeccion de errores - tramas back-to-back (idle_clks=1) con glitch antepuesto
    for (int i = 0; i < 30; i++) begin
      logic [7:0] d;
      d = 8'($urandom);
      drive_frame(d, 1'b0, 1, 1'b1);
    end
    repeat (4) @(posedge clk);

    // Final scoreboard
    check_queues();

    if (err_count == 0) begin
      $display("RESULT: PASS");
    end else begin
      $display("RESULT: FAIL (%0d errors)", err_count);
    end
    $display("SUMMARY: tx_bytes=%0d rx_frames=%0d rx_frame_errs=%0d glitches=%0d skew_frames=%0d",
             tx_bytes, rx_frames, rx_errs, glitches, skew_frames);
    $finish;
  end

  // Watchdog
  initial begin
    #200_000_000;
    $display("RESULT: FAIL (timeout)");
    $finish;
  end

endmodule
