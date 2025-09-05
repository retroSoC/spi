// Copyright (c) 2023-2025 Miao Yuchi <miaoyuchi@ict.ac.cn>
// spi is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`include "spi_define.svh"

module apb4_spi #(
    parameter int FIFO_DEPTH = 32
) (
`ifdef __VERILOG__
    `apb4_slave_if(apb4),
    output                    spi_spi_sck_o,
    output [`SPI_NSS_NUM-1:0] spi_spi_nss_o,
    output [             3:0] spi_spi_io_en_o,
    input  [             3:0] spi_spi_io_in_i,
    output [             3:0] spi_spi_io_out_o,
    output                    spi_irq_o
`else
    apb4_if.slave apb4,
    spi_if.dut    spi
`endif
);

`ifndef __VERILOG__
  `apb4_slave_if2wire(apb4, apb4);
  wire                    spi_spi_sck_o;
  wire [`SPI_NSS_NUM-1:0] spi_spi_nss_o;
  wire [             3:0] spi_spi_io_en_o;
  wire [             3:0] spi_spi_io_in_i = spi.spi_io_in_i;
  wire [             3:0] spi_spi_io_out_o;
  wire                    spi_irq_o;
  assign spi.spi_sck_o    = spi_spi_sck_o;
  assign spi.spi_nss_o    = spi_spi_nss_o;
  assign spi.spi_io_en_o  = spi_spi_io_en_o;
  assign spi.spi_io_out_o = spi_spi_io_out_o;
  assign spi.irq_o        = spi_irq_o;
`endif

  spi_core #(
      .BUFFER_DEPTH(FIFO_DEPTH)
  ) u_spi_core (
      .HCLK    (apb4_pclk),
      .HRESETn (apb4_presetn),
      .PADDR   (apb4_paddr[11:0]),
      .PWDATA  (apb4_pwdata),
      .PWRITE  (apb4_pwrite),
      .PSEL    (apb4_psel),
      .PENABLE (apb4_penable),
      .PRDATA  (apb4_prdata),
      .PREADY  (apb4_pready),
      .PSLVERR (apb4_pslverr),
      .events_o(spi_irq_o),
      .spi_clk (spi_spi_sck_o),
      .spi_csn0(spi_spi_nss_o[0]),
      .spi_csn1(spi_spi_nss_o[1]),
      .spi_csn2(spi_spi_nss_o[2]),
      .spi_csn3(spi_spi_nss_o[3]),
      .spi_sdo0(spi_spi_io_out_o[0]),
      .spi_sdo1(spi_spi_io_out_o[1]),
      .spi_sdo2(spi_spi_io_out_o[2]),
      .spi_sdo3(spi_spi_io_out_o[3]),
      .spi_oe0 (spi_spi_io_en_o[0]),
      .spi_oe1 (spi_spi_io_en_o[1]),
      .spi_oe2 (spi_spi_io_en_o[2]),
      .spi_oe3 (spi_spi_io_en_o[3]),
      .spi_sdi0(spi_spi_io_in_i[0]),
      .spi_sdi1(spi_spi_io_in_i[1]),
      .spi_sdi2(spi_spi_io_in_i[2]),
      .spi_sdi3(spi_spi_io_in_i[3])
  );
endmodule
