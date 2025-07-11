// Copyright (c) 2023-2024 Miao Yuchi <miaoyuchi@ict.ac.cn>
// spi is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

// io0(mosi)
// io1(miso)
// io2
// io3

`include "spi_define.svh"

interface spi_if ();
  logic                    spi_sck_o;
  logic [`SPI_NSS_NUM-1:0] spi_nss_o;
  logic [             3:0] spi_io_en_o;
  logic [             3:0] spi_io_in_i;
  logic [             3:0] spi_io_out_o;
  logic                    irq_o;

  modport dut(
      output spi_sck_o,
      output spi_nss_o,
      output spi_io_en_o,
      input spi_io_in_i,
      output spi_io_out_o,
      output irq_o
  );

  // verilog_format: off
  modport tb(
      input spi_sck_o,
      input spi_nss_o,
      input spi_io_en_o,
      output spi_io_in_i,
      input spi_io_out_o,
      input irq_o
  );
  // verilog_format: on
endinterface