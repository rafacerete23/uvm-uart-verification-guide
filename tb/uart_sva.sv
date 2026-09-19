// uart_sva.sv - Aserciones SVA y cobertura para uart_core (se conecta con bind)
`ifndef UART_SVA_SV
`define UART_SVA_SV

module uart_sva #(
  parameter int CLKS_PER_BIT = 16
) (
  input logic       clk,
  input logic       rst_n,
  input logic       tx_ready,
  input logic       txd,
  input logic       rx_valid,
  input logic       rx_frame_err,
  input logic [1:0] tx_state,
  input logic [2:0] rx_state,
  input logic       rxd_s2
);

  // Codificacion de los enums de uart_core (tx_state_t / rx_state_t)
  localparam logic [1:0] TX_IDLE = 2'd0;
  localparam logic [2:0] RX_IDLE = 3'd0;
  localparam logic [2:0] RX_STOP = 3'd3;

  default clocking cb @(posedge clk);
  endclocking

  // Tras el reset: linea TX en reposo y receptor inactivo
  a_reset_state: assert property ($rose(rst_n) |->
    (txd === 1'b1) && (tx_ready === 1'b1) && (tx_state == TX_IDLE) &&
    (rx_state == RX_IDLE) && !rx_valid && !rx_frame_err);

  // txd alto siempre que el transmisor esta en reposo
  a_txd_idle_high: assert property (disable iff (!rst_n) (tx_state == TX_IDLE) |-> (txd === 1'b1));

  // tx_ready solo en TX_IDLE
  a_tx_ready_idle: assert property (disable iff (!rst_n) tx_ready == (tx_state == TX_IDLE));

  // Forma de la trama TX: start=0 (1 bit), 8 bits de datos, stop=1 (1 bit)
  a_tx_frame_shape: assert property (disable iff (!rst_n)
    ($fell(txd) && $past(tx_state) == TX_IDLE)
      |-> (!txd)[*CLKS_PER_BIT] ##1 (1'b1)[*8*CLKS_PER_BIT] ##1 txd[*CLKS_PER_BIT]);

  // rx_valid solo tras completar el bit de stop
  a_rx_valid_after_stop: assert property (disable iff (!rst_n)
    rx_valid |-> ($past(rx_state) == RX_STOP) && ($past(rxd_s2) === 1'b1));

  // rx_frame_err solo si el bit de stop muestreado fue 0
  a_rx_err_bad_stop: assert property (disable iff (!rst_n)
    rx_frame_err |-> ($past(rx_state) == RX_STOP) && ($past(rxd_s2) === 1'b0));

  // rx_valid y rx_frame_err nunca a la vez
  a_rx_valid_xor_err: assert property (disable iff (!rst_n) !(rx_valid && rx_frame_err));

  // Cobertura
  c_tx_backtoback: cover property (disable iff (!rst_n)
    ($fell(txd) && $past(tx_state) == TX_IDLE)
      ##[10*CLKS_PER_BIT+1 : 10*CLKS_PER_BIT+2]
    ($fell(txd) && $past(tx_state) == TX_IDLE));
  c_framing_error:     cover property (disable iff (!rst_n) rx_frame_err);
  c_tx_while_rx_active: cover property (disable iff (!rst_n) (tx_state != TX_IDLE) && (rx_state != RX_IDLE));

endmodule

bind uart_core uart_sva #(.CLKS_PER_BIT(CLKS_PER_BIT)) uart_sva_inst (.*);

`endif
