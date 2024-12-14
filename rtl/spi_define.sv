// Copyright (c) 2023-2024 Miao Yuchi <miaoyuchi@ict.ac.cn>
// spi is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

`ifndef INC_SPI_DEF_SV
`define INC_SPI_DEF_SV

/* register mapping
 * SPI_CTRL:
 * BITS:   | 31:9 | 8:5 | 4   | 3  | 2    | 1    | 0  |
 * FIELDS: | RES  | NSS | RWM | ST | RXIE | TXIE | EN |
 * PERMS:  | NONE | RW  | RW  | RW | RW   | RW   | RW |
 * ------------------------------------------------------------------------------
 * SPI_FMT:
 * BITS:   | 31:27 | 26:22 | 21:17 | 16:9 | 8:5 | 4   | 3   | 2   | 1    | 0    |
 * FIELDS: | RES   | RXTH  | TXTH  | DIV  | CSV | ASS | RDM | LSB | CPOL | CPHA |
 * PERMS:  | NONE  | RW    | RW    | RW   | RW  | RW  | RW  | RW  | RW   | RW   |
 * ------------------------------------------------------------------------------
 * SPI_FRAME:
 * BITS:   | 31:26 | 25:24 | 23:22 | 21:14 | 13:12 | 11:10 | 9:8    | 7:6    | 5:4   | 3:2   | 1:0   |
 * FIELDS: | RES   | TCHD  | TCSP  | RECY  | DSIZE | DMODE | ALSIZE | ALMODE | ASIZE | AMODE | CMODE |
 * PERMS:  | NONE  | RW    | RW    | RW    | RW    | RW    | RW     | RW     | RW    | RW    | RW    |
 * ------------------------------------------------------------------------------
 * SPI_CMD:
 * BITS:   | 31:8  | 7:0 |
 * FIELDS: | RES   | CMD |
 * PERMS:  | NONE  | RW  |
 * ------------------------------------------------------------------------------
 * SPI_ADDR:
 * BITS:   | 31:0 |
 * FIELDS: | ADDR |
 * PERMS:  | RW   |
 * ------------------------------------------------------------------------------
 * SPI_ALTR:
 * BITS:   | 31:0 |
 * FIELDS: | ALTR |
 * PERMS:  | RW   |
 * ------------------------------------------------------------------------------
 * SPI_NOP:
 * BITS:   | 31:10 | 9:0 |
 * FIELDS: | RES   | NOP |
 * PERMS:  | NONE  | RW  |
 * ------------------------------------------------------------------------------
 * SPI_TRL:
 * BITS:   | 31:10 | 9:0 |
 * FIELDS: | RES   | TRL |
 * PERMS:  | NONE  | WO  |
 * ------------------------------------------------------------------------------
 * SPI_TXR:
 * BITS:   | 31:8  | 7:0    |
 * FIELDS: | RES   | TXDATA |
 * PERMS:  | NONE  | WO     |
 * ------------------------------------------------------------------------------
 * SPI_RXR:
 * BITS:   | 31:8  | 7:0    |
 * FIELDS: | RES   | RXDATA |
 * PERMS:  | NONE  | RO     |
 * ------------------------------------------------------------------------------
 * SPI_STAT:
 * BITS:   | 31:5 | 4    | 3    | 2    | 1    | 0    |
 * FIELDS: | RES  | RETY | TFUL | BUSY | RXIF | TXIF |
 * PERMS:  | NONE | RO   | RO   | RO   | RO   | RO   |
 * ------------------------------------------------------------------------------
*/

// verilog_format: off
`define SPI_CTRL  4'b0000 // BASEADDR + 0x00
`define SPI_FMT   4'b0001 // BASEADDR + 0x04
`define SPI_FRAME 4'b0010 // BASEADDR + 0x08
`define SPI_CMD   4'b0011 // BASEADDR + 0x0C
`define SPI_ADDR  4'b0100 // BASEADDR + 0x10
`define SPI_ALTR  4'b0101 // BASEADDR + 0x14
`define SPI_NOP   4'b0110 // BASEADDR + 0x18
`define SPI_TRL   4'b0111 // BASEADDR + 0x1C
`define SPI_TXR   4'b1000 // BASEADDR + 0x20
`define SPI_RXR   4'b1001 // BASEADDR + 0x24
`define SPI_STAT  4'b1010 // BASEADDR + 0x28

`define SPI_CTRL_ADDR  {26'b0, `SPI_CTRL,  2'b00}
`define SPI_FMT_ADDR   {26'b0, `SPI_FMT,   2'b00}
`define SPI_FRAME_ADDR {26'b0, `SPI_FRAME, 2'b00}
`define SPI_CMD_ADDR   {26'b0, `SPI_CMD,   2'b00}
`define SPI_ADDR_ADDR  {26'b0, `SPI_ADDR,  2'b00}
`define SPI_ALTR_ADDR  {26'b0, `SPI_ALTR,  2'b00}
`define SPI_NOP_ADDR   {26'b0, `SPI_NOP,   2'b00}
`define SPI_TRL_ADDR   {26'b0, `SPI_TRL,   2'b00}
`define SPI_TXR_ADDR   {26'b0, `SPI_TXR,   2'b00}
`define SPI_RXR_ADDR   {26'b0, `SPI_RXR,   2'b00}
`define SPI_STAT_ADDR  {26'b0, `SPI_STAT,  2'b00}

`define SPI_CTRL_WIDTH  9
`define SPI_FMT_WIDTH   27
`define SPI_FRAME_WIDTH 26
`define SPI_CMD_WIDTH   8
`define SPI_ADDR_WIDTH  32
`define SPI_ALTR_WIDTH  32
`define SPI_NOP_WIDTH   10
`define SPI_TRL_WIDTH   10
`define SPI_TXR_WIDTH   32
`define SPI_RXR_WIDTH   32
`define SPI_STAT_WIDTH  5

`define SPI_NSS_NUM 1

`define SPI_MODE_SKIP     2'b00
`define SPI_MODE_STD_SPI  2'b01
`define SPI_MODE_DUAL_SPI 2'b10
`define SPI_MODE_QUAD_SPI 2'b11

`define SPI_TRANS_8_BITS  2'b00
`define SPI_TRANS_16_BITS 2'b01
`define SPI_TRANS_24_BITS 2'b10
`define SPI_TRANS_32_BITS 2'b11

`define SPI_PSCR_DIV2     8'd0
`define SPI_PSCR_DIV4     8'd1
`define SPI_PSCR_DIV8     8'd2
`define SPI_PSCR_DIV16    8'd3
`define SPI_PSCR_DIV32    8'd4

`define SPI_FSM_IDLE      4'd0
`define SPI_FSM_TCSP      4'd1
`define SPI_FSM_CMD       4'd2
`define SPI_FSM_ADDR      4'd3
`define SPI_FSM_ALTR      4'd4
`define SPI_FSM_NOP       4'd5
`define SPI_FSM_WDATA     4'd6
`define SPI_FSM_RDATA     4'd7
`define SPI_FSM_TCHD      4'd8
`define SPI_FSM_RECY      4'd9
// verilog_format: on

// io0(mosi)
// io1(miso)
// io2
// io3
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
`endif
