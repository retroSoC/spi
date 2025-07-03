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

module spi_master_clkgen (
    input  wire         clk,
    input  wire         rstn,
    input  wire         en,
    input  wire [7:0]   clk_div,
    input  wire         clk_div_valid,
    output reg          spi_clk,
    output reg          spi_fall,
    output reg          spi_rise
);

    reg [7:0] counter_trgt;
    reg [7:0] counter_trgt_next;
    reg [7:0] counter;
    reg [7:0] counter_next;

    reg       spi_clk_next;
    reg       running;

    always @(*) begin
        spi_rise = 1'b0;
        spi_fall = 1'b0;

        if (clk_div_valid)
            counter_trgt_next = clk_div;
        else
            counter_trgt_next = counter_trgt;

        if (counter == counter_trgt) begin
            counter_next = 0;
            spi_clk_next = ~spi_clk;

            if (spi_clk == 1'b0)
                spi_rise = running;
            else
                spi_fall = running;

	end else begin
            counter_next = counter + 1;
            spi_clk_next = spi_clk;
        end
    end

    always @(posedge clk or negedge rstn) begin
        if (rstn == 1'b0) begin
            counter_trgt <= 'h0;
            counter      <= 'h0;
            spi_clk      <= 1'b0;
            running      <= 1'b0;
	end else begin
            counter_trgt <= counter_trgt_next;

            if (!((spi_clk == 1'b0) && ~en)) begin
                running <= 1'b1;
                spi_clk <= spi_clk_next;
                counter <= counter_next;
	    end else
                running <= 1'b0;
        end
    end


endmodule
