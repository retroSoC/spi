// Copyright (c) 2023-2024 Miao Yuchi <miaoyuchi@ict.ac.cn>
// spi is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "apb4_if.sv"
`include "gpio_pad.sv"
`include "spi_define.sv"

module apb4_spi_tb ();
  localparam CLK_PEROID = 10;
  logic rst_n_i, clk_i;
  wire [3:0] s_spi_io_pad;

  initial begin
    clk_i = 1'b0;
    forever begin
      #(CLK_PEROID / 2) clk_i <= ~clk_i;
    end
  end

  task sim_reset(int delay);
    rst_n_i = 1'b0;
    repeat (delay) @(posedge clk_i);
    #1 rst_n_i = 1'b1;
  endtask

  initial begin
    sim_reset(40);
  end

  apb4_if u_apb4_if (
      clk_i,
      rst_n_i
  );

  spi_if u_spi_if ();

  for (genvar i = 0; i < 4; i++) begin : SPI_TB_PAD_BLOCK
    tri_pd_pad_h u_spi_io_pad (
        .i_i   (u_spi_if.spi_io_out_o[i]),
        .oen_i (u_spi_if.spi_io_en_o[i]),
        .ren_i (),
        .c_o   (u_spi_if.spi_io_in_i[i]),
        .pad_io(s_spi_io_pad[i])
    );
  end

  test_top u_test_top (
      .apb4(u_apb4_if.master),
      .spi (u_spi_if.tb)
  );
  apb4_spi u_apb4_spi (
      .apb4(u_apb4_if.slave),
      .spi (u_spi_if.dut)
  );

  // W25Q128JVxIM u_W25Q128JVxIM (
  //     .CSn  (u_spi_if.spi_nss_o[0]),
  //     .CLK  (u_spi_if.spi_sck_o),
  //     .DIO  (s_spi_io_pad[0]),
  //     .DO   (s_spi_io_pad[1]),
  //     .WPn  (s_spi_io_pad[2]),
  //     .HOLDn(s_spi_io_pad[3])
  // );
endmodule
