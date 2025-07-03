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

module spi_clkgen (
    input  logic       clk_i,
    input  logic       rst_n_i,
    input  logic       en_i,
    input  logic [7:0] clk_div_i,
    input  logic       clk_div_valid_i,
    output logic       spi_clk_o,
    output logic       spi_fall_o,
    output logic       spi_rise_o
);

  logic [7:0] s_cnt_tgt_d, s_cnt_tgt_q;
  logic [7:0] s_cnt_d, s_cnt_q;
  logic s_spi_clk_d, s_spi_clk_q;
  logic r_running;

  assign spi_clk_o = s_spi_clk_q;

  always_comb begin
    spi_rise_o = 1'b0;
    spi_fall_o = 1'b0;

    if (clk_div_valid_i) s_cnt_tgt_d = clk_div_i;
    else s_cnt_tgt_d = s_cnt_tgt_q;

    if (s_cnt_q == s_cnt_tgt_q) begin
      s_cnt_d     = 0;
      s_spi_clk_d = ~s_spi_clk_q;

      if (s_spi_clk_q == 1'b0) spi_rise_o = r_running;
      else spi_fall_o = r_running;

    end else begin
      s_cnt_d     = s_cnt_q + 1;
      s_spi_clk_d = s_spi_clk_q;
    end
  end

  always_ff @(posedge clk_i or negedge rst_n_i) begin
    if (rst_n_i == 1'b0) begin
      s_cnt_tgt_q <= '0;
      s_cnt_q     <= '0;
      s_spi_clk_q <= '0;
      r_running   <= '0;
    end else begin
      s_cnt_tgt_q <= s_cnt_tgt_d;

      if (!((s_spi_clk_q == 1'b0) && ~en_i)) begin
        r_running   <= 1'b1;
        s_spi_clk_q <= s_spi_clk_d;
        s_cnt_q     <= s_cnt_d;
      end else r_running <= 1'b0;
    end
  end


endmodule
