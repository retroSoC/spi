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

module spi_tx (
    input  wire        clk,
    input  wire        rstn,
    input  wire        en,
    input  wire        tx_edge,
    output wire        tx_done,
    output wire        sdo0,
    output wire        sdo1,
    output wire        sdo2,
    output wire        sdo3,
    input  wire        en_quad_in,
    input  wire [15:0] counter_in,
    input  wire        counter_in_upd,
    input  wire [31:0] data,
    input  wire        data_valid,
    output reg         data_ready,
    output reg         clk_en_o
);
  localparam [0:0] IDLE = 0;
  localparam [0:0] TRANSMIT = 1;

  reg  [31:0] data_int;
  reg  [31:0] data_int_next;
  reg  [15:0] counter;
  reg  [15:0] counter_trgt;
  reg  [15:0] counter_next;
  reg  [15:0] counter_trgt_next;

  wire        done;
  wire        reg_done;

  reg  [ 0:0] tx_CS;
  reg  [ 0:0] tx_NS;

  assign sdo0 = (en_quad_in ? data_int[28] : data_int[31]);
  assign sdo1 = data_int[29];
  assign sdo2 = data_int[30];
  assign sdo3 = data_int[31];

  assign tx_done = done;
  assign reg_done = (!en_quad_in && (counter[4:0] == 5'b11111)) || (en_quad_in && (counter[2:0] == 3'b111));

  always @(*) begin
    if (counter_in_upd) counter_trgt_next = (en_quad_in ? {2'b00, counter_in[15:2]} : counter_in);
    else counter_trgt_next = counter_trgt;
  end

  assign done = (counter == (counter_trgt - 1)) && tx_edge;

  always @(*) begin
    tx_NS         = tx_CS;
    clk_en_o      = 1'b0;
    data_int_next = data_int;
    data_ready    = 1'b0;
    counter_next  = counter;

    case (tx_CS)
      IDLE: begin
        clk_en_o = 1'b0;

        if (en && data_valid) begin
          data_int_next = data;
          data_ready    = 1'b1;
          tx_NS         = TRANSMIT;
        end
      end
      TRANSMIT: begin
        clk_en_o = 1'b1;

        if (tx_edge) begin
          counter_next  = counter + 1;
          data_int_next = (en_quad_in ? {data_int[27:0], 4'b0000} : {data_int[30:0], 1'b0});

          if (tx_done) begin
            counter_next = 0;

            if (en && data_valid) begin
              data_int_next = data;
              data_ready    = 1'b1;
              tx_NS         = TRANSMIT;
            end else begin
              clk_en_o = 1'b0;
              tx_NS    = IDLE;
            end
          end else if (reg_done) begin
            if (data_valid) begin
              data_int_next = data;
              data_ready    = 1'b1;
            end else begin
              clk_en_o = 1'b0;
              tx_NS    = IDLE;
            end
          end
        end
      end
    endcase
  end


  always @(posedge clk or negedge rstn) begin
    if (~rstn) begin
      counter      <= 0;
      counter_trgt <= 'h8;
      data_int     <= 'h0;
      tx_CS        <= IDLE;
    end else begin
      counter      <= counter_next;
      counter_trgt <= counter_trgt_next;
      data_int     <= data_int_next;
      tx_CS        <= tx_NS;
    end
  end

endmodule
