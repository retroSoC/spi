// Copyright (c) 2023-2024 Miao Yuchi <miaoyuchi@ict.ac.cn>
// spi is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "shift_reg.sv"
`include "edge_det.sv"
`include "clk_int_div.sv"
`include "spi_define.sv"

module spi_core #(
    parameter int FIFO_DEPTH = 64
) (
    input  logic                    clk_i,
    input  logic                    rst_n_i,
    input  logic                    en_i,
    input  logic [             3:0] nss_i,
    input  logic [             3:0] csv_i,
    input  logic                    ass_i,
    input  logic                    lsb_i,
    input  logic                    st_i,
    input  logic                    rwm_i,
    input  logic [             1:0] cmode_i,
    input  logic [             1:0] amode_i,
    input  logic [             1:0] asize_i,
    input  logic [             1:0] almode_i,
    input  logic [             1:0] alsize_i,
    input  logic [             1:0] dmode_i,
    input  logic [             1:0] dsize_i,
    input  logic [             7:0] recy_i,
    input  logic [             1:0] tcsp_i,
    input  logic [             1:0] tchd_i,
    input  logic [             7:0] cmd_i,
    input  logic [            31:0] addr_i,
    input  logic [            31:0] altr_i,
    input  logic [             9:0] nop_i,
    input  logic [             9:0] trl_i,
    input  logic                    cpol_i,
    input  logic                    cpha_i,
    input  logic [             7:0] div_i,
    output logic                    busy_o,
    output logic                    last_o,
    input  logic                    tx_valid_i,
    output logic                    tx_ready_o,
    input  logic [             7:0] tx_data_i,
    output logic                    rx_valid_o,
    input  logic                    rx_ready_i,
    output logic [             7:0] rx_data_o,
    output logic                    spi_sck_o,
    output logic [`SPI_NSS_NUM-1:0] spi_nss_o,
    output logic [             3:0] spi_io_en_o,
    input  logic [             3:0] spi_io_in_i,
    output logic [             3:0] spi_io_out_o
);


  logic [3:0] s_nss_sel;
  // fsm
  logic [3:0] s_fsm_state_d, s_fsm_state_q;
  logic [9:0] s_fsm_cnt_d, s_fsm_cnt_q;
  logic s_ce_fsm_low_bound, s_ce_fsm_high_bound;
  logic s_xfer_flag;
  logic [7:0] s_sg_bit_cnt_d, s_sg_bit_cnt_q;
  // clk
  logic [7:0] s_div_val, s_clk_cnt;
  logic s_spi_clk, s_clk_fir_edge_trg, s_clk_sec_edge_trg;
  // tx data
  logic       s_xfer_trg;
  logic       s_tx_shift_1_dat;
  logic [1:0] s_tx_shift_2_dat;
  logic [3:0] s_tx_shift_4_dat;
  // xfer
  logic [7:0] s_xfer_cmd_d, s_xfer_cmd_q;
  logic [31:0] s_xfer_addr_d, s_xfer_addr_q;
  logic [31:0] s_xfer_altr_d, s_xfer_altr_q;
  logic [7:0] s_xfer_wr_data_d, s_xfer_wr_data_q;

  // assign
  assign s_ce_fsm_low_bound  = s_fsm_state_q > `SPI_FSM_TCSP;
  assign s_ce_fsm_high_bound = s_fsm_state_q < `SPI_FSM_TCHD;

  assign busy_o              = ~(s_fsm_state_q == `SPI_FSM_IDLE);
  assign tx_ready_o          = busy_o;  // TODO: only in data phase
  assign rx_valid_o          = busy_o;  // TODO: only in data phase
  assign rx_data_o           = '0;

  // software nss ctrl is more flexible
  assign s_xfer_flag         = ~(s_fsm_state_q == `SPI_FSM_IDLE || s_fsm_state_q == `SPI_FSM_RECY);
  assign s_nss_sel           = (nss_i & {4{s_xfer_flag & ass_i}}) | (nss_i & {4{~ass_i}});
  assign spi_nss_o           = ~(s_nss_sel[`SPI_NSS_NUM-1:0] ^ csv_i[`SPI_NSS_NUM-1:0]);
  assign spi_sck_o           = s_ce_fsm_low_bound && s_ce_fsm_high_bound ? s_spi_clk : cpol_i;

  always_comb begin
    s_div_val = 8'd1;
    unique case (div_i)
      `SPI_PSCR_DIV2:  s_div_val = 8'd1;
      `SPI_PSCR_DIV4:  s_div_val = 8'd3;
      `SPI_PSCR_DIV8:  s_div_val = 8'd7;
      `SPI_PSCR_DIV16: s_div_val = 8'd15;
      `SPI_PSCR_DIV32: s_div_val = 8'd31;
      default:         s_div_val = 8'd1;
    endcase
  end
  // when div_valid_i == 1, inter cnt reg will set to '0'
  clk_int_div_simple #(
      .DIV_VALUE_WIDTH (8),
      .DONE_DELAY_WIDTH(3)
  ) u_clk_int_div_simple (
      .clk_i        (clk_i),
      .rst_n_i      (rst_n_i),
      .div_i        (s_div_val),
      .clk_init_i   (cpol_i),
      .div_valid_i  (~s_xfer_flag),
      .div_ready_o  (),
      .div_done_o   (),
      .clk_cnt_o    (s_clk_cnt),
      .clk_fir_trg_o(s_clk_fir_edge_trg),
      .clk_sec_trg_o(s_clk_sec_edge_trg),
      .clk_o        (s_spi_clk)
  );

  // 1. delay some cycles to meet tCSP at negedge of ce
  // 2. align the first posedge of spi_sck when ce == 0
  // 3. delay some cycles to meet tCHD at posedge of ce
  // std(mode1): 8 dul(mode2): 4 quad(mod3): 2
  always_comb begin
    s_fsm_state_d = s_fsm_state_q;
    s_fsm_cnt_d   = s_fsm_cnt_q;
    unique case (s_fsm_state_q)
      `SPI_FSM_IDLE: begin
        if (st_i) begin
          s_fsm_state_d = `SPI_FSM_TCSP;
          s_fsm_cnt_d   = {8'd0, tcsp_i};
        end
      end
      `SPI_FSM_TCSP: begin
        if (s_fsm_cnt_q == '0) begin
          if (cmode_i != `SPI_MODE_SKIP) begin
            s_fsm_state_d = `SPI_FSM_CMD;
            s_fsm_cnt_d   = 10'd1;
          end else if (amode_i != `SPI_MODE_SKIP) begin
            s_fsm_state_d = `SPI_FSM_ADDR;
            s_fsm_cnt_d   = {8'd0, asize_i + 2'd1};
          end else if (almode_i != `SPI_MODE_SKIP) begin
            s_fsm_state_d = `SPI_FSM_ALTR;
            s_fsm_cnt_d   = {8'd0, alsize_i + 2'd1};
          end else if (nop_i != '0) begin
            s_fsm_state_d = `SPI_FSM_NOP;
            s_fsm_cnt_d   = nop_i;
          end else if (dmode_i != `SPI_MODE_SKIP) begin
            if (rwm_i) s_fsm_state_d = `SPI_FSM_RDATA;
            else s_fsm_state_d = `SPI_FSM_WDATA;
            s_fsm_cnt_d = trl_i;
          end else s_fsm_state_d = `SPI_FSM_TCHD;
        end else begin
          if (s_clk_sec_edge_trg) s_fsm_cnt_d = s_fsm_cnt_q - 1'b1;
        end
      end
      `SPI_FSM_CMD: begin
        if (s_fsm_cnt_q == '0) begin
          if (amode_i != `SPI_MODE_SKIP) begin
            s_fsm_state_d = `SPI_FSM_ADDR;
            s_fsm_cnt_d   = {8'd0, asize_i + 2'd1};
          end else if (almode_i != `SPI_MODE_SKIP) begin
            s_fsm_state_d = `SPI_FSM_ALTR;
            s_fsm_cnt_d   = {8'd0, alsize_i + 2'd1};
          end else if (nop_i != '0) begin
            s_fsm_state_d = `SPI_FSM_NOP;
            s_fsm_cnt_d   = nop_i;
          end else if (dmode_i != `SPI_MODE_SKIP) begin
            if (rwm_i) s_fsm_state_d = `SPI_FSM_RDATA;
            else s_fsm_state_d = `SPI_FSM_WDATA;
            s_fsm_cnt_d = trl_i;
          end else s_fsm_state_d = `SPI_FSM_TCHD;
        end else begin
          if (s_sg_bit_cnt_q == 8'd7) s_fsm_cnt_d = s_fsm_cnt_q - 1'b1;
        end
      end
      `SPI_FSM_ADDR: begin
        if (s_fsm_cnt_q == '0) begin
          if (almode_i != `SPI_MODE_SKIP) begin
            s_fsm_state_d = `SPI_FSM_ALTR;
            s_fsm_cnt_d   = {8'd0, alsize_i + 2'd1};
          end else if (nop_i != '0) begin
            s_fsm_state_d = `SPI_FSM_NOP;
            s_fsm_cnt_d   = nop_i;
          end else if (dmode_i != `SPI_MODE_SKIP) begin
            if (rwm_i) s_fsm_state_d = `SPI_FSM_RDATA;
            else s_fsm_state_d = `SPI_FSM_WDATA;
            s_fsm_cnt_d = trl_i;
          end else s_fsm_state_d = `SPI_FSM_TCHD;
        end else begin
          if (s_sg_bit_cnt_q == 8'd7) s_fsm_cnt_d = s_fsm_cnt_q - 1'b1;
        end
      end
      `SPI_FSM_ALTR: begin
        if (s_fsm_cnt_q == '0) begin
          if (nop_i != '0) begin
            s_fsm_state_d = `SPI_FSM_NOP;
            s_fsm_cnt_d   = nop_i;
          end else if (dmode_i != `SPI_MODE_SKIP) begin
            if (rwm_i) s_fsm_state_d = `SPI_FSM_RDATA;
            else s_fsm_state_d = `SPI_FSM_WDATA;
            s_fsm_cnt_d = trl_i;
          end else s_fsm_state_d = `SPI_FSM_TCHD;
        end else begin
          if (s_sg_bit_cnt_q == 8'd7) s_fsm_cnt_d = s_fsm_cnt_q - 1'b1;
        end
      end
      `SPI_FSM_NOP: begin
        if (s_fsm_cnt_q == '0) begin
          if (dmode_i != `SPI_MODE_SKIP) begin
            if (rwm_i) s_fsm_state_d = `SPI_FSM_RDATA;
            else s_fsm_state_d = `SPI_FSM_WDATA;
            s_fsm_cnt_d = trl_i;
          end else s_fsm_state_d = `SPI_FSM_TCHD;
        end else begin
          if (s_sg_bit_cnt_q == 8'd7) s_fsm_cnt_d = s_fsm_cnt_q - 1'b1;
        end
      end
      `SPI_FSM_WDATA: begin
        if (s_fsm_cnt_q == '0) begin
          s_fsm_state_d = `SPI_FSM_TCHD;
          s_fsm_cnt_d   = tchd_i;
        end else begin
          if (s_sg_bit_cnt_q == 8'd7) s_fsm_cnt_d = s_fsm_cnt_q - 1'b1;
        end
      end
      `SPI_FSM_RDATA: begin
        if (s_fsm_cnt_q == '0) begin
          s_fsm_state_d = `SPI_FSM_TCHD;
          s_fsm_cnt_d   = tchd_i;
        end else begin
          if (s_sg_bit_cnt_q == 8'd7) s_fsm_cnt_d = s_fsm_cnt_q - 1'b1;
        end
      end
      `SPI_FSM_TCHD: begin
        if (s_fsm_cnt_q == '0) begin
          s_fsm_state_d = `SPI_FSM_RECY;
          s_fsm_cnt_d   = recy_i;
        end else begin
          if (s_sg_bit_cnt_q == 8'd7) s_fsm_cnt_d = s_fsm_cnt_q - 1'b1;
        end
      end
      `SPI_FSM_RECY: begin
        if (s_fsm_cnt_q == '0) begin
          s_fsm_state_d = `SPI_FSM_IDLE;
          s_fsm_cnt_d   = '1;
        end else begin
          if (s_sg_bit_cnt_q == 8'd7) s_fsm_cnt_d = s_fsm_cnt_q - 1'b1;
        end
      end
      default: begin
        s_fsm_state_d = `SPI_FSM_IDLE;
        s_fsm_cnt_d   = '1;
      end
    endcase
  end
  dffr #(4) u_fsm_state_dffr (
      clk_i,
      rst_n_i,
      s_fsm_state_d,
      s_fsm_state_q
  );


  dffrh #(10) u_fsm_cnt_dffrh (
      clk_i,
      rst_n_i,
      s_fsm_cnt_d,
      s_fsm_cnt_q
  );


  always_comb begin
    spi_io_en_o  = '0;
    spi_io_out_o = '0;
    unique case (s_fsm_state_q)
      `SPI_FSM_IDLE: begin
        spi_io_en_o  = '0;
        spi_io_out_o = '0;
      end
      `SPI_FSM_CMD: begin
        unique case (cmode_i)
          `SPI_MODE_STD_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1_dat;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_MODE_DUAL_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_2_dat[0];
            spi_io_out_o[1] = s_tx_shift_2_dat[1];
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_MODE_QUAD_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_4_dat[0];
            spi_io_out_o[1] = s_tx_shift_4_dat[1];
            spi_io_out_o[2] = s_tx_shift_4_dat[2];
            spi_io_out_o[3] = s_tx_shift_4_dat[3];
          end
          default: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1_dat;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
        endcase
      end
      `SPI_FSM_ADDR: begin
        unique case (amode_i)
          `SPI_MODE_STD_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1_dat;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_MODE_DUAL_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_2_dat[0];
            spi_io_out_o[1] = s_tx_shift_2_dat[1];
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_MODE_QUAD_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_4_dat[0];
            spi_io_out_o[1] = s_tx_shift_4_dat[1];
            spi_io_out_o[2] = s_tx_shift_4_dat[2];
            spi_io_out_o[3] = s_tx_shift_4_dat[3];
          end
          default: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1_dat;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
        endcase
      end
      `SPI_FSM_ALTR: begin
        unique case (almode_i)
          `SPI_MODE_STD_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1_dat;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_MODE_DUAL_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_2_dat[0];
            spi_io_out_o[1] = s_tx_shift_2_dat[1];
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_MODE_QUAD_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_4_dat[0];
            spi_io_out_o[1] = s_tx_shift_4_dat[1];
            spi_io_out_o[2] = s_tx_shift_4_dat[2];
            spi_io_out_o[3] = s_tx_shift_4_dat[3];
          end
          default: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1_dat;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
        endcase
      end
      `SPI_FSM_NOP: begin
        spi_io_en_o  = '1;
        spi_io_out_o = '0;
      end
      `SPI_FSM_WDATA: begin
        unique case (dmode_i)
          `SPI_MODE_STD_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1_dat;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_MODE_DUAL_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_2_dat[0];
            spi_io_out_o[1] = s_tx_shift_2_dat[1];
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_MODE_QUAD_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b1;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_4_dat[0];
            spi_io_out_o[1] = s_tx_shift_4_dat[1];
            spi_io_out_o[2] = s_tx_shift_4_dat[2];
            spi_io_out_o[3] = s_tx_shift_4_dat[3];
          end
          default: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1_dat;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
        endcase
      end
      `SPI_FSM_RDATA: begin
        unique case (dmode_i)
          `SPI_MODE_STD_SPI: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1_dat;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_MODE_DUAL_SPI: begin
            spi_io_en_o[0]  = 1'b0;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = 1'b0;
            spi_io_out_o[1] = 1'b0;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
          `SPI_MODE_QUAD_SPI: begin
            spi_io_en_o[0]  = 1'b0;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b0;
            spi_io_en_o[3]  = 1'b0;
            spi_io_out_o[0] = 1'b0;
            spi_io_out_o[1] = 1'b0;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b0;
          end
          default: begin
            spi_io_en_o[0]  = 1'b1;
            spi_io_en_o[1]  = 1'b0;
            spi_io_en_o[2]  = 1'b1;
            spi_io_en_o[3]  = 1'b1;
            spi_io_out_o[0] = s_tx_shift_1_dat;
            spi_io_out_o[2] = 1'b0;
            spi_io_out_o[3] = 1'b1;
          end
        endcase
      end
      default: begin
        spi_io_en_o  = '0;
        spi_io_out_o = '0;
      end
    endcase
  end


  always_comb begin
    s_sg_bit_cnt_d = s_sg_bit_cnt_q;
    if (busy_o && s_fsm_cnt_q) begin
      if (s_sg_bit_cnt_q == 8'd7) s_sg_bit_cnt_d = 8'd0;
      else if (s_xfer_trg) s_sg_bit_cnt_d = s_sg_bit_cnt_q + 1'b1;
    end
  end
  dffr #(8) u_sg_bit_cnt_dffr (
      clk_i,
      rst_n_i,
      s_sg_bit_cnt_d,
      s_sg_bit_cnt_q
  );


  assign s_xfer_trg = cpha_i ? s_clk_fir_edge_trg : s_clk_sec_edge_trg;
  always_comb begin
    s_tx_shift_1_dat = '0;
    unique case (s_fsm_state_q)
      `SPI_FSM_IDLE:  s_tx_shift_1_dat = '0;
      `SPI_FSM_TCSP:  s_tx_shift_1_dat = '0;
      `SPI_FSM_CMD:   s_tx_shift_1_dat = s_xfer_cmd_q[7];
      `SPI_FSM_ADDR:  s_tx_shift_1_dat = s_xfer_addr_q[31];
      `SPI_FSM_ALTR:  s_tx_shift_1_dat = s_xfer_altr_q[31];
      `SPI_FSM_NOP:   s_tx_shift_1_dat = '0;
      `SPI_FSM_WDATA: s_tx_shift_1_dat = s_xfer_wr_data_q[7];
      `SPI_FSM_RDATA: s_tx_shift_1_dat = '0;
      `SPI_FSM_TCHD:  s_tx_shift_1_dat = '0;
      `SPI_FSM_RECY:  s_tx_shift_1_dat = '0;
    endcase
  end

  // NOTE: no support dual and quad spi
  assign s_tx_shift_2_dat = '0;
  assign s_tx_shift_4_dat = '0;

  // cmd shift reg
  always_comb begin
    if (s_fsm_state_q == `SPI_FSM_CMD) s_xfer_cmd_d = {s_xfer_cmd_q[6:0], 1'd0};
    else s_xfer_cmd_d = cmd_i;
  end
  dffer #(8) u_xfer_cmd_dffer (
      clk_i,
      rst_n_i,
      s_xfer_trg,
      s_xfer_cmd_d,
      s_xfer_cmd_q
  );

  // addr shift reg
  always_comb begin
    if (s_fsm_state_q == `SPI_FSM_ADDR) s_xfer_addr_d = {s_xfer_addr_q[31:0], 1'd0};
    else begin
      unique case (asize_i)
        `SPI_TRANS_8_BITS:  s_xfer_addr_d = {addr_i[7:0], 24'd0};
        `SPI_TRANS_16_BITS: s_xfer_addr_d = {addr_i[15:0], 16'd0};
        `SPI_TRANS_24_BITS: s_xfer_addr_d = {addr_i[23:0], 8'd0};
        `SPI_TRANS_32_BITS: s_xfer_addr_d = addr_i;
        default:            s_xfer_addr_d = {addr_i[7:0], 24'd0};
      endcase
    end
  end
  dffer #(32) u_xfer_addr_dffer (
      clk_i,
      rst_n_i,
      s_xfer_trg,
      s_xfer_addr_d,
      s_xfer_addr_q
  );


  // altr shift reg
  always_comb begin
    if (s_fsm_state_q == `SPI_FSM_ALTR) s_xfer_altr_d = {s_xfer_altr_q[31:0], 1'd0};
    else begin
      unique case (alsize_i)
        `SPI_TRANS_8_BITS:  s_xfer_altr_d = {altr_i[7:0], 24'd0};
        `SPI_TRANS_16_BITS: s_xfer_altr_d = {altr_i[15:0], 16'd0};
        `SPI_TRANS_24_BITS: s_xfer_altr_d = {altr_i[23:0], 8'd0};
        `SPI_TRANS_32_BITS: s_xfer_altr_d = altr_i;
        default:            s_xfer_altr_d = {altr_i[7:0], 24'd0};
      endcase
    end
  end
  dffer #(32) u_xfer_altr_dffer (
      clk_i,
      rst_n_i,
      s_xfer_trg,
      s_xfer_altr_d,
      s_xfer_altr_q
  );


  // wr data shift reg
  always_comb begin
    if (s_fsm_state_q == `SPI_FSM_WDATA) s_xfer_wr_data_d = {s_xfer_wr_data_q[6:0], 1'd0};
    else s_xfer_wr_data_d = tx_data_i;
  end
  dffer #(8) u_xfer_wr_data_dffer (
      clk_i,
      rst_n_i,
      s_xfer_trg,
      s_xfer_wr_data_d,
      s_xfer_wr_data_q
  );

  edge_det_sync_re u_xfer_done_edge_det_sync_re (
      .clk_i  (clk_i),
      .rst_n_i(rst_n_i),
      .dat_i  (busy_o),
      .re_o   (last_o)
  );
endmodule
