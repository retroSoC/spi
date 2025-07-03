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
    parameter int FIFO_DEPTH = 64
) (
    apb4_if.slave apb4,
    spi_if.dut    spi
);

  spi_core #(
      .BUFFER_DEPTH(FIFO_DEPTH)
  ) u_spi_core (
      .HCLK    (apb4.pclk),
      .HRESETn (apb4.presetn),
      .PADDR   (apb4.paddr[11:0]),
      .PWDATA  (apb4.pwdata),
      .PWRITE  (apb4.pwrite),
      .PSEL    (apb4.psel),
      .PENABLE (apb4.penable),
      .PRDATA  (apb4.prdata),
      .PREADY  (apb4.pready),
      .PSLVERR (apb4.pslverr),
      .events_o(spi.irq_o),
      .spi_clk (spi.spi_sck_o),
      .spi_csn0(spi.spi_nss_o[0]),
      .spi_csn1(spi.spi_nss_o[1]),
      .spi_csn2(spi.spi_nss_o[2]),
      .spi_csn3(spi.spi_nss_o[3]),
      .spi_sdo0(spi.spi_io_out_o[0]),
      .spi_sdo1(spi.spi_io_out_o[1]),
      .spi_sdo2(spi.spi_io_out_o[2]),
      .spi_sdo3(spi.spi_io_out_o[3]),
      .spi_oe0 (spi.spi_io_en_o[0]),
      .spi_oe1 (spi.spi_io_en_o[1]),
      .spi_oe2 (spi.spi_io_en_o[2]),
      .spi_oe3 (spi.spi_io_en_o[3]),
      .spi_sdi0(spi.spi_io_in_i[0]),
      .spi_sdi1(spi.spi_io_in_i[1]),
      .spi_sdi2(spi.spi_io_in_i[2]),
      .spi_sdi3(spi.spi_io_in_i[3])
  );
endmodule
