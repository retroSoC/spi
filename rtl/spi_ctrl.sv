// Copyright 2017 ETH Zurich and University of Bologna.
//
// -- Adaptable modifications are redistributed under compatible License --
//
// Copyright (c) 2023-2025 Miao Yuchi <miaoyuchi@ict.ac.cn>
// spi is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`define SPI_STD 2'b00
`define SPI_QUAD_TX 2'b01
`define SPI_QUAD_RX 2'b10

module spi_ctrl (
    input  wire        clk,
    input  wire        rstn,
    output reg         eot,
    input  wire [ 7:0] spi_clk_div,
    input  wire        spi_clk_div_valid,
    output reg  [ 6:0] spi_status,
    input  wire [31:0] spi_addr,
    input  wire [ 5:0] spi_addr_len,
    input  wire [31:0] spi_cmd,
    input  wire [ 5:0] spi_cmd_len,
    input  wire [15:0] spi_data_len,
    input  wire [15:0] spi_dummy_rd,
    input  wire [15:0] spi_dummy_wr,
    input  wire [ 3:0] spi_csreg,
    input  wire        spi_swrst,               //FIXME Not used at all
    input  wire        spi_rd,
    input  wire        spi_wr,
    input  wire        spi_qrd,
    input  wire        spi_qwr,
    input  wire [31:0] spi_ctrl_data_tx,
    input  wire        spi_ctrl_data_tx_valid,
    output reg         spi_ctrl_data_tx_ready,
    output wire [31:0] spi_ctrl_data_rx,
    output wire        spi_ctrl_data_rx_valid,
    input  wire        spi_ctrl_data_rx_ready,
    output wire        spi_clk,
    output wire        spi_csn0,
    output wire        spi_csn1,
    output wire        spi_csn2,
    output wire        spi_csn3,
    output reg  [ 1:0] spi_mode,
    output wire        spi_sdo0,
    output wire        spi_sdo1,
    output wire        spi_sdo2,
    output wire        spi_sdo3,
    input  wire        spi_sdi0,
    input  wire        spi_sdi1,
    input  wire        spi_sdi2,
    input  wire        spi_sdi3
);

  localparam [2:0] DATA_NULL = 0;
  localparam [2:0] DATA_EMPTY = 1;
  localparam [2:0] DATA_CMD = 2;
  localparam [2:0] DATA_ADDR = 3;
  localparam [2:0] DATA_FIFO = 4;

  localparam [4:0] IDLE = 0;
  localparam [4:0] CMD = 1;
  localparam [4:0] ADDR = 2;
  localparam [4:0] MODE = 3;
  localparam [4:0] DUMMY = 4;
  localparam [4:0] DATA_TX = 5;
  localparam [4:0] DATA_RX = 6;
  localparam [4:0] WAIT_EDGE = 7;


  wire        spi_rise;
  wire        spi_fall;

  reg         spi_clock_en;

  reg         spi_en_tx;
  reg         spi_en_rx;

  reg  [15:0] counter_tx;
  reg         counter_tx_valid;
  reg  [15:0] counter_rx;
  reg         counter_rx_valid;

  reg  [31:0] data_to_tx;
  reg         data_to_tx_valid;
  wire        data_to_tx_ready;

  wire        en_quad;
  reg         en_quad_int;
  reg         do_tx;  //FIXME NOT USED at all!!
  reg         do_rx;

  wire        tx_done;
  wire        rx_done;

  reg  [ 1:0] s_spi_mode;

  reg         ctrl_data_valid;

  reg         spi_cs;

  wire        tx_clk_en;
  wire        rx_clk_en;

  reg  [ 2:0] ctrl_data_mux;
  reg  [ 4:0] state;
  reg  [ 4:0] state_next;


  assign en_quad = (spi_qrd | spi_qwr) | en_quad_int;

  spi_clkgen u_clkgen (
      .clk_i          (clk),
      .rst_n_i        (rstn),
      .en_i           (spi_clock_en),
      .clk_div_i      (spi_clk_div),
      .clk_div_valid_i(spi_clk_div_valid),
      .spi_clk_o      (spi_clk),
      .spi_fall_o     (spi_fall),
      .spi_rise_o     (spi_rise)
  );

  spi_tx u_txreg (
      .clk           (clk),
      .rstn          (rstn),
      .en            (spi_en_tx),
      .tx_edge       (spi_fall),
      .tx_done       (tx_done),
      .sdo0          (spi_sdo0),
      .sdo1          (spi_sdo1),
      .sdo2          (spi_sdo2),
      .sdo3          (spi_sdo3),
      .en_quad_in    (en_quad),
      .counter_in    (counter_tx),
      .counter_in_upd(counter_tx_valid),
      .data          (data_to_tx),
      .data_valid    (data_to_tx_valid),
      .data_ready    (data_to_tx_ready),
      .clk_en_o      (tx_clk_en)
  );

  spi_rx u_rxreg (
      .clk           (clk),
      .rstn          (rstn),
      .en            (spi_en_rx),
      .rx_edge       (spi_rise),
      .rx_done       (rx_done),
      .sdi0          (spi_sdi0),
      .sdi1          (spi_sdi1),
      .sdi2          (spi_sdi2),
      .sdi3          (spi_sdi3),
      .en_quad_in    (en_quad),
      .counter_in    (counter_rx),
      .counter_in_upd(counter_rx_valid),
      .data          (spi_ctrl_data_rx),
      .data_valid    (spi_ctrl_data_rx_valid),
      .data_ready    (spi_ctrl_data_rx_ready),
      .clk_en_o      (rx_clk_en)
  );

  always @(*) begin
    data_to_tx             = 'h0;
    data_to_tx_valid       = 1'b0;
    spi_ctrl_data_tx_ready = 1'b0;

    case (ctrl_data_mux)
      DATA_NULL: begin
        data_to_tx             = 'b0;
        data_to_tx_valid       = 1'b0;
        spi_ctrl_data_tx_ready = 1'b0;
      end
      DATA_EMPTY: begin
        data_to_tx       = 'b0;
        data_to_tx_valid = 1'b1;
      end
      DATA_CMD: begin
        data_to_tx             = spi_cmd;
        data_to_tx_valid       = ctrl_data_valid;
        spi_ctrl_data_tx_ready = 1'b0;
      end
      DATA_ADDR: begin
        data_to_tx             = spi_addr;
        data_to_tx_valid       = ctrl_data_valid;
        spi_ctrl_data_tx_ready = 1'b0;
      end
      DATA_FIFO: begin
        data_to_tx             = spi_ctrl_data_tx;
        data_to_tx_valid       = spi_ctrl_data_tx_valid;
        spi_ctrl_data_tx_ready = data_to_tx_ready;
      end
    endcase
  end

  always @(*) begin
    spi_cs           = 1'b1;
    spi_clock_en     = 1'b0;
    counter_tx       = 'b0;
    counter_tx_valid = 1'b0;
    counter_rx       = 'b0;
    counter_rx_valid = 1'b0;
    state_next       = state;
    ctrl_data_mux    = DATA_NULL;
    ctrl_data_valid  = 1'b0;
    spi_en_rx        = 1'b0;
    spi_en_tx        = 1'b0;
    spi_status       = 'b0;
    s_spi_mode       = `SPI_QUAD_RX;
    eot              = 1'b0;
    case (state)
      IDLE: begin
        spi_status[0] = 1'b1;
        s_spi_mode    = `SPI_QUAD_RX;

        if (spi_rd || spi_wr || spi_qrd || spi_qwr) begin
          spi_cs       = 1'b0;
          spi_clock_en = 1'b1;

          if (spi_cmd_len != 0) begin
            s_spi_mode       = (spi_qrd | spi_qwr) ? `SPI_QUAD_TX : `SPI_STD;
            counter_tx       = {8'h00, spi_cmd_len};
            counter_tx_valid = 1'b1;
            ctrl_data_mux    = DATA_CMD;
            ctrl_data_valid  = 1'b1;
            spi_en_tx        = 1'b1;
            state_next       = CMD;
          end else if (spi_addr_len != 0) begin
            s_spi_mode       = (spi_qrd | spi_qwr) ? `SPI_QUAD_TX : `SPI_STD;
            counter_tx       = {8'h00, spi_addr_len};
            counter_tx_valid = 1'b1;
            ctrl_data_mux    = DATA_ADDR;
            ctrl_data_valid  = 1'b1;
            spi_en_tx        = 1'b1;
            state_next       = ADDR;
          end else if (spi_data_len != 0)
            if (spi_rd || spi_qrd) begin
              s_spi_mode = (spi_qrd) ? `SPI_QUAD_RX : `SPI_STD;

              if (spi_dummy_rd != 0) begin
                counter_tx       = (en_quad) ? {spi_dummy_rd[13:0], 2'b00} : spi_dummy_rd;
                counter_tx_valid = 1'b1;
                spi_en_tx        = 1'b1;
                ctrl_data_mux    = DATA_EMPTY;
                state_next       = DUMMY;
              end else begin
                counter_rx       = spi_data_len;
                counter_rx_valid = 1'b1;
                spi_en_rx        = 1'b1;
                state_next       = DATA_RX;
              end
            end else begin
              s_spi_mode = (spi_qwr) ? `SPI_QUAD_TX : `SPI_STD;

              if (spi_dummy_wr != 0) begin
                counter_tx       = (en_quad) ? {spi_dummy_wr[13:0], 2'b00} : spi_dummy_wr;
                counter_tx_valid = 1'b1;
                ctrl_data_mux    = DATA_EMPTY;
                spi_en_tx        = 1'b1;
                state_next       = DUMMY;
              end else begin
                counter_tx       = spi_data_len;
                counter_tx_valid = 1'b1;
                ctrl_data_mux    = DATA_FIFO;
                ctrl_data_valid  = 1'b0;
                spi_en_tx        = 1'b1;
                state_next       = DATA_TX;
              end
            end
        end else begin
          spi_cs     = 1'b1;
          state_next = IDLE;
        end
      end
      CMD: begin
        spi_status[1] = 1'b1;
        spi_cs        = 1'b0;
        spi_clock_en  = 1'b1;
        s_spi_mode    = (en_quad) ? `SPI_QUAD_TX : `SPI_STD;

        if (tx_done) begin
          if (spi_addr_len != 0) begin
            s_spi_mode       = (en_quad) ? `SPI_QUAD_TX : `SPI_STD;
            counter_tx       = {8'h00, spi_addr_len};
            counter_tx_valid = 1'b1;
            ctrl_data_mux    = DATA_ADDR;
            ctrl_data_valid  = 1'b1;
            spi_en_tx        = 1'b1;
            state_next       = ADDR;
          end else if (spi_data_len != 0) begin
            if (do_rx) begin
              s_spi_mode = (en_quad) ? `SPI_QUAD_RX : `SPI_STD;
              if (spi_dummy_rd != 0) begin
                counter_tx       = (en_quad) ? {spi_dummy_rd[13:0], 2'b00} : spi_dummy_rd;
                counter_tx_valid = 1'b1;
                spi_en_tx        = 1'b1;
                ctrl_data_mux    = DATA_EMPTY;
                state_next       = DUMMY;
              end else begin
                counter_rx       = spi_data_len;
                counter_rx_valid = 1'b1;
                spi_en_rx        = 1'b1;
                state_next       = DATA_RX;
              end
            end else begin
              s_spi_mode = (en_quad) ? `SPI_QUAD_TX : `SPI_STD;
              if (spi_dummy_wr != 0) begin
                counter_tx       = (en_quad) ? {spi_dummy_wr[13:0], 2'b00} : spi_dummy_wr;
                counter_tx_valid = 1'b1;
                ctrl_data_mux    = DATA_EMPTY;
                spi_en_tx        = 1'b1;
                state_next       = DUMMY;
              end else begin
                counter_tx       = spi_data_len;
                counter_tx_valid = 1'b1;
                ctrl_data_mux    = DATA_FIFO;
                ctrl_data_valid  = 1'b1;
                spi_en_tx        = 1'b1;
                state_next       = DATA_TX;
              end
            end
          end else begin
            state_next = IDLE;
          end
        end else begin
          spi_en_tx  = 1'b1;
          state_next = CMD;
        end
      end
      ADDR: begin
        spi_en_tx     = 1'b1;
        spi_status[2] = 1'b1;
        spi_cs        = 1'b0;
        spi_clock_en  = 1'b1;
        s_spi_mode    = (en_quad) ? `SPI_QUAD_TX : `SPI_STD;
        if (tx_done) begin
          if (spi_data_len != 0) begin
            if (do_rx) begin
              s_spi_mode = (en_quad) ? `SPI_QUAD_RX : `SPI_STD;
              if (spi_dummy_rd != 0) begin
                counter_tx       = (en_quad) ? {spi_dummy_rd[13:0], 2'b00} : spi_dummy_rd;
                counter_tx_valid = 1'b1;
                spi_en_tx        = 1'b1;
                ctrl_data_mux    = DATA_EMPTY;
                state_next       = DUMMY;
              end else begin
                counter_rx       = spi_data_len;
                counter_rx_valid = 1'b1;
                spi_en_rx        = 1'b1;
                state_next       = DATA_RX;
              end
            end else begin
              s_spi_mode = (en_quad) ? `SPI_QUAD_TX : `SPI_STD;
              spi_en_tx  = 1'b1;

              if (spi_dummy_wr != 0) begin
                counter_tx       = (en_quad) ? {spi_dummy_wr[13:0], 2'b00} : spi_dummy_wr;
                counter_tx_valid = 1'b1;
                ctrl_data_mux    = DATA_EMPTY;
                state_next       = DUMMY;
              end else begin
                counter_tx       = spi_data_len;
                counter_tx_valid = 1'b1;
                ctrl_data_mux    = DATA_FIFO;
                ctrl_data_valid  = 1'b1;
                state_next       = DATA_TX;
              end
            end
          end else begin
            state_next = IDLE;
          end
        end
      end
      MODE: begin
        spi_status[3] = 1'b1;
        spi_cs        = 1'b0;
        spi_clock_en  = 1'b1;
        spi_en_tx     = 1'b1;
      end
      DUMMY: begin
        spi_en_tx     = 1'b1;
        spi_status[4] = 1'b1;
        spi_cs        = 1'b0;
        spi_clock_en  = 1'b1;
        s_spi_mode    = (en_quad) ? `SPI_QUAD_RX : `SPI_STD;

        if (tx_done) begin
          if (spi_data_len != 0) begin
            if (do_rx) begin
              counter_rx       = spi_data_len;
              counter_rx_valid = 1'b1;
              spi_en_rx        = 1'b1;
              state_next       = DATA_RX;
            end else begin
              counter_tx       = spi_data_len;
              counter_tx_valid = 1'b1;
              s_spi_mode       = (en_quad) ? `SPI_QUAD_TX : `SPI_STD;
              spi_clock_en     = tx_clk_en;
              spi_en_tx        = 1'b1;
              state_next       = DATA_TX;
            end
          end else begin
            eot        = 1'b1;
            state_next = IDLE;
          end
        end else begin
          ctrl_data_mux = DATA_EMPTY;
          spi_en_tx     = 1'b1;
          state_next    = DUMMY;
        end
      end
      DATA_TX: begin
        spi_status[5]   = 1'b1;
        spi_cs          = 1'b0;
        spi_clock_en    = tx_clk_en;
        ctrl_data_mux   = DATA_FIFO;
        ctrl_data_valid = 1'b1;
        spi_en_tx       = 1'b1;
        s_spi_mode      = (en_quad) ? `SPI_QUAD_TX : `SPI_STD;

        if (tx_done) begin
          eot          = 1'b1;
          state_next   = IDLE;
          spi_clock_en = 1'b0;
        end else begin
          state_next = DATA_TX;
        end
      end
      DATA_RX: begin
        spi_status[6] = 1'b1;
        spi_cs        = 1'b0;
        spi_clock_en  = rx_clk_en;
        s_spi_mode    = (en_quad) ? `SPI_QUAD_RX : `SPI_STD;

        if (rx_done) begin
          state_next = WAIT_EDGE;
        end else begin
          spi_en_rx  = 1'b1;
          state_next = DATA_RX;
        end
      end
      WAIT_EDGE: begin
        spi_status[6] = 1'b1;
        spi_cs        = 1'b0;
        spi_clock_en  = 1'b0;
        s_spi_mode    = (en_quad) ? `SPI_QUAD_RX : `SPI_STD;

        if (spi_fall) begin
          eot        = 1'b1;
          state_next = IDLE;
        end else begin
          state_next = WAIT_EDGE;
        end
      end
    endcase
  end


  always @(posedge clk or negedge rstn) begin
    if (rstn == 1'b0) begin
      state       <= IDLE;
      en_quad_int <= 1'b0;
      do_rx       <= 1'b0;
      do_tx       <= 1'b0;
      spi_mode    <= `SPI_QUAD_RX;
    end else begin
      state    <= state_next;
      spi_mode <= s_spi_mode;

      if (spi_qrd || spi_qwr) en_quad_int <= 1'b1;
      else if (state_next == IDLE) en_quad_int <= 1'b0;

      if (spi_rd || spi_qrd) begin
        do_rx <= 1'b1;
        do_tx <= 1'b0;
      end else if (spi_wr || spi_qwr) begin
        do_rx <= 1'b0;
        do_tx <= 1'b1;
      end else if (state_next == IDLE) begin
        do_rx <= 1'b0;
        do_tx <= 1'b0;
      end
    end
  end

  assign spi_csn0 = ~spi_csreg[0] | spi_cs;
  assign spi_csn1 = ~spi_csreg[1] | spi_cs;
  assign spi_csn2 = ~spi_csreg[2] | spi_cs;
  assign spi_csn3 = ~spi_csreg[3] | spi_cs;

endmodule
