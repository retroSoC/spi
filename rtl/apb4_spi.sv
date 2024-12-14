// Copyright (c) 2023-2024 Miao Yuchi <miaoyuchi@ict.ac.cn>
// spi is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "register.sv"
`include "fifo.sv"
`include "spi_define.sv"

module apb4_spi #(
    parameter int FIFO_DEPTH     = 64,
    parameter int LOG_FIFO_DEPTH = $clog2(FIFO_DEPTH)
) (
    apb4_if.slave apb4,
    spi_if.dut    spi
);

  logic [3:0] s_apb4_addr;
  logic s_apb4_wr_hdshk, s_apb4_rd_hdshk;
  logic [`SPI_CTRL_WIDTH-1:0] s_spi_ctrl_d, s_spi_ctrl_q;
  logic s_spi_ctrl_wr, s_spi_ctrl_en;
  logic [`SPI_FMT_WIDTH-1:0] s_spi_fmt_d, s_spi_fmt_q;
  logic s_spi_fmt_en;
  logic [`SPI_FRAME_WIDTH-1:0] s_spi_frame_d, s_spi_frame_q;
  logic s_spi_frame_en;
  logic [`SPI_CMD_WIDTH-1:0] s_spi_cmd_d, s_spi_cmd_q;
  logic s_spi_cmd_en;
  logic [`SPI_ADDR_WIDTH-1:0] s_spi_addr_d, s_spi_addr_q;
  logic s_spi_addr_en;
  logic [`SPI_ALTR_WIDTH-1:0] s_spi_altr_d, s_spi_altr_q;
  logic s_spi_altr_en;
  logic [`SPI_NOP_WIDTH-1:0] s_spi_nop_d, s_spi_nop_q;
  logic s_spi_nop_en;
  logic [`SPI_TRL_WIDTH-1:0] s_spi_trl_d, s_spi_trl_q;
  logic s_spi_trl_en;
  logic [`SPI_STAT_WIDTH-1:0] s_spi_stat_d, s_spi_stat_q;
  // bit
  logic s_bit_en, s_bit_txie, s_bit_rxie, s_bit_st, s_bit_rwm;
  logic s_bit_cpha, s_bit_cpol, s_bit_lsb, s_bit_rdm, s_bit_ass;
  logic [3:0] s_bit_nss, s_bit_csv;
  logic [7:0] s_bit_div, s_bit_recv;
  logic [4:0] s_bit_txth, s_bit_rxth;
  logic [1:0] s_bit_cmode, s_bit_amode, s_bit_asize;
  logic [1:0] s_bit_almode, s_bit_alsize;
  logic [1:0] s_bit_dmode, s_bit_dsize;
  logic [1:0] s_bit_tcsp, s_bit_tchd;
  logic s_bit_txif, s_bit_rxif;
  // irq
  logic s_tx_irq_trg, s_rx_irq_trg;
  // fifo
  logic s_tx_push_valid, s_tx_push_ready, s_tx_empty, s_tx_full, s_tx_pop_valid, s_tx_pop_ready;
  logic s_rx_push_valid, s_rx_push_ready, s_rx_empty, s_rx_full, s_rx_pop_valid, s_rx_pop_ready;
  logic [7:0] s_tx_push_data, s_tx_pop_data, s_rx_push_data, s_rx_pop_data;
  logic [31:0] s_spi_rv_rx;
  logic [LOG_FIFO_DEPTH:0] s_tx_elem, s_rx_elem;
  // spi
  logic s_busy, s_last;

  assign s_apb4_addr     = apb4.paddr[5:2];
  assign s_apb4_wr_hdshk = apb4.psel && apb4.penable && apb4.pwrite;
  assign s_apb4_rd_hdshk = apb4.psel && apb4.penable && (~apb4.pwrite);
  assign apb4.pready     = 1'b1;
  assign apb4.pslverr    = 1'b0;

  assign s_bit_en        = s_spi_ctrl_q[0];
  assign s_bit_txie      = s_spi_ctrl_q[1];
  assign s_bit_rxie      = s_spi_ctrl_q[2];
  assign s_bit_st        = s_spi_ctrl_q[3];
  assign s_bit_rwm       = s_spi_ctrl_q[4];
  assign s_bit_nss       = s_spi_ctrl_q[8:5];

  assign s_bit_cpha      = s_spi_fmt_q[0];
  assign s_bit_cpol      = s_spi_fmt_q[1];
  assign s_bit_lsb       = s_spi_fmt_q[2];
  assign s_bit_rdm       = s_spi_fmt_q[3];
  assign s_bit_ass       = s_spi_fmt_q[4];
  assign s_bit_csv       = s_spi_fmt_q[8:5];
  assign s_bit_div       = s_spi_fmt_q[16:9];
  assign s_bit_txth      = s_spi_fmt_q[21:17];
  assign s_bit_rxth      = s_spi_fmt_q[26:22];

  assign s_bit_cmode     = s_spi_frame_q[1:0];
  assign s_bit_amode     = s_spi_frame_q[3:2];
  assign s_bit_asize     = s_spi_frame_q[5:4];
  assign s_bit_almode    = s_spi_frame_q[7:6];
  assign s_bit_alsize    = s_spi_frame_q[9:8];
  assign s_bit_dmode     = s_spi_frame_q[11:10];
  assign s_bit_dsize     = s_spi_frame_q[13:12];
  assign s_bit_recv      = s_spi_frame_q[21:14];
  assign s_bit_tcsp      = s_spi_frame_q[23:22];
  assign s_bit_tchd      = s_spi_frame_q[25:24];

  assign s_bit_txif      = s_spi_stat_q[0];
  assign s_bit_rxif      = s_spi_stat_q[1];
  // irq
  assign s_tx_irq_trg    = s_bit_txth > s_tx_elem;
  assign s_rx_irq_trg    = s_bit_rxth < s_rx_elem;
  assign spi.irq_o       = s_bit_txif | s_bit_rxif;

  assign s_spi_ctrl_wr   = s_apb4_wr_hdshk && s_apb4_addr == `SPI_CTRL && ~s_busy;
  assign s_spi_ctrl_en   = s_spi_ctrl_wr || (s_busy && s_last);
  always_comb begin
    s_spi_ctrl_d = s_spi_ctrl_q;
    if (s_apb4_wr_hdshk && s_apb4_addr == `SPI_CTRL && ~s_busy) begin
      s_spi_ctrl_d = apb4.pwdata[`SPI_CTRL_WIDTH-1:0];
    end else if (s_busy && s_last) begin
      s_spi_ctrl_d[3] = 1'b0;
    end
  end
  dffer #(`SPI_CTRL_WIDTH) u_spi_ctrl_dffer (
      apb4.pclk,
      apb4.presetn,
      s_spi_ctrl_en,
      s_spi_ctrl_d,
      s_spi_ctrl_q
  );

  assign s_spi_fmt_en = s_apb4_wr_hdshk && s_apb4_addr == `SPI_FMT && ~s_busy;
  assign s_spi_fmt_d  = apb4.pwdata[`SPI_FMT_WIDTH-1:0];
  dffer #(`SPI_FMT_WIDTH) u_spi_fmt_dffer (
      apb4.pclk,
      apb4.presetn,
      s_spi_fmt_en,
      s_spi_fmt_d,
      s_spi_fmt_q
  );

  assign s_spi_frame_en = s_apb4_wr_hdshk && s_apb4_addr == `SPI_FRAME && ~s_busy;
  assign s_spi_frame_d  = apb4.pwdata[`SPI_FRAME_WIDTH-1:0];
  dffer #(`SPI_FRAME_WIDTH) u_spi_frame_dffer (
      apb4.pclk,
      apb4.presetn,
      s_spi_frame_en,
      s_spi_frame_d,
      s_spi_frame_q
  );

  assign s_spi_cmd_en = s_apb4_wr_hdshk && s_apb4_addr == `SPI_CMD && ~s_busy;
  assign s_spi_cmd_d  = apb4.pwdata[`SPI_CMD_WIDTH-1:0];
  dffer #(`SPI_CMD_WIDTH) u_spi_cmd_dffer (
      apb4.pclk,
      apb4.presetn,
      s_spi_cmd_en,
      s_spi_cmd_d,
      s_spi_cmd_q
  );

  assign s_spi_addr_en = s_apb4_wr_hdshk && s_apb4_addr == `SPI_ADDR && ~s_busy;
  assign s_spi_addr_d  = apb4.pwdata[`SPI_ADDR_WIDTH-1:0];
  dffer #(`SPI_ADDR_WIDTH) u_spi_addr_dffer (
      apb4.pclk,
      apb4.presetn,
      s_spi_addr_en,
      s_spi_addr_d,
      s_spi_addr_q
  );

  assign s_spi_altr_en = s_apb4_wr_hdshk && s_apb4_addr == `SPI_ALTR && ~s_busy;
  assign s_spi_altr_d  = apb4.pwdata[`SPI_ALTR_WIDTH-1:0];
  dffer #(`SPI_ALTR_WIDTH) u_spi_altr_dffer (
      apb4.pclk,
      apb4.presetn,
      s_spi_altr_en,
      s_spi_altr_d,
      s_spi_altr_q
  );

  assign s_spi_nop_en = s_apb4_wr_hdshk && s_apb4_addr == `SPI_NOP && ~s_busy;
  assign s_spi_nop_d  = apb4.pwdata[`SPI_NOP_WIDTH-1:0];
  dffer #(`SPI_NOP_WIDTH) u_spi_nop_dffer (
      apb4.pclk,
      apb4.presetn,
      s_spi_nop_en,
      s_spi_nop_d,
      s_spi_nop_q
  );

  assign s_spi_trl_en = s_apb4_wr_hdshk && s_apb4_addr == `SPI_TRL && ~s_busy;
  assign s_spi_trl_d  = apb4.pwdata[`SPI_TRL_WIDTH-1:0];
  dffer #(`SPI_TRL_WIDTH) u_spi_trl_dffer (
      apb4.pclk,
      apb4.presetn,
      s_spi_trl_en,
      s_spi_trl_d,
      s_spi_trl_q
  );

  // NOTE: this version only support 8b data
  always_comb begin
    s_tx_push_valid = 1'b0;
    s_tx_push_data  = '0;
    if (s_apb4_wr_hdshk && s_apb4_addr == `SPI_TXR) begin
      s_tx_push_valid = 1'b1;
      unique case (s_bit_dsize)
        `SPI_TRANS_8_BITS: s_tx_push_data = apb4.pwdata[7:0];
        default:           s_tx_push_data = apb4.pwdata[7:0];
      endcase
    end
  end

  always_comb begin
    s_spi_stat_d[4] = s_rx_empty;
    s_spi_stat_d[3] = s_tx_full;
    s_spi_stat_d[2] = s_busy;
    if ((s_bit_txif || s_bit_rxif) && s_apb4_rd_hdshk && s_apb4_addr == `SPI_STAT) begin
      s_spi_stat_d[1:0] = 2'b0;
    end else if (~s_bit_txif && s_bit_en && s_bit_txie && s_tx_irq_trg) begin
      s_spi_stat_d[1:0] = {s_bit_rxif, 1'b1};
    end else if (~s_bit_rxif && s_bit_en && s_bit_rxie && s_rx_irq_trg) begin
      s_spi_stat_d[1:0] = {1'b1, s_bit_txif};
    end else begin
      s_spi_stat_d[1:0] = {s_bit_rxif, s_bit_txif};
    end
  end
  dffr #(`SPI_STAT_WIDTH) u_spi_stat_dffr (
      apb4.pclk,
      apb4.presetn,
      s_spi_stat_d,
      s_spi_stat_q
  );


  assign s_spi_rv_rx = s_rx_pop_data[7:0];
  always_comb begin
    apb4.prdata    = '0;
    s_rx_pop_ready = 1'b0;
    if (s_apb4_rd_hdshk) begin
      unique case (s_apb4_addr)
        `SPI_CTRL:  apb4.prdata[`SPI_CTRL_WIDTH-1:0] = s_spi_ctrl_q;
        `SPI_FMT:   apb4.prdata[`SPI_FMT_WIDTH-1:0] = s_spi_fmt_q;
        `SPI_FRAME: apb4.prdata[`SPI_FRAME_WIDTH-1:0] = s_spi_frame_q;
        `SPI_CMD:   apb4.prdata[`SPI_CMD_WIDTH-1:0] = s_spi_cmd_q;
        `SPI_ADDR:  apb4.prdata[`SPI_ADDR_WIDTH-1:0] = s_spi_addr_q;
        `SPI_ALTR:  apb4.prdata[`SPI_ALTR_WIDTH-1:0] = s_spi_altr_q;
        `SPI_NOP:   apb4.prdata[`SPI_NOP_WIDTH-1:0] = s_spi_nop_q;
        `SPI_TRL:   apb4.prdata[`SPI_TRL_WIDTH-1:0] = s_spi_trl_q;
        `SPI_RXR: begin
          s_rx_pop_ready                  = 1'b1;
          // NOTE: need to handshake to pop a valid data
          apb4.prdata[`SPI_RXR_WIDTH-1:0] = s_bit_rdm ? s_spi_rv_rx : s_rx_pop_data;
        end
        `SPI_STAT:  apb4.prdata[`SPI_STAT_WIDTH-1:0] = s_spi_stat_q;
        default:    apb4.prdata = '0;
      endcase
    end
  end

  assign s_tx_push_ready = ~s_tx_full;
  assign s_tx_pop_valid  = ~s_tx_empty;
  fifo #(
      .DATA_WIDTH  (8),
      .BUFFER_DEPTH(FIFO_DEPTH)
  ) u_tx_fifo (
      .clk_i  (apb4.pclk),
      .rst_n_i(apb4.presetn),
      .flush_i(~s_bit_en),
      .cnt_o  (s_tx_elem),
      .push_i (s_tx_push_valid),
      .full_o (s_tx_full),
      .dat_i  (s_tx_push_data),
      .pop_i  (s_tx_pop_ready),
      .empty_o(s_tx_empty),
      .dat_o  (s_tx_pop_data)
  );

  assign s_rx_push_ready = ~s_rx_full;
  assign s_rx_pop_valid  = ~s_rx_empty;
  fifo #(
      .DATA_WIDTH  (8),
      .BUFFER_DEPTH(FIFO_DEPTH)
  ) u_rx_fifo (
      .clk_i  (apb4.pclk),
      .rst_n_i(apb4.presetn),
      .flush_i(~s_bit_en),
      .cnt_o  (s_rx_elem),
      .push_i (s_rx_push_valid),
      .full_o (s_rx_full),
      .dat_i  (s_rx_push_data),
      .pop_i  (s_rx_pop_ready),
      .empty_o(s_rx_empty),
      .dat_o  (s_rx_pop_data)
  );

  spi_core #(
      .FIFO_DEPTH(FIFO_DEPTH)
  ) u_spi_core (
      .clk_i       (apb4.pclk),
      .rst_n_i     (apb4.presetn),
      .en_i        (s_bit_en),
      .nss_i       (s_bit_nss),
      .csv_i       (s_bit_csv),
      .ass_i       (s_bit_ass),
      .lsb_i       (s_bit_lsb),
      .st_i        (s_bit_st),
      .rwm_i       (s_bit_rwm),
      .cmode_i     (s_bit_cmode),
      .amode_i     (s_bit_amode),
      .asize_i     (s_bit_asize),
      .almode_i    (s_bit_almode),
      .alsize_i    (s_bit_alsize),
      .dmode_i     (s_bit_dmode),
      .dsize_i     (s_bit_dsize),
      .recy_i      (s_bit_recv),
      .tcsp_i      (s_bit_tcsp),
      .tchd_i      (s_bit_tchd),
      .cmd_i       (s_spi_cmd_q),
      .addr_i      (s_spi_addr_q),
      .altr_i      (s_spi_altr_q),
      .nop_i       (s_spi_nop_q),
      .cpol_i      (s_bit_cpol),
      .cpha_i      (s_bit_cpha),
      .div_i       (s_bit_div),
      .trl_i       (s_spi_trl_q),
      .busy_o      (s_busy),
      .last_o      (s_last),
      .tx_valid_i  (s_tx_pop_valid),
      .tx_ready_o  (s_tx_pop_ready),
      .tx_data_i   (s_tx_pop_data),
      .rx_valid_o  (s_rx_push_valid),
      .rx_ready_i  (s_rx_push_ready),
      .rx_data_o   (s_rx_push_data),
      .spi_sck_o   (spi.spi_sck_o),
      .spi_nss_o   (spi.spi_nss_o),
      .spi_io_en_o (spi.spi_io_en_o),
      .spi_io_in_i (spi.spi_io_in_i),
      .spi_io_out_o(spi.spi_io_out_o)
  );

endmodule
