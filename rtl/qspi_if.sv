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

interface qspi_if ();
  logic                    sck_o;
  logic [`SPI_NSS_NUM-1:0] nss_o;
  logic [             3:0] io_oe_o;
  logic [             3:0] io_di_i;
  logic [             3:0] io_do_o;
  logic                    irq_o;

  modport dut(
      output sck_o,
      output nss_o,
      output io_oe_o,
      input io_di_i,
      output io_do_o,
      output irq_o
  );

  // verilog_format: off
  modport tb(
      input sck_o,
      input nss_o,
      input io_oe_o,
      output io_di_i,
      input io_do_o,
      input irq_o
  );
  // verilog_format: on
endinterface