// Minimal UART core: 8N1 transmitter + receiver sharing one baud tick divider.
//   CLKS_PER_BIT = clk frequency / baud rate.
// Host side is a simple valid/ready style handshake:
//   tx_valid & tx_ready -> byte accepted; tx_ready is low while a frame is in flight.
//   rx_valid pulses for one cycle when a frame with a good stop bit was received;
//   rx_frame_err pulses instead of rx_valid when the stop bit was 0; the receiver then
//   waits for the line to go high again before looking for the next start bit.
module uart_core #(
  parameter int CLKS_PER_BIT = 16
) (
  input  logic       clk,
  input  logic       rst_n,
  // TX host side
  input  logic [7:0] tx_data,
  input  logic       tx_valid,
  output logic       tx_ready,
  output logic       txd,
  // RX host side
  input  logic       rxd,
  output logic [7:0] rx_data,
  output logic       rx_valid,
  output logic       rx_frame_err
);
  localparam int CW = $clog2(CLKS_PER_BIT);

  // ---------------- transmitter ----------------
  typedef enum logic [1:0] {TX_IDLE, TX_START, TX_DATA, TX_STOP} tx_state_t;
  tx_state_t     tx_state;
  logic [CW-1:0] tx_cnt;
  logic [2:0]    tx_bit;
  logic [7:0]    tx_shift;

  assign tx_ready = (tx_state == TX_IDLE);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_state <= TX_IDLE; txd <= 1'b1; tx_cnt <= '0; tx_bit <= '0; tx_shift <= '0;
    end else begin
      case (tx_state)
        TX_IDLE: begin
          txd <= 1'b1;
          if (tx_valid) begin
            tx_shift <= tx_data; tx_cnt <= '0; tx_state <= TX_START; txd <= 1'b0;
          end
        end
        TX_START: begin
          if (tx_cnt == CLKS_PER_BIT-1) begin
            tx_cnt <= '0; tx_bit <= '0; tx_state <= TX_DATA; txd <= tx_shift[0];
          end else tx_cnt <= tx_cnt + 1'b1;
        end
        TX_DATA: begin
          if (tx_cnt == CLKS_PER_BIT-1) begin
            tx_cnt <= '0;
            if (tx_bit == 3'd7) begin tx_state <= TX_STOP; txd <= 1'b1; end
            else begin tx_bit <= tx_bit + 1'b1; txd <= tx_shift[tx_bit + 1'b1]; end
          end else tx_cnt <= tx_cnt + 1'b1;
        end
        TX_STOP: begin
          if (tx_cnt == CLKS_PER_BIT-1) begin tx_cnt <= '0; tx_state <= TX_IDLE; end
          else tx_cnt <= tx_cnt + 1'b1;
        end
      endcase
    end
  end

  // ---------------- receiver ----------------
  typedef enum logic [2:0] {RX_IDLE, RX_START, RX_DATA, RX_STOP, RX_RECOVER} rx_state_t;
  rx_state_t     rx_state;
  logic [CW-1:0] rx_cnt;
  logic [2:0]    rx_bit;
  logic [7:0]    rx_shift;
  logic          rxd_s1, rxd_s2;         // 2-flop synchronizer

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin rxd_s1 <= 1'b1; rxd_s2 <= 1'b1; end
    else begin rxd_s1 <= rxd; rxd_s2 <= rxd_s1; end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_state <= RX_IDLE; rx_cnt <= '0; rx_bit <= '0; rx_shift <= '0;
      rx_data <= '0; rx_valid <= 1'b0; rx_frame_err <= 1'b0;
    end else begin
      rx_valid <= 1'b0; rx_frame_err <= 1'b0;
      case (rx_state)
        RX_IDLE:  if (!rxd_s2) begin rx_cnt <= '0; rx_state <= RX_START; end
        RX_START: begin  // sample in the middle of the start bit to reject glitches
          if (rx_cnt == (CLKS_PER_BIT/2)-1) begin
            rx_cnt <= '0;
            if (!rxd_s2) begin rx_bit <= '0; rx_state <= RX_DATA; end
            else rx_state <= RX_IDLE;
          end else rx_cnt <= rx_cnt + 1'b1;
        end
        RX_DATA: begin
          if (rx_cnt == CLKS_PER_BIT-1) begin
            rx_cnt <= '0;
            rx_shift[rx_bit] <= rxd_s2;
            if (rx_bit == 3'd7) rx_state <= RX_STOP; else rx_bit <= rx_bit + 1'b1;
          end else rx_cnt <= rx_cnt + 1'b1;
        end
        RX_STOP: begin
          if (rx_cnt == CLKS_PER_BIT-1) begin
            rx_cnt <= '0;
            if (rxd_s2) begin rx_data <= rx_shift; rx_valid <= 1'b1; rx_state <= RX_IDLE; end
            else begin rx_frame_err <= 1'b1; rx_state <= RX_RECOVER; end
          end else rx_cnt <= rx_cnt + 1'b1;
        end
        // After a framing error, wait for the line to return to idle (high) so the
        // remaining low time of the bad stop bit is not mistaken for a new start bit.
        RX_RECOVER: if (rxd_s2) rx_state <= RX_IDLE;
      endcase
    end
  end
endmodule
