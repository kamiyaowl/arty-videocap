`default_nettype none
`timescale 1 ps / 1 ps

module CAPTURE #(
  parameter [4-1:0] RX_INV  = 4'b0110,
  parameter [4-1:0] TX_INV  = 4'b1100
) (
  input   wire            clk_src_raw,  // 100MHz
  input   wire            rst_raw_n,

  output  wire[4-1:0]     tmds_tx_p,
  output  wire[4-1:0]     tmds_tx_n,
  input   wire[4-1:0]     tmds_rx_p,
  input   wire[4-1:0]     tmds_rx_n,

  output  wire[3-1:0]     led0,     // RGB LEDs
  output  wire[3-1:0]     led1,     // RGB LEDs
  output  wire[3-1:0]     led2,     // RGB LEDs
  output  wire[3-1:0]     led3,     // RGB LEDs
  output  wire[7:4]       led,      // LEDs LD4-7
  input   wire[4-1:0]     btn,
  input   wire[4-1:0]     sw,

  inout   wire            eth_mdio,
  output  wire            eth_mdc,
  output  wire            eth_rstn,
  output  wire[4-1:0]     eth_tx_d,
  output  wire            eth_tx_en,
  input   wire            eth_tx_clk,
  input   wire[4-1:0]     eth_rx_d,
  input   wire            eth_rx_err,
  input   wire            eth_rx_dv,
  input   wire            eth_rx_clk,
  input   wire            eth_col,
  input   wire            eth_crs,
  output  wire            eth_ref_clk
);

wire  clk100;
BUFG bufg_des(.I(clk_src_raw), .O(clk100));

localparam[10-1:0]
  CTLTKN0 = 10'b1101010100,
  CTLTKN1 = 10'b0010101011,
  CTLTKN2 = 10'b0101010100,
  CTLTKN3 = 10'b1010101011,
  START0  = 10'b1011001100;

// TMDS pass through
wire            clk, rst, valid;
wire[30-1:0]    data;
PASS_THROUGH #(.RX_INV(RX_INV), .TX_INV(TX_INV)) pt (
  .clk_src_raw(clk100),
  .rst_raw_n(rst_raw_n),

  .tmds_tx_p(tmds_tx_p),
  .tmds_tx_n(tmds_tx_n),
  .tmds_rx_p(tmds_rx_p),
  .tmds_rx_n(tmds_rx_n),

  .led0(led0), .led1(led1),
  .led2(led2), .led3(led3),
  .led(led), .btn(btn), .sw(sw),

  .clk_data(clk),
  .rst_data(rst),
  .valid_data(valid),
  .data(data)
);

wire
  c0  = data[0+:10] == CTLTKN0,
  c1  = data[0+:10] == CTLTKN1,
  c2  = data[0+:10] == CTLTKN2,
  c3  = data[0+:10] == CTLTKN3,
  s0  = data[0+:10] == START0,
  vd  = c0 | c1,  // vsync deassert
  va  = c2 | c3;  // vcync assert
wire[24-1:0]  ycbcr;
DECODER dec [0:3-1] (.clk(clk), .rst(rst), .D(data), .Q(ycbcr));

reg           pvalid, vsync, frame_mask, rpvalid, rvsync;
reg [1:0]     pvalid_assert;
reg [24-1:0]  rycbcr;
always @(posedge clk) begin
  if(rst) begin
    {pvalid, vsync, frame_mask, pvalid_assert} <= 0;
  end else begin
    pvalid_assert <= {pvalid_assert[0], s0};
    pvalid  <=
      (c0 | c1 | c2 | c3) ? 1'b0 :
      &pvalid_assert      ? 1'b1 : pvalid;
    vsync   <=
      vd ? 1'b0 :
      va ? 1'b1 : vsync;

    // make frame rate half
    if(!vsync && va) frame_mask <= 1'b1;//FIXME: ~frame_mask; // posedge vsync
  end

  rpvalid <= pvalid & frame_mask;
  rvsync  <= vsync  & frame_mask;
  rycbcr  <= ycbcr;
end

(* keep = "true" *)
wire        jvalid;
(* keep = "true" *)
wire[8-1:0] jpeg;
MJPG_ENCODER me (
  .clk(clk),
  .rst(rst),

  .pvalid(rpvalid),
  .vsync(rvsync),
  .ycbcr(rycbcr),

  .jvalid(jvalid),
  .jpeg(jpeg)
);


wire          clk_eth;
wire          start_send, nibble_valid, nibble_user_data, with_usr_valid;
wire[3:0]     nibble, with_usr;
BRIDGE_ENC2ETH be2e (
  .enc_clk(clk),
  .rst(rst),
  .enqueue(jvalid),
  .jpeg(jpeg),

  .eth_clk(clk_eth),
  .start_send(start_send),
  .nibble(nibble),
  .nibble_user_data(nibble_user_data),
  .nibble_valid(nibble_valid),
  .with_usr(with_usr),
  .with_usr_valid(with_usr_valid)
);

ethernet_test et (
  .CLK100MHZ(clk100),

  .eth_mdio(eth_mdio),
  .eth_mdc(eth_mdc),
  .eth_rstn(eth_rstn),
  .eth_tx_d(eth_tx_d),
  .eth_tx_en(eth_tx_en),
  .eth_tx_clk(eth_tx_clk),
  .eth_rx_d(eth_rx_d),
  .eth_rx_err(eth_rx_err),
  .eth_rx_dv(eth_rx_dv),
  .eth_rx_clk(eth_rx_clk),
  .eth_col(eth_col),
  .eth_crs(eth_crs),
  .eth_ref_clk(eth_ref_clk),

  .start_sending(start_send),
  .nibble_clk(clk_eth),
  .nibble(nibble),
  .nibble_user_data(nibble_user_data),
  .nibble_valid(nibble_valid),
  .with_usr(with_usr),
  .with_usr_valid(with_usr_valid)
);

// debug
(* keep = "true" *)
reg [32-1:0]  dbg_data;
always @(posedge clk_eth) if(with_usr_valid)
  dbg_data <= {with_usr, dbg_data[4+:28]};

endmodule

`default_nettype wire

